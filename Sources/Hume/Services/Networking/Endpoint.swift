import Foundation

/// Represents a network endpoint used with `NetworkClient`.
///
/// The `Endpoint` struct encapsulates all the necessary information required
/// to construct and send a network request, including the URL path, HTTP method,
/// query parameters, request body, and cache policy.
///
/// - Note: This structure is generic and works with any response type that conforms to `NetworkClientResponse`.
///
/// Example:
/// ```swift
/// let endpoint = Endpoint<DataResponse<User>>(
///     path: "/users/123",
///     method: .get
/// )
/// ```
///
/// - Parameter Response: The expected response type conforming to `Decodable`.
struct Endpoint<Response: NetworkClientResponse> {
  /// The URL path of the endpoint relative to the base URL.
  let path: String

  /// The HTTP method to be used for the request (e.g., `.get`, `.post`).
  let method: HTTPMethod

  var headers: [String: String]? = nil

  /// A dictionary of query parameters to be appended to the URL.
  let queryParams: [String: String]?

  /// An optional request body conforming to `NetworkClientRequest` (e.g., for POST or PATCH requests).
  let body: (any NetworkClientRequest)?

  /// The cache policy to use for the request. Defaults to `.useProtocolCachePolicy`.
  let cachePolicy: URLRequest.CachePolicy

  /// The timeout duration in seconds for the request. Defaults to 60 seconds.
  let timeoutDuration: TimeInterval

  /// The maximum number of retry attempts for failed requests. Defaults to 0 (no retries).
  let maxRetries: Int

  /// Initializes a new `Endpoint` instance.
  ///
  /// - Parameters:
  ///   - path: The URL path of the endpoint relative to the base URL.
  ///   - method: The HTTP method to be used for the request. Defaults to `.get`.
  ///   - queryParams: A dictionary of query parameters to be appended to the URL. Defaults to `nil`.
  ///   - body: An optional request body conforming to `NetworkClientRequest`. Defaults to `nil`.
  ///   - cachePolicy: The cache policy to use for the request. Defaults to `.useProtocolCachePolicy`.
  ///   - timeoutDuration: The timeout duration in seconds. Defaults to 60 seconds.
  ///   - maxRetries: The maximum number of retry attempts. Defaults to 0 (no retries).
  init(
    path: String,
    method: HTTPMethod = .get,
    headers: [String: String]? = nil,
    queryParams: [String: String]? = nil,
    body: (any NetworkClientRequest)? = nil,
    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
    timeoutDuration: TimeInterval = 60,
    maxRetries: Int = 0
  ) {
    self.path = path
    self.method = method
    self.headers = headers
    self.queryParams = queryParams
    self.body = body
    self.cachePolicy = cachePolicy
    self.timeoutDuration = timeoutDuration
    self.maxRetries = maxRetries
  }
}
