import Foundation

public enum HumeAuth {
  case accessToken(String)
  case accessTokenProvider(() async throws -> String)
  case apiKey(String)
}

extension HumeAuth {
  /// Adds authentication to a RequestBuilder for HTTP requests
  func authenticate(_ requestBuilder: RequestBuilder) async throws -> RequestBuilder {
    switch self {
    case .accessToken(let token):
      return requestBuilder.addHeader(key: "Authorization", value: "Bearer \(token)")
    case .accessTokenProvider(let provider):
      return requestBuilder.addHeader(key: "Authorization", value: "Bearer \(try await provider())")
    case .apiKey(let key):
      return requestBuilder.addHeader(key: "X-API-Key", value: key)
    }
  }

  /// Adds authentication to URLComponents for WebSocket connections
  func authenticate(_ components: inout URLComponents) async throws {
    switch self {
    case .accessToken(let token):
      addQueryItem(&components, name: "accessToken", value: token)
    case .accessTokenProvider(let provider):
      addQueryItem(&components, name: "accessToken", value: try await provider())
    case .apiKey(let key):
      addQueryItem(&components, name: "apiKey", value: key)
    }
  }

  private func addQueryItem(_ components: inout URLComponents, name: String, value: String) {
    if components.queryItems == nil {
      components.queryItems = []
    }
    components.queryItems?.append(URLQueryItem(name: name, value: value))
  }
}
