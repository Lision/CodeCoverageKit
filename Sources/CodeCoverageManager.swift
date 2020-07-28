//
//  CodeCoverageManager.swift
//  CodeCoverageKit
//
//  Created by 李鑫 on 2020/6/24.
//  Copyright © 2020 Lision. All rights reserved.
//

#if !targetEnvironment(simulator)

#if SWIFT_PACKAGE
import InstrProfiling
#endif
import Foundation
import UIKit
import SSZipArchive

@objc(YFDCodeCoverageManager) public class CodeCoverageManager: NSObject {
    public typealias AppID = String

    @objc public static let sharedInstance: CodeCoverageManager = CodeCoverageManager()
    private static let bundleVersionKey = "com.coco.app.bundle.version"
    private static let fileName = "coco.profraw"
    private static let zipName = "coco.zip"
    private static let fileURL: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(CodeCoverageManager.fileName, isDirectory: false)
    private static let zipURL: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(CodeCoverageManager.zipName, isDirectory: false)
    private var appID = ""
    private let serialQueue = DispatchQueue(label: "com.coco.serial")

    /// Start collecting code coverage data and report it regularly.
    ///
    /// - parameter appID: The identifier obtained by registering on the code coverage platform.
    ///                    If appID.isEmpty == true, the code coverage can not start normally.
    @objc(startWithAppID:) public func start(with appID: AppID) {
        guard !appID.isEmpty else {
            assert(!appID.isEmpty)
            return
        }
        self.appID = appID
        uploadLastProfrawFileIfNeeded()
        Timer.scheduledTimer(
            timeInterval: 30,
            target: self,
            selector: #selector(uploadProfraw(_:)),
            userInfo: nil,
            repeats: true
        )
    }

    override init() {
        super.init()
        clearArtifactsIfNeeded()
        setupInstrProfiling()
        setupDataBindings()
    }

    // MARK: Setup
    func setupInstrProfiling() {
        __llvm_profile_register_write_file_atexit()
        CodeCoverageManager.fileURL.path.withCString {
            __llvm_profile_set_filename(UnsafeMutablePointer(mutating: $0))
        }
        print(String(cString: __llvm_profile_get_filename()))
        __llvm_profile_initialize_file()
    }

    func setupDataBindings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: Notification
    @objc func applicationWillTerminate(_ notification: Notification) {
        __llvm_profile_write_file()
    }

    // MARK: Timer
    @objc func uploadProfraw(_ timer: Timer) {
        serialQueue.async {
            guard __llvm_profile_write_file() == 0 else { return }
            self.zipProfrawFile()
            self.uploadProfrawFile()
        }
    }

    // MARK: Upload
    func uploadLastProfrawFileIfNeeded() {
        serialQueue.async {
            self.zipProfrawFile()
            self.uploadProfrawFile()
        }
    }
    
    func uploadProfrawFile() {
        uploadProfrawFile { (data, success) in
            guard success else {
                print(data ?? "upload result = \(success)")
                return
            }
            self.deleteFile(atPath: CodeCoverageManager.fileURL.path)
            self.deleteFile(atPath: CodeCoverageManager.zipURL.path)
        }
    }
    
    func uploadProfrawFile(completionHandler: @escaping (String?, Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: CodeCoverageManager.zipURL.path) else {
            completionHandler("\(CodeCoverageManager.zipURL.path) is not exist.", false)
            return
        }
        guard let cocoData = try? Data(contentsOf: CodeCoverageManager.zipURL), !cocoData.isEmpty else {
            completionHandler("coco data transfer failed.", false)
            return
        }
        guard let uploadUrl = URL(string: "http://coco.zhenguanyu.com/upload") else {
            completionHandler("verify upload api url failed.", false)
            return
        }
        let boundary = UUID().uuidString
        var uploadData = Data()
        uploadData.appendFormField(name: "app_id",
                                   value: appID,
                                   boundary: boundary)
        uploadData.appendFormField(name: "app",
                                   value: Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? "",
                                   boundary: boundary)
        uploadData.appendFormField(name: "version",
                                   value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                                   boundary: boundary)
        uploadData.appendFormField(name: "build_number",
                                   value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
                                   boundary: boundary)
        uploadData.appendFormField(name: "uuid",
                                   value: UIDevice.current.identifierForVendor?.uuidString ?? "",
                                   boundary: boundary)
        uploadData.appendFormField(name: "device_info",
                                   value: String(data: try! JSONEncoder().encode(DeviceInfo()), encoding: .utf8) ?? "",
                                   boundary: boundary)
        uploadData.appendFormField(name: "hash",
                                   value: Encryptor.SHA256Digest(data: cocoData),
                                   boundary: boundary)
        uploadData.appendFormFileData(cocoData,
                                      name: "file",
                                      fileName: CodeCoverageManager.zipName,
                                      mimeType: "application/zip",
                                      boundary: boundary)
        uploadData.appendFormBoundaryEnd(boundary: boundary)
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                completionHandler(error.localizedDescription, false)
                return
            }
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                completionHandler("server error", false)
                return
            }
            completionHandler(nil, true)
        }
        task.resume()
    }

    // MARK: File
    func clearArtifactsIfNeeded() {
        guard let currentBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else { return }
        guard let storedBundleVersion = UserDefaults.standard.string(forKey: CodeCoverageManager.bundleVersionKey) else {
            UserDefaults.standard.set(currentBundleVersion, forKey: CodeCoverageManager.bundleVersionKey)
            return
        }
        guard storedBundleVersion != currentBundleVersion else { return }
        deleteFile(atPath: CodeCoverageManager.fileURL.path)
        deleteFile(atPath: CodeCoverageManager.zipURL.path)
        UserDefaults.standard.set(currentBundleVersion, forKey: CodeCoverageManager.bundleVersionKey)
    }

    func zipProfrawFile() {
        guard FileManager.default.fileExists(atPath: CodeCoverageManager.fileURL.path) else { return }
        deleteFile(atPath: CodeCoverageManager.zipURL.path)
        SSZipArchive.createZipFile(atPath: CodeCoverageManager.zipURL.path,
                                   withFilesAtPaths: [CodeCoverageManager.fileURL.path])
    }

    func deleteFile(atPath path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try! FileManager.default.removeItem(atPath: path)
    }
}

#endif
