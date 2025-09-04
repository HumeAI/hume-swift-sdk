import Foundation

typealias TokenProvider = () async throws -> AuthTokenType

protocol TokenProvidable: AnyObject {
  /// Fetches a token asynchronously
  func fetchToken() async throws -> AuthTokenType
}

enum TokenProviderError: Error {
  case unconfigured
  case invalidToken
}

enum AuthTokenType {
  case bearer(String)

  func updateRequest(_ requestBuilder: RequestBuilder) async throws -> RequestBuilder {
    switch self {
    case .bearer(let token):
      return
        requestBuilder
        .addHeader(key: "Authorization", value: "Bearer \(token)")
    }
  }
}
