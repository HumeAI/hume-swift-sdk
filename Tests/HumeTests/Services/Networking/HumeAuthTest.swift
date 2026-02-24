//
//  HumeAuthTest.swift
//  Hume
//
//  Created by Chris on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

struct HumeAuthTest {

  // MARK: - Local Constants
  private enum Constants {
    static let baseURLString = "https://api.example.com"
    static let apiPath = "/v1/test"

    static let authorizationHeader = "Authorization"
    static let xApiKeyHeader = "X-API-Key"

    static let accessTokenQueryItem = "accessToken"
    static let apiKeyQueryItem = "apiKey"

    static let accessToken = "abc123"
    static let apiKey = "key_123"
    static let providerAccessToken = "tok_success"

    static let wsScheme = "wss"
    static let wsHost = "example.com"
    static let wsPath = "/socket"
  }

  // MARK: - Helpers
  private func makeRequestBuilder() -> RequestBuilder {
    return RequestBuilder(baseURL: URL(string: Constants.baseURLString)!)
      .setPath(Constants.apiPath)
  }

  // MARK: - RequestBuilder authenticate(_:)

  @Test func requestBuilder_accessToken_setsAuthorizationHeader() async throws {
    let builder = makeRequestBuilder()
    let auth = HumeAuth.accessToken(Constants.accessToken)

    let authed = try await auth.authenticate(builder)
    let request = try authed.build()
    let headers = request.allHTTPHeaderFields ?? [:]

    #expect(headers[Constants.authorizationHeader] == "Bearer \(Constants.accessToken)")
  }

  @Test func requestBuilder_apiKey_setsXAPIKeyHeader() async throws {
    let builder = makeRequestBuilder()
    let auth = HumeAuth.apiKey(Constants.apiKey)

    let authed = try await auth.authenticate(builder)
    let request = try authed.build()
    let headers = request.allHTTPHeaderFields ?? [:]

    #expect(headers[Constants.xApiKeyHeader] == Constants.apiKey)
  }

  @Test func requestBuilder_accessTokenProvider_success_setsAuthorizationHeader() async throws {
    let builder = makeRequestBuilder()
    let auth = HumeAuth.accessTokenProvider { Constants.providerAccessToken }

    let authed = try await auth.authenticate(builder)
    let request = try authed.build()
    let headers = request.allHTTPHeaderFields ?? [:]

    #expect(headers[Constants.authorizationHeader] == "Bearer \(Constants.providerAccessToken)")
  }

  @Test func requestBuilder_accessTokenProvider_throwing_rethrows() async {
    enum DummyError: Error { case boom }
    let builder = makeRequestBuilder()
    let auth = HumeAuth.accessTokenProvider {
      throw DummyError.boom
    }

    var didThrow = false
    do {
      _ = try await auth.authenticate(builder)
    } catch {
      didThrow = true
    }
    #expect(didThrow == true)
  }

  // MARK: - URLComponents authenticate(_:)

  @Test func urlComponents_accessToken_addsQueryItem() async throws {
    var components = URLComponents()
    components.scheme = Constants.wsScheme
    components.host = Constants.wsHost
    components.path = Constants.wsPath

    let auth = HumeAuth.accessToken(Constants.accessToken)
    try await auth.authenticate(&components)

    let items = components.queryItems ?? []
    #expect(
      items.contains(where: {
        $0.name == Constants.accessTokenQueryItem && $0.value == Constants.accessToken
      }))
  }

  @Test func urlComponents_apiKey_addsQueryItem() async throws {
    var components = URLComponents()
    components.scheme = Constants.wsScheme
    components.host = Constants.wsHost
    components.path = Constants.wsPath

    let auth = HumeAuth.apiKey(Constants.apiKey)
    try await auth.authenticate(&components)

    let items = components.queryItems ?? []
    #expect(
      items.contains(where: { $0.name == Constants.apiKeyQueryItem && $0.value == Constants.apiKey }
      ))
  }

  @Test func urlComponents_accessTokenProvider_success_addsQueryItem() async throws {
    var components = URLComponents()
    components.scheme = Constants.wsScheme
    components.host = Constants.wsHost
    components.path = Constants.wsPath

    let auth = HumeAuth.accessTokenProvider { Constants.providerAccessToken }
    try await auth.authenticate(&components)

    let items = components.queryItems ?? []
    #expect(
      items.contains(where: {
        $0.name == Constants.accessTokenQueryItem && $0.value == Constants.providerAccessToken
      }))
  }

  @Test func urlComponents_accessTokenProvider_throwing_rethrows() async {
    enum DummyError: Error { case boom }
    var components = URLComponents()
    components.scheme = "wss"
    components.host = "example.com"
    components.path = "/socket"

    let auth = HumeAuth.accessTokenProvider {
      throw DummyError.boom
    }

    var didThrow = false
    do {
      try await auth.authenticate(&components)
    } catch {
      didThrow = true
    }
    #expect(didThrow == true)
  }
}
