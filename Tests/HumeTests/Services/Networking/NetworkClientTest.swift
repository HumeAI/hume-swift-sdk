//
//  NetworkClientTest.swift
//  Hume
//
//  Created by AI on 9/9/25.
//

import Foundation
import Testing

@testable import Hume

// MARK: - Mocks

private final class MockNetworkingService: NetworkingService {
  var lastRequest: URLRequest?

  var performRequestImpl: ((URLRequest) async throws -> Any)?
  var streamDataImpl: ((URLRequest) -> AsyncThrowingStream<Data, Error>)?

  func performRequest<Response>(_ request: URLRequest) async throws -> Response
  where Response: Decodable {
    lastRequest = request
    if let impl = performRequestImpl {
      let any = try await impl(request)
      guard let typed = any as? Response else {
        fatalError("MockNetworkingService: type mismatch for Response=\(Response.self)")
      }
      return typed
    }
    fatalError("MockNetworkingService.performRequestImpl not set")
  }

  func streamData(for request: URLRequest) -> AsyncThrowingStream<Data, Error> {
    lastRequest = request
    if let impl = streamDataImpl {
      return impl(request)
    }
    return AsyncThrowingStream { continuation in
      continuation.finish()
    }
  }
}

// MARK: - Fixtures

private struct TestBody: Codable, Hashable {
  let foo: String
  let bar: Int
}
private struct TestEvent: Decodable, Hashable { let x: Int }

extension NetworkClientImpl {
  fileprivate static func makeForTests(
    baseURL: URL = URL(string: "https://api.example.com")!,
    auth: HumeAuth = .accessToken("tok"),
    service: NetworkingService
  ) -> NetworkClientImpl {
    .init(baseURL: baseURL, auth: auth, networkingService: service)
  }
}

struct NetworkClientTest {

  // nc-send-builds-and-returns
  @Test func send_builds_request_and_returns_response() async throws {
    let mock = MockNetworkingService()
    let expected = EmptyResponse()
    mock.performRequestImpl = { _ in expected }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<EmptyResponse>(
      path: "/v1/foo",
      method: .post,
      headers: [
        "Content-Type": "text/plain",
        "X-Custom": "1",
      ],
      queryParams: ["q": "1", "w": "z"],
      body: TestBody(foo: "hello", bar: 42),
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutDuration: 5
    )

    let response = try await client.send(endpoint)
    #expect(response == expected)

    // Validate built URLRequest
    let request = try #require(mock.lastRequest)

    // URL + query params
    let url = try #require(request.url)
    let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(comps.path == "/v1/foo")
    let items = comps.queryItems ?? []
    #expect(items.contains(where: { $0.name == "q" && $0.value == "1" }))
    #expect(items.contains(where: { $0.name == "w" && $0.value == "z" }))

    // Method
    #expect(request.httpMethod == HTTPMethod.post.rawValue)

    // Headers (auth + override of Content-Type + custom)
    let headers = request.allHTTPHeaderFields ?? [:]
    #expect(headers["Authorization"] == "Bearer tok")
    #expect(headers["Content-Type"] == "text/plain")
    #expect(headers["X-Custom"] == "1")

    // Cache policy and timeout
    #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    #expect(request.timeoutInterval == 5)

    // Body encodes our payload
    let body = try #require(request.httpBody)
    let decoded = try JSONDecoder().decode(TestBody.self, from: body)
    #expect(decoded == TestBody(foo: "hello", bar: 42))
  }

  // nc-send-notification-on-error
  @Test func send_posts_notification_and_throws_on_error_nonretryable() async {
    enum Dummy: Error { case boom }
    let mock = MockNetworkingService()
    mock.performRequestImpl = { _ in throw Dummy.boom }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<EmptyResponse>(path: "/v1/err")

    // Observe notification
    let notifications = NotificationCenter.default.notifications(
      named: NetworkClientNotification.DidReceiveNetworkError
    )

    var didReceiveNotification = false
    let notifierTask = Task {
      for await _ in notifications {
        didReceiveNotification = true
        break
      }
    }

    var didThrow = false
    do {
      _ = try await client.send(endpoint)
    } catch {
      didThrow = true
    }

    // Allow the async notification to post on main
    try? await Task.sleep(nanoseconds: 100_000_000)
    notifierTask.cancel()

    #expect(didThrow)
    #expect(didReceiveNotification)
  }

  // nc-send-headers-override
  @Test func send_applies_and_overrides_endpoint_headers() async throws {
    let mock = MockNetworkingService()
    mock.performRequestImpl = { _ in EmptyResponse() }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<EmptyResponse>(
      path: "/v1/headers",
      method: .get,
      headers: ["Content-Type": "application/xml"]
    )

    _ = try await client.send(endpoint)
    let request = try #require(mock.lastRequest)
    let headers = request.allHTTPHeaderFields ?? [:]
    // Default set to application/json in makeRequestBuilder, then overridden by endpoint.headers
    #expect(headers["Content-Type"] == "application/xml")
  }

  // nc-stream-data-pass-through
  @Test func stream_yields_data_chunks_for_Data_response() async throws {
    let mock = MockNetworkingService()
    mock.performRequestImpl = { _ in Data() }  // not used
    mock.streamDataImpl = { _ in
      AsyncThrowingStream<Data, Error> { continuation in
        continuation.yield(Data([0x61, 0x62, 0x63]))  // "abc"
        continuation.yield(Data([0x64, 0x65]))  // "de"
        continuation.finish()
      }
    }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<Data>(path: "/v1/stream", method: .get)

    var chunks: [Data] = []
    for try await data in client.stream(endpoint) {
      chunks.append(data)
    }

    #expect(chunks.count == 2)
    #expect(chunks[0] == Data([0x61, 0x62, 0x63]))
    #expect(chunks[1] == Data([0x64, 0x65]))
  }

  // nc-stream-jsonl-decoding
  @Test func stream_decodes_newline_delimited_json_across_chunk_boundaries() async throws {
    let mock = MockNetworkingService()
    mock.streamDataImpl = { _ in
      AsyncThrowingStream<Data, Error> { continuation in
        // {"x":1}\n{"x":2}\n split across chunks
        continuation.yield(Data("{\"x\":1}\n{\"x\":".utf8))
        continuation.yield(Data("2}\n".utf8))
        continuation.finish()
      }
    }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<TestEvent>(path: "/v1/jsonl", method: .get)

    var events: [TestEvent] = []
    for try await evt in client.stream(endpoint) {
      events.append(evt)
    }

    #expect(events == [TestEvent(x: 1), TestEvent(x: 2)])
  }

  // nc-stream-error-propagation
  @Test func stream_finishes_with_error_when_underlying_stream_throws() async {
    enum DummyErr: Error { case nope }
    let mock = MockNetworkingService()
    mock.streamDataImpl = { _ in
      AsyncThrowingStream<Data, Error> { continuation in
        continuation.finish(throwing: DummyErr.nope)
      }
    }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<TestEvent>(path: "/v1/err-stream", method: .get)

    var didThrow = false
    do {
      for try await _ in client.stream(endpoint) {
        // no-op
      }
    } catch {
      didThrow = true
    }
    #expect(didThrow)
  }

  // nc-factory-base-url
  @Test func factory_uses_default_host_in_base_url() async throws {
    let mock = MockNetworkingService()
    mock.performRequestImpl = { _ in EmptyResponse() }

    let client = NetworkClientImpl.makeHumeClient(
      auth: .accessToken("tok"), networkingService: mock)
    let endpoint = Endpoint<EmptyResponse>(path: "/factory-test", method: .get)

    _ = try await client.send(endpoint)

    let request = try #require(mock.lastRequest)
    let url = try #require(request.url)
    let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(comps.scheme == "https")
    #expect(comps.host == SDKConfiguration.default.host)
    #expect(comps.path == "/factory-test")
  }

  // nc-send-retryable-error-once
  @Test func send_retries_once_on_retryable_error_and_then_succeeds() async throws {
    let mock = MockNetworkingService()
    var calls = 0
    mock.performRequestImpl = { _ in
      calls += 1
      if calls == 1 { throw URLError(.timedOut) }
      return EmptyResponse()
    }

    let client = NetworkClientImpl.makeForTests(service: mock)
    let endpoint = Endpoint<EmptyResponse>(path: "/retry", method: .get, maxRetries: 1)

    let result = try await client.send(endpoint)
    #expect(result == EmptyResponse())
    #expect(calls == 2)
  }
}
