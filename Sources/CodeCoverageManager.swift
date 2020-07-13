//
//  CodeCoverageManager.swift
//  CodeCoverageKit
//
//  Created by 李鑫 on 2020/6/24.
//  Copyright © 2020 Lision. All rights reserved.
//

#if targetEnvironment(simulator)
// Not currently supported simulator
#else

#if SWIFT_PACKAGE
import InstrProfiling
#endif
import Foundation
import UIKit

@objc(YFDCodeCoverageManager) public class CodeCoverageManager: NSObject {
    public typealias AppID = String

    @objc public static let sharedInstance: CodeCoverageManager = CodeCoverageManager()
    private static let fileName = "coco.profraw"
    private static let zipName = "coco.zip"
    private static let url: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(CodeCoverageManager.fileName, isDirectory: false)
    private var appID = ""

    /// Start collecting code coverage data and report it regularly.
    ///
    /// - parameter appID: The identifier obtained by registering on the code coverage platform.
    @objc(startWithAppID:) public func start(with appID: AppID) {
        self.appID = appID
        Timer.scheduledTimer(
            timeInterval: 10,
            target: self,
            selector: #selector(updateProfrawData(_:)),
            userInfo: nil,
            repeats: true
        ).fire()
    }

    override init() {
        super.init()
        setupInstrProfiling()
        setupDataBindings()
    }

    // MARK: Setup
    func setupInstrProfiling() {
        __llvm_profile_register_write_file_atexit()
        CodeCoverageManager.url.path.withCString {
            __llvm_profile_set_filename(UnsafeMutablePointer(mutating: $0))
        }
        print(String(cString: __llvm_profile_get_filename()))
        __llvm_profile_initialize_file()
        if FileManager.default.fileExists(atPath: CodeCoverageManager.url.path) {
            try! FileManager.default.removeItem(atPath: CodeCoverageManager.url.path)
        }
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
    @objc func updateProfrawData(_ timer: Timer) {
        guard !appID.isEmpty, __llvm_profile_write_file() == 0 else { return }
        uploadProfrawFile { (data, success) in
            print(data ?? "upload result = \(success)")
        }
    }

    // MARK: Upload
    func uploadProfrawFile(completionHandler: @escaping (String?, Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: CodeCoverageManager.url.path) else {
            completionHandler("\(CodeCoverageManager.url.path) is not exist.", false)
            return
        }
        guard let cocoData = try? Data(contentsOf: CodeCoverageManager.url) else {
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
                                      fileName: CodeCoverageManager.fileName,
                                      mimeType: "application/profraw",
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
}

#endif
