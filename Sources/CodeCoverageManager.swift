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
import Alamofire

@objc(YFDCodeCoverageManager) public class CodeCoverageManager: NSObject {
    public typealias AppID = String

    @objc public static let sharedInstance: CodeCoverageManager = CodeCoverageManager()
    private static let bundleVersionKey = "com.coco.app.bundle.version"
    private static let fileName = "coco.profraw"
    private static let fileURL: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent(CodeCoverageManager.fileName, isDirectory: false)

    @objc public var uploadURL = "http://coco.zhenguanyu.com/upload"
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
        assert(String(cString: __llvm_profile_get_filename()) == CodeCoverageManager.fileURL.path)
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
            self.uploadProfrawFile()
        }
    }

    // MARK: Upload
    func uploadLastProfrawFileIfNeeded() {
        serialQueue.async {
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
        }
    }

    func uploadProfrawFile(completionHandler: @escaping (String?, Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: CodeCoverageManager.fileURL.path) else {
            completionHandler("\(CodeCoverageManager.fileURL.path) is not exist.", false)
            return
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: CodeCoverageManager.fileURL.path) else {
            completionHandler("\(CodeCoverageManager.fileURL.path) file attributes can not be read.", false)
            return
        }
        guard let fileSize = attributes[.size] as? Int64 else {
            completionHandler("\(CodeCoverageManager.fileURL.path) file size load failed.", false)
            return
        }
        guard let modificationDate = attributes[.modificationDate] as? Date else {
            completionHandler("\(CodeCoverageManager.fileURL.path) file modification date load failed.", false)
            return
        }

        AF.upload(
            multipartFormData: { (multipartFormData) in
                multipartFormData.append(self.appID.data(using: .utf8)!, withName: "app_id")
                let app = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
                multipartFormData.append(app.data(using: .utf8)!, withName: "app")
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                multipartFormData.append(version.data(using: .utf8)!, withName: "version")
                let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
                multipartFormData.append(buildNumber.data(using: .utf8)!, withName: "build_number")
                let uuid = UIDevice.current.identifierForVendor?.uuidString ?? ""
                multipartFormData.append(uuid.data(using: .utf8)!, withName: "uuid")
                let deviceInfo = String(data: try! JSONEncoder().encode(DeviceInfo()), encoding: .utf8) ?? ""
                multipartFormData.append(deviceInfo.data(using: .utf8)!, withName: "device_info")
                let hash = Encryptor.SHA256Digest(data: "\(fileSize)_\(modificationDate.timeIntervalSinceReferenceDate)".data(using: .utf8)!)
                multipartFormData.append(hash.data(using: .utf8)!, withName: "hash")
                multipartFormData.append(
                    CodeCoverageManager.fileURL,
                    withName: "file",
                    fileName: CodeCoverageManager.fileName,
                    mimeType: "application/profraw"
                )
            }, to: uploadURL).response { (response) in
                switch response.result {
                case .success(_):
                    completionHandler(nil, true)
                case .failure(let error):
                    completionHandler(error.localizedDescription, false)
                }
            }
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
        UserDefaults.standard.set(currentBundleVersion, forKey: CodeCoverageManager.bundleVersionKey)
    }

    func deleteFile(atPath path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try! FileManager.default.removeItem(atPath: path)
    }
}

#endif
