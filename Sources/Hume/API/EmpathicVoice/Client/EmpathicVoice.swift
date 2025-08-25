//
//  EmpathicVoice.swift
//
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation

public class EmpathicVoice {
  private let options: HumeClient.Options
  private let networkClient: NetworkClient

  init(options: HumeClient.Options) {
    self.options = options
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      tokenProvider: { try await options.accessTokenProvider() },
      networkingService: networkingService)
  }

  public lazy var configs: Configs = { Configs(networkClient: networkClient) }()

  public lazy var chat: Chat = { Chat(options: options) }()
}
