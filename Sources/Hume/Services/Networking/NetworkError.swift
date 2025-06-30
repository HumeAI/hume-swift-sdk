import Foundation

enum NetworkError: Error, LocalizedError, Equatable {
    case authenticationError
    case unauthorized
    case forbidden
    case invalidRequest
    case invalidResponse
    case errorResponse(code: Int, message: String?)
    case noData
    case requestDecodingFailed
    case responseDecodingFailed
    case unknownMessageType
    case unknown

    var errorDescription: String? {
        switch self {
        case .authenticationError:
            return "The authentication credentials were invalid."
        case .unauthorized:
            return "The authentication credentials were unauthorized."
        case .forbidden:
            return "The authentication credentials were forbidden"
        case .invalidRequest:
            return "The network request could not be created."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .errorResponse(let code, let message):
            return "Error \(code): \(message ?? "No message provided")."
        case .noData:
            return "No data was returned from the server."
        case .requestDecodingFailed:
            return "Failed to decode the request data."
        case .responseDecodingFailed:
            return "Failed to decode the response data."
        case .unknownMessageType:
            return "Received an unknown message type from the WebSocket."
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
