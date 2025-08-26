//
//  HumeClient.swift
//
//
//  Created by Daniel Rees on 5/17/24.
//

import Foundation

public class HumeClient {
  /// Backward compatibility typealias
  public typealias Options = HumeAuth

  private let options: HumeClient.Options
  private let networkClient: NetworkClient

  public init(options: Options) {
    self.options = options
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      options: options,
      networkingService: networkingService)
  }

  public lazy var empathicVoice: EmpathicVoiceClient = {
    return EmpathicVoiceClient(networkClient: networkClient, options: options)
  }()

  public lazy var tts: TTSClient = {
    return TTSClient(networkClient: networkClient)
  }()
}
