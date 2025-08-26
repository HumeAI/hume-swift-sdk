//
//  HumeAuth.swift
//  Hume
//
//  Created by Claude Code on 8/26/25.
//

import Foundation

public enum HumeAuth {
  /// Use an access token with the Hume APIs
  case accessToken(String)
  /// Use a closure to provide an access token asynchronously
  case accessTokenProvider(() async throws -> String)
  #if HUME_SERVER
  /// Use an API key with the Hume APIs (server-side only)
  case apiKey(String)
  #endif
}

extension HumeAuth {
  /// Returns the appropriate authorization header for HTTP requests
  func authHeader() async throws -> (String, String) {
    switch self {
    case .accessToken(let token):
      return ("Authorization", "Bearer \(token)")
    case .accessTokenProvider(let provider):
      return ("Authorization", "Bearer \(try await provider())")
    #if HUME_SERVER
    case .apiKey(let key):
      return ("X-API-Key", key)
    #endif
    }
  }
  
  /// Returns the appropriate query parameter for WebSocket connections
  func queryParam() async throws -> (String, String) {
    switch self {
    case .accessToken(let token):
      return ("accessToken", token)
    case .accessTokenProvider(let provider):
      return ("accessToken", try await provider())
    #if HUME_SERVER
    case .apiKey(let key):
      return ("apiKey", key)
    #endif
    }
  }
  
  /// Returns whether this authentication method is an API key
  var isApiKey: Bool {
    #if HUME_SERVER
    if case .apiKey = self { return true }
    #endif
    return false
  }
}