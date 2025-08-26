import Foundation

// MARK: - Backward compatibility types for custom token providers
// These are kept for backward compatibility with NetworkClient.send(customTokenProvider:)

typealias TokenProvider = () async throws -> AuthTokenType

enum AuthTokenType {
  case bearer(String)
  #if HUME_SERVER
  case apiKey(String)
  #endif

  func updateRequest(_ requestBuilder: RequestBuilder) async throws -> RequestBuilder {
    switch self {
    case .bearer(let token):
      return
        requestBuilder
        .addHeader(key: "Authorization", value: "Bearer \(token)")
    #if HUME_SERVER
    case .apiKey(let key):
      return
        requestBuilder
        .addHeader(key: "X-API-Key", value: key)
    #endif
    }
  }
}
