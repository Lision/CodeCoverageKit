//
//  Data+FormData.swift
//  YFDCodeCoverageKit
//
//  Created by 李鑫 on 2020/7/7.
//

import Foundation

extension Data {
    mutating func appendFormField(
        name: String,
        value: String,
        boundary: String
    ) {
        append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)".data(using: .utf8)!)
    }

    mutating func appendFormFileData(
        _ data: Data,
        name: String,
        fileName: String,
        mimeType: String,
        boundary: String
    ) {
        append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
    }

    mutating func appendFormBoundaryEnd(boundary: String) {
        append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
    }
}
