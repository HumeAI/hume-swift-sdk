//
//  HumeClient.swift
//
//
//  Created by Daniel Rees on 5/17/24.
//

import Foundation

public class HumeClient {
  public enum Options {
    case accessToken(token: String)
    case accessTokenProvider(() async throws -> String)
    case apiKey(key: String)
  }

  private let options: HumeClient.Options
  private let networkClient: NetworkClient

  public init(options: Options) {
    self.options = options
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      auth: options.toHumeAuth(),
      networkingService: networkingService)
  }

  public lazy var empathicVoice: EmpathicVoiceClient = {
    return EmpathicVoiceClient(networkClient: networkClient, auth: options.toHumeAuth())
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
