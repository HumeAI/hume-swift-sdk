//
//  EndpointTest.swift
//  Hume
//
//  Created by AI on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

private struct DummyResponse: NetworkClientResponse {}

struct EndpointTest {

  @Test func initializes_with_defaults() async throws {
    let ep = Endpoint<DummyResponse>(path: "/v1/defaults")
    #expect(ep.path == "/v1/defaults")
    #expect(ep.method == .get)
    #expect(ep.headers == nil)
    #expect(ep.queryParams == nil)
    #expect(ep.body == nil)
    #expect(ep.cachePolicy == .useProtocolCachePolicy)
    #expect(ep.timeoutDuration == 60)
    #expect(ep.maxRetries == 0)
  }

  @Test func preserves_custom_values() async throws {
    struct Req: NetworkClientRequest { let x: Int }
    let ep = Endpoint<DummyResponse>(
      path: "/v1/custom",
      method: .post,
      headers: ["X": "1"],
      queryParams: ["q": "z"],
      body: Req(x: 9),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutDuration: 15,
      maxRetries: 2
    )

    #expect(ep.path == "/v1/custom")
    #expect(ep.method == .post)
    #expect(ep.headers?["X"] == "1")
    #expect(ep.queryParams?["q"] == "z")
    #expect(ep.body != nil)
    #expect(ep.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(ep.timeoutDuration == 15)
    #expect(ep.maxRetries == 2)
  }
}
