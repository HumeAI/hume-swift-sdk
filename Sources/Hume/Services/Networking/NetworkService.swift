import Foundation

/// The `NetworkingService` interface provides an API for making requests aginst a `ServiceResource`
public protocol NetworkingService {
    /// Make a request for the given endpoint and returns the data encoded as `T`
    ///
    /// - Parameter Response: The expected response as a model that conforms to `Decodable`
    /// - Parameters:
    ///     - request: URLRequest to make
    /// - Returns: An object of type `Response`
    /// - Throws: `NetworkError`
    func performRequest<Response: Decodable>(_ request: URLRequest) async throws -> Response

    /// Streams raw Data chunks for a long-lived HTTP response (e.g. chunked transfer).
    /// - Parameter request: The URLRequest to execute.
    /// - Returns: An `AsyncThrowingStream<Data, Error>` yielding data chunks.
    func streamData(for request: URLRequest) -> AsyncThrowingStream<Data, Error>
}

class NetworkingServiceImpl: NSObject, NetworkingService {
    private let session: NetworkingServiceSession
    private let decoder: JSONDecoder
    
    private var delegate: URLSessionDelegate?
    private var streamingClient: NetworkStreamingClient
    
    init(session: NetworkingServiceSession, decoder: JSONDecoder = Defaults.decoder) {
        self.session = session
        self.decoder = decoder
        self.streamingClient = NetworkStreamingClient()
        super.init()
    }
    
    private func processResponse<Response: Decodable>(data: Data, response: URLResponse, request: URLRequest) async throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Failed to perform request (\(request.url?.absoluteString ?? "")): invalid response")
            throw NetworkError.invalidResponse
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            Logger.error("Bad Response. StatusCode=\(httpResponse.statusCode) \nURL=\(httpResponse.url?.absoluteString ?? "")")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["message"] as? String {
                Logger.error("""
                             **Response Error**
                             Status: \(json["status"] ?? httpResponse.statusCode)
                             Path: \(json["path"] ?? request.url?.absoluteString ?? "unknown")
                             Message: \(errorMessage)\n
                             Data: \n\(String(data: data, encoding: .utf8) ?? "\t\tnone")
                             """)
                throw NetworkError.errorResponse(code: httpResponse.statusCode, message: errorMessage)
            } else {
                Logger.error("""
                             **Response Error**
                             Status: \(httpResponse.statusCode)
                             Path: \(request.url?.absoluteString ?? "unknown")
                             Data: \n\(String(data: data, encoding: .utf8) ?? "\t\tnone")
                             """)
                switch httpResponse.statusCode {
                case 400:
                    throw NetworkError.invalidRequest
                case 401:
                    throw NetworkError.unauthorized
                case 403:
                    throw NetworkError.forbidden
                default:
                    throw NetworkError.invalidResponse
                }
            }
        }
        
        do {
            let response: Task<Response, Error> = Task.detached(priority: .userInitiated) { [unowned self] in
                // nesting this in task to make sure we're off the main thread for large payloads
                if data.isEmpty && Response.self == EmptyResponse.self {
                    // kinda hacky way to return a typed response when theres no data to decode
                    Logger.debug("Recevied empty response for (\(request.url?.absoluteString ?? ""))")
                    
                    return EmptyResponse() as! Response
                } else if Response.self == Data.self {
                    // special case for returning raw data
                    return data as! Response
                }
                let decodedResponse = try self.decoder.decode(Response.self, from: data)
                return decodedResponse
            }
            let responseValue = try await response.value
            Logger.debug("Received response for (\(request.url?.absoluteString ?? ""))")
            if let jsonString = String(data: data, encoding: .utf8) {
                let truncatedJson = jsonString.count > 2000 ? String(jsonString.prefix(2000)) + "..." : jsonString
                Logger.debug("Response JSON body for (\(request.url?.absoluteString ?? "")):\n\(truncatedJson)")
            }
            
            return responseValue
        } catch {
            let msg = (error as? DecodingError)?.prettyDescription ?? ""
            Logger.error("Failed to decode response: \(msg)\n\nData:\n\(String(data: data, encoding: .utf8) ?? "")")
            throw NetworkError.responseDecodingFailed
        }
    }
    
    // MARK: - Public
    func performRequest<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response): (Data, URLResponse)
        Logger.debug("performRequest: [\(request.httpMethod ?? "UNK")] \(request)\n\tBody: \(request.httpBody?.prettyPrintedJSONString ?? "")")
        
        do {
            (data, response) = try await session.data(for: request, delegate: nil)
        } catch {
            Logger.error("Failed to perform request (\(request.url?.absoluteString ?? "")): \(error)")
            throw NetworkError.invalidResponse
        }
        
        return try await processResponse(data: data, response: response, request: request)
    }
    
    func streamData(for request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        Logger.debug("stream data for: \(request)")
        return AsyncThrowingStream<Data, Error> { continuation in
            // Start streaming
            streamingClient.startStreaming(
                request: request,
                onData: { data in
                    if let data {
                        continuation.yield(data)
                    }
                },
                onResponse: { response in
                    Logger.debug("stream response: \(response)")
                },
                onComplete: { error in
                    if let error = error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            )
        }
    }
}
