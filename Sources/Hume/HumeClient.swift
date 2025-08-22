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
  }

  private let options: HumeClient.Options
  private let networkClient: NetworkClient

  public init(options: Options) {
    self.options = options
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      tokenProvider: { try await options.accessTokenProvider() },
      networkingService: networkingService)
  }

  public lazy var empathicVoice: EmpathicVoice = {
    return EmpathicVoice(options: options)
  }()

  public lazy var tts: TTSClient = {
    return TTSClient(networkClient: networkClient)
  }()
}

extension HumeClient.Options {
  func accessTokenProvider() async throws -> AuthTokenType {
    switch self {
    case .accessToken(let token):
      return .bearer(token)
    case .accessTokenProvider(let tokenProvider):
      return try await .bearer(tokenProvider())
    }
  }
}
