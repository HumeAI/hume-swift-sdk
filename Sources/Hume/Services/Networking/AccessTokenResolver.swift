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
    case .accessTokenProvider(let tokenProvider):
      return try await tokenProvider()
    #if HUME_SERVER
    case .apiKey(let key):
      return key
    #endif
    }
  }
}
