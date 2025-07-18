//
//  AccessTokenResolver.swift
//  HumeAI2
//
//  Created by Chris on 4/1/25.
//

import Foundation

internal struct AccessTokenResolver {
    internal static func resolve(options: HumeClient.Options) async throws -> String {
        switch options {
        case .accessToken(let accessToken):
            return accessToken
        }
    }
}
