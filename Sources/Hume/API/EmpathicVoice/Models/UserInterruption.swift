//
//  UserInterruption.swift
//
//
//  This file was auto-generated by Fern from our API Definition.
//

import Foundation


public struct UserInterruption: Codable {
    let customSessionId: String?
    let time: Int
    let type: String

    public init(customSessionId: String?,
                time: Int,
                type: String) {
        self.customSessionId = customSessionId
        self.time = time
        self.type = type
    }
}
