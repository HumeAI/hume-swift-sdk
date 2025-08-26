//
//  HumeClient.swift
//
//
//  Created by Daniel Rees on 5/17/24.
//

import Foundation

public class HumeClient {
  public enum Options {
    /// Use an access token with the Hume APIs
    case accessToken(token: String)
    /// Use a closure to provide an access token asynchronously
    case accessTokenProvider(() async throws -> String)
    /// Use an API key with the Hume APIs
    case apiKey(key: String)
  }

  private let options: HumeClient.Options
  private let networkClient: NetworkClient

  public init(options: Options) {
    if case .apiKey = options, !Self.isRunningOnServer {
      fatalError("API key authentication is only supported in server-side environments.")
    }
    self.options = options
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      auth: options.toHumeAuth(),
      networkingService: networkingService)
  }

  public lazy var empathicVoice: EmpathicVoice = {
    return EmpathicVoice(auth: options.toHumeAuth())
  }()

  public lazy var tts: TTSClient = {
    return TTSClient(networkClient: networkClient)
  }()
}



extension HumeClient.Options {
  func toHumeAuth() -> HumeAuth {
    switch self {
    case .accessToken(let token):
      return .accessToken(token)
    case .accessTokenProvider(let provider):
      return .accessTokenProvider(provider)
    case .apiKey(let key):
      return .apiKey(key)
    }
  }
}