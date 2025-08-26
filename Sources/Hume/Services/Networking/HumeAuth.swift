import Foundation

public enum HumeAuth {
  case accessToken(String)
  case accessTokenProvider(() async throws -> String)
  #if HUME_SERVER
  case apiKey(String)
  #endif
}

extension HumeAuth {
  func authHeader() async throws -> (String, String) {
    switch self {
    case .accessToken(let token):
      return ("Authorization", "Bearer \(token)")
    case .accessTokenProvider(let provider):
      return ("Authorization", "Bearer \(try await provider())")
    #if HUME_SERVER
    case .apiKey(let key):
      return ("X-API-Key", key)
    #endif
    }
  }
  
  func queryParam() async throws -> (String, String) {
    switch self {
    case .accessToken(let token):
      return ("accessToken", token)
    case .accessTokenProvider(let provider):
      return ("accessToken", try await provider())
    #if HUME_SERVER
    case .apiKey(let key):
      return ("apiKey", key)
    #endif
    }
  }
}
