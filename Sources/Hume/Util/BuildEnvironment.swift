//
//  BuildEnvironment.swift
//  Hume
//
//  Created by Chris on 6/24/25.
//

import Foundation

public struct SDKConfiguration {
    /// The host API base URL
    public let host: String

    public init(host: String) {
        self.host = host
    }
}

extension SDKConfiguration {
    public static var `default`: SDKConfiguration {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "HumeAPIHost") as? String, !urlString.isEmpty else {
            return SDKConfiguration(host: "api.hume.ai")
        }
        return SDKConfiguration(host: urlString)
    }
}
