//
//  Encryptor.swift
//  YFDCodeCoverageKit
//
//  Created by 李鑫 on 2020/7/7.
//

#if SWIFT_PACKAGE
import InstrProfiling
#endif
import Foundation

class Encryptor {
    static func SHA256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    static func SHA256Digest(data: Data) -> String {
        let temp = SHA256(data: data)
        return "\(temp.map { String(format: "%02hhx", $0) }.joined())"
    }
}
