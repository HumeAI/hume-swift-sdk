import Foundation
import Testing

//
//  Untitled.swift
//  Hume
//
//  Created by Chris on 9/9/25.
//
//
@testable import Hume

// MARK: - Mocks & Helpers

private final class MockNetworkingServiceSession: NetworkingServiceSession {
  var session: URLSession = .shared

  var nextData: Data = Data()
  var nextResponse: URLResponse = HTTPURLResponse(
    url: URL(string: "https://example.com")!,
    statusCode: 200,
    httpVersion: nil,
    headerFields: nil
  )!
  var nextError: Error?

  func data(
    for request: URLRequest,
    delegate: (any URLSessionTaskDelegate)?
  ) async throws -> (Data, URLResponse) {
    if let error = nextError { throw error }
    return (nextData, nextResponse)
  }

  func bytes(
    for request: URLRequest,
    delegate: (any URLSessionTaskDelegate)?
  ) async throws -> (URLSession.AsyncBytes, URLResponse) {
    fatalError("Not implemented for tests")
  }
}

private func makeRequest(urlString: String = "https://example.com/test") -> URLRequest {
  var request = URLRequest(url: URL(string: urlString)!)
  request.httpMethod = "GET"
  return request
}

private func makeHTTPURLResponse(status: Int, url: String = "https://example.com/test")
  -> HTTPURLResponse
{
  return HTTPURLResponse(
    url: URL(string: url)!, statusCode: status, httpVersion: nil, headerFields: nil)!
}

private func makeService(using session: MockNetworkingServiceSession) -> NetworkingServiceImpl {
  return NetworkingServiceImpl(session: session, decoder: Defaults.decoder)
}

private struct TestModel: Codable, Equatable {
  let message: String
}

// MARK: - Tests

struct NetworkServiceTest {

  @Test func performRequest_success_decodesModel() async throws {
    let session = MockNetworkingServiceSession()
    let expected = TestModel(message: "ok")
    session.nextData = try JSONEncoder().encode(expected)
    session.nextResponse = makeHTTPURLResponse(status: 200)

    let service = makeService(using: session)
    let result: TestModel = try await service.performRequest(makeRequest())

    #expect(result == expected)
  }

  @Test func performRequest_returnsRawData_whenResponseIsData() async throws {
    let session = MockNetworkingServiceSession()
    let payload = Data([0x00, 0x01, 0x02])
    session.nextData = payload
    session.nextResponse = makeHTTPURLResponse(status: 200)

    let service = makeService(using: session)
    let result: Data = try await service.performRequest(makeRequest())

    #expect(result == payload)
  }

  @Test func performRequest_returnsEmptyResponse_whenDataEmpty() async throws {
    let session = MockNetworkingServiceSession()
    session.nextData = Data()
    session.nextResponse = makeHTTPURLResponse(status: 200)

    let service = makeService(using: session)
    let result: EmptyResponse = try await service.performRequest(makeRequest())

    #expect(type(of: result) == EmptyResponse.self)
  }

  @Test func performRequest_sessionThrows_mapsToInvalidResponse() async {
    enum Dummy: Error { case boom }
    let session = MockNetworkingServiceSession()
    session.nextError = Dummy.boom

    let service = makeService(using: session)
    var received: NetworkError?
    do {
      let _: TestModel = try await service.performRequest(makeRequest())
    } catch let error as NetworkError {
      received = error
    } catch {}

    #expect(received == .invalidResponse)
  }

  @Test func performRequest_nonHTTPResponse_mapsToInvalidResponse() async {
    let session = MockNetworkingServiceSession()
    session.nextData = Data()
    session.nextResponse = URLResponse(
      url: URL(string: "https://example.com/test")!,
      mimeType: nil,
      expectedContentLength: 0,
      textEncodingName: nil
    )

    let service = makeService(using: session)
    var isInvalidResponse = false
    do {
      let _: TestModel = try await service.performRequest(makeRequest())
    } catch NetworkError.invalidResponse {
      isInvalidResponse = true
    } catch {}

    #expect(isInvalidResponse == true)
  }

  @Test func performRequest_errorJSONWithMessage_throwsErrorResponse() async {
    let session = MockNetworkingServiceSession()
    let json = ["message": "Uh oh"]
    session.nextData = try! JSONSerialization.data(withJSONObject: json)
    session.nextResponse = makeHTTPURLResponse(status: 500)

    let service = makeService(using: session)
    var matched = false
    do {
      let _: TestModel = try await service.performRequest(makeRequest())
    } catch let error as NetworkError {
      if case .errorResponse(let code, let message) = error {
        matched = (code == 500 && message == "Uh oh")
      }
    } catch {}

    #expect(matched == true)
  }

  @Test func performRequest_400_mapsToInvalidRequest() async {
    let session = MockNetworkingServiceSession()
    session.nextData = Data("{}".utf8)
    session.nextResponse = makeHTTPURLResponse(status: 400)

    let service = makeService(using: session)
    var received: NetworkError?
    do { let _: TestModel = try await service.performRequest(makeRequest()) } catch let error
      as NetworkError
    { received = error } catch {}

    #expect(received == .invalidRequest)
  }

  @Test func performRequest_401_mapsToUnauthorized() async {
    let session = MockNetworkingServiceSession()
    session.nextData = Data("{}".utf8)
    session.nextResponse = makeHTTPURLResponse(status: 401)

    let service = makeService(using: session)
    var received: NetworkError?
    do { let _: TestModel = try await service.performRequest(makeRequest()) } catch let error
      as NetworkError
    { received = error } catch {}

    #expect(received == .unauthorized)
  }

  @Test func performRequest_403_mapsToForbidden() async {
    let session = MockNetworkingServiceSession()
    session.nextData = Data("{}".utf8)
    session.nextResponse = makeHTTPURLResponse(status: 403)

    let service = makeService(using: session)
    var received: NetworkError?
    do { let _: TestModel = try await service.performRequest(makeRequest()) } catch let error
      as NetworkError
    { received = error } catch {}

    #expect(received == .forbidden)
  }

  @Test func performRequest_otherStatus_mapsToInvalidResponse() async {
    let session = MockNetworkingServiceSession()
    session.nextData = Data("{}".utf8)
    session.nextResponse = makeHTTPURLResponse(status: 500)

    let service = makeService(using: session)
    var received: NetworkError?
    do { let _: TestModel = try await service.performRequest(makeRequest()) } catch let error
      as NetworkError
    { received = error } catch {}

    #expect(received == .invalidResponse)
  }

  @Test func performRequest_decodeFailure_mapsToResponseDecodingFailed() async {
    struct Mismatch: Decodable { let other: String }

    let session = MockNetworkingServiceSession()
    session.nextData = Data("{\"message\":\"ok\"}".utf8)
    session.nextResponse = makeHTTPURLResponse(status: 200)

    let service = makeService(using: session)
    var received: NetworkError?
    do { let _: Mismatch = try await service.performRequest(makeRequest()) } catch let error
      as NetworkError
    { received = error } catch {}

    #expect(received == .responseDecodingFailed)
  }
}
