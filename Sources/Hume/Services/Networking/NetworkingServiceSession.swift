//
//  NetworkingServiceSession.swift
//  Hume
//
//  Created by Chris on 6/27/25.
//

import Foundation

/// `NetworkingServiceSession` serves as an interface to create light wrappers around making network requests. By abstracting out the connection layer,
/// it enables us to isolate the Networking logic for testing
protocol NetworkingServiceSession {
  var session: URLSession { get }
  /// Submit a request and returns the retrieved data
  func data(
    for request: URLRequest,
    delegate: (any URLSessionTaskDelegate)?
  ) async throws -> (Data, URLResponse)

  #if os(iOS) || os(macOS)
    @available(macOS 12.0, *)
    func bytes(
      for request: URLRequest,
      delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (URLSession.AsyncBytes, URLResponse)
  #endif
}

/// `URLNetworkingSession` is the default implementation of `NetworkingServiceSession`. This uses the standard `URLSession` and enables it with a configurable `URLCache`
struct URLNetworkingSession: NetworkingServiceSession {
  let session: URLSession
  private let urlCache: URLCache

  init(
    memoryCapacity: Int = Constants.Networking.URLCacheMemoryCapacity,
    diskCapacity: Int = Constants.Networking.URLCacheDiskCapacity
  ) {
    urlCache = URLCache(
      memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "urlCache")

    let configuration = URLSessionConfiguration.default
    configuration.urlCache = urlCache
    configuration.requestCachePolicy = .useProtocolCachePolicy

    self.session = URLSession(configuration: configuration)
  }

  #if os(iOS) || os(macOS)
    @available(macOS 12.0, *)
    func data(
      for request: URLRequest,
      delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (Data, URLResponse) {
      try await session.data(for: request, delegate: delegate)
    }

    @available(macOS 12.0, *)
    public func bytes(
      for request: URLRequest,
      delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (URLSession.AsyncBytes, URLResponse) {
      return try await session.bytes(for: request, delegate: delegate)
    }
  #else
    // Fallback for other platforms
    func data(
      for request: URLRequest,
      delegate: (any URLSessionTaskDelegate)? = nil
    ) async throws -> (Data, URLResponse) {
      // Use older API for compatibility
      return try await withCheckedThrowingContinuation { continuation in
        let task = session.dataTask(with: request) { data, response, error in
          if let error = error {
            continuation.resume(throwing: error)
          } else if let data = data, let response = response {
            continuation.resume(returning: (data, response))
          } else {
            continuation.resume(throwing: URLError(.badServerResponse))
          }
        }
        task.resume()
      }
    }
  #endif
}
