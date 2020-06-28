//
//  DeviceInfo.swift
//  YFDCodeCoverageKit
//
//  Created by 李鑫 on 2020/7/7.
//

import UIKit

struct DeviceInfo: Codable {
    let name: String
    let systemName: String
    let systemVersion: String
    let model: String
    let localizedModel: String

    init() {
        name = UIDevice.current.name
        systemName = UIDevice.current.systemName
        systemVersion = UIDevice.current.systemVersion
        model = UIDevice.current.model
        localizedModel = UIDevice.current.localizedModel
    }
}
