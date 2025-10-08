//
//  RequestBuilderTest.swift
//  Hume
//
//  Created by AI on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

private struct Body: Codable, Equatable { let url: String }

struct RequestBuilderTest {

  private func makeBuilder() -> RequestBuilder {
    RequestBuilder(baseURL: URL(string: "https://api.example.com")!)
  }

  @Test func build_constructs_url_with_path_and_query() async throws {
    let builder = makeBuilder()
      .setPath("/v1/items")
      .setQueryParams(["q": "swift", "page": "2"])

    let request = try builder.build()
    let url = try #require(request.url)
    let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(comps.path == "/v1/items")
    let items = comps.queryItems ?? []
    #expect(items.contains(where: { $0.name == "q" && $0.value == "swift" }))
    #expect(items.contains(where: { $0.name == "page" && $0.value == "2" }))
  }

  @Test func sets_method_and_headers() async throws {
    let builder = makeBuilder()
      .setPath("/v1/h")
      .setMethod(.post)
      .setHeaders(["X-Base": "1"])  // baseline
      .addHeader(key: "X-Base", value: "2")  // override
      .addHeader(key: "X-Extra", value: "y")

    let request = try builder.build()
    #expect(request.httpMethod == HTTPMethod.post.rawValue)
    let headers = request.allHTTPHeaderFields ?? [:]
    #expect(headers["X-Base"] == "2")
    #expect(headers["X-Extra"] == "y")
  }

  @Test func encodes_body_and_keeps_slashes_unescaped() async throws {
    let payload = Body(url: "https://example.com/a/b")
    let builder = makeBuilder()
      .setPath("/v1/body")
      .setBody(payload)

    let request = try builder.build()
    let body = try #require(request.httpBody)
    let json = try #require(String(data: body, encoding: .utf8))
    // Expect no \/ escaping
    #expect(json.contains("https://example.com/a/b"))
    let decoded = try JSONDecoder().decode(Body.self, from: body)
    #expect(decoded == payload)
  }

  @Test func body_nil_leaves_httpBody_nil() async throws {
    let builder = makeBuilder()
      .setPath("/v1/nobody")
      .setBody(nil)

    let request = try builder.build()
    #expect(request.httpBody == nil)
  }

  @Test func sets_cache_policy_and_timeout() async throws {
    let builder = makeBuilder()
      .setPath("/v1/conf")
      .setCachePolicy(.reloadIgnoringLocalCacheData)
      .setTimeout(5)

    let request = try builder.build()
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(request.timeoutInterval == 5)
  }
}
