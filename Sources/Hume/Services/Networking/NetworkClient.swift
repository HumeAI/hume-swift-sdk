import Foundation

protocol NetworkClient: AnyObject {
    /// Sends a request using the provided endpoint and returns the decoded response.
    ///
    /// - Parameter endpoint: The endpoint to send the request to.
    /// - Throws: A `NetworkError` if the request fails or authentication is missing.
    /// - Returns: A decoded response of type `Response`.
    func send<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>, customTokenProvider: TokenProvider?) async throws -> Response
    func stream<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>, customTokenProvider: TokenProvider?) -> AsyncThrowingStream<Response, Error>
}

extension NetworkClient {
    func send<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>) async throws -> Response {
        try await self.send(endpoint, customTokenProvider: nil)
    }
    func stream<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>) -> AsyncThrowingStream<Response, Error> {
        self.stream(endpoint, customTokenProvider: nil)
    }
}

enum NetworkClientNotification {
    static let DidReceiveNetworkError = Notification.Name("DidReceiveNetworkError")
}

class NetworkClientImpl: NetworkClient {
    private let baseURL: URL
    private let tokenProvider: TokenProvider
    private let networkingService: NetworkingService

    init(baseURL: URL, tokenProvider: @escaping TokenProvider, networkingService: NetworkingService) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.networkingService = networkingService
    }

    func send<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>, customTokenProvider: TokenProvider? = nil) async throws -> Response {
        var requestBuilder = try await makeRequestBuilder(endpoint, customTokenProvider: customTokenProvider)
        requestBuilder = requestBuilder.setBody(endpoint.body)
        requestBuilder = requestBuilder.setTimeout(endpoint.timeoutDuration)
        let request = try requestBuilder.build()

        var lastError: Error?
        var retryCount = 0
        
        repeat {
            do {
                return try await networkingService.performRequest(request)
            } catch {
                lastError = error
                retryCount += 1
                
                // Only retry if we haven't exceeded maxRetries and it's a retryable error
                if retryCount <= endpoint.maxRetries && isRetryableError(error) {
                    // Exponential backoff: wait 2^retryCount seconds before retrying
                    Logger.warn("retry #\(retryCount) - \(request.url?.absoluteString ?? "unknown URL")")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
                    continue
                }
                
                // notify listeners of error
                DispatchQueue.main.async {
                    NotificationCenter.default.post(Notification(name: NetworkClientNotification.DidReceiveNetworkError, userInfo: ["error": error]))
                }
                throw error
            }
        } while retryCount <= endpoint.maxRetries
        
        // This should never be reached, but just in case
        throw lastError ?? NetworkError.unknown
    }
    
    func stream<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>, customTokenProvider: TokenProvider? = nil) -> AsyncThrowingStream<Response, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Build URLRequest
                    var builder = try await makeRequestBuilder(endpoint, customTokenProvider: customTokenProvider)
                    builder = builder.setBody(endpoint.body)
                    builder = builder.setTimeout(endpoint.timeoutDuration)
                    let request = try builder.build()

                    // Stream raw bytes using networkingService
                    for try await chunk in networkingService.streamData(for: request) {
                        if Response.self == Data.self {
                            continuation.yield(chunk as! Response)
                        } else {
                            let decoded = try Defaults.decoder.decode(Response.self, from: chunk)
                            continuation.yield(decoded)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Add logic to determine if an error is retryable
        // For example, network timeouts, server errors (5xx), etc.
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .dnsLookupFailed,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func makeRequestBuilder<Response: NetworkClientResponse>(_ endpoint: Endpoint<Response>, customTokenProvider: TokenProvider? = nil) async throws -> RequestBuilder {
        var requestBuilder = RequestBuilder(baseURL: baseURL)
            .setPath(endpoint.path)
            .setMethod(endpoint.method)
            .setQueryParams(endpoint.queryParams ?? [:])
            .setCachePolicy(endpoint.cachePolicy)
            .addHeader(key: "Content-Type", value: "application/json")
        
        if let customTokenProvider {
            requestBuilder = try await customTokenProvider().updateRequest(requestBuilder)
        } else {
            requestBuilder = try await tokenProvider().updateRequest(requestBuilder)
        }

        if let headers = endpoint.headers {
            for (key, value) in headers {
                requestBuilder = requestBuilder.addHeader(key: key, value: value)
            }
        }
        return requestBuilder
    }
}

// MARK: - Client Factory

extension NetworkClientImpl {
    static func makeHumeClient(tokenProvider: @escaping TokenProvider,
                               networkingService: NetworkingService
    ) -> NetworkClientImpl {
        let host: String = SDKConfiguration.default.host
        let baseURL = URL(string: "https://\(host)")!
        return .init(baseURL: baseURL, tokenProvider: tokenProvider, networkingService: networkingService)
    }
}

// MARK: - Common models

typealias NetworkClientResponse = Decodable & Hashable
typealias NetworkClientRequest = Encodable & Hashable

struct EmptyResponse: NetworkClientResponse {}
