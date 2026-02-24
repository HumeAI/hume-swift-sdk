//
//  TokenProvidableTest.swift
//  Hume
//
//  Created by AI on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

struct TokenProvidableTest {

  @Test func bearer_updates_request_with_authorization_header() async throws {
    let token = AuthTokenType.bearer("tok_123")
    let base = URL(string: "https://api.example.com")!
    var builder = RequestBuilder(baseURL: base)
      .setPath("/v1/foo")
      .setHeaders([:])

    builder = try await token.updateRequest(builder)
    let request = try builder.build()
    let headers = request.allHTTPHeaderFields ?? [:]
    #expect(headers["Authorization"] == "Bearer tok_123")
  }
}
