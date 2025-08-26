//
//  HumeClient.swift
//
//
//  Created by Daniel Rees on 5/17/24.
//

import Foundation

public class HumeClient {
  public struct Options {
    /// Access token for client-side authentication
    public let accessToken: String?
    /// Closure that provides access token asynchronously
    public let accessTokenProvider: (() async throws -> String)?
    /// API key for server-side authentication (server-side only)
    #if HUME_SERVER
    public let apiKey: String?
    #endif
    
    /// Initialize with access token
    public init(accessToken: String) {
      self.accessToken = accessToken
      self.accessTokenProvider = nil
      #if HUME_SERVER
      self.apiKey = nil
      #endif
    }
    
    /// Initialize with access token provider
    public init(accessTokenProvider: @escaping () async throws -> String) {
      self.accessToken = nil
      self.accessTokenProvider = accessTokenProvider
      #if HUME_SERVER
      self.apiKey = nil
      #endif
    }
    
    #if HUME_SERVER
    /// Initialize with API key (server-side only)
    public init(apiKey: String) {
      self.accessToken = nil
      self.accessTokenProvider = nil
      self.apiKey = apiKey
    }
    #endif
  }
  
  private let auth: HumeAuth
  private let networkClient: NetworkClient

  public init(options: Options) {
    // Convert Options struct to HumeAuth enum
    if let accessTokenProvider = options.accessTokenProvider {
      self.auth = .accessTokenProvider(accessTokenProvider)
    } else if let accessToken = options.accessToken {
      self.auth = .accessToken(accessToken)
    } else {
      #if HUME_SERVER
      if let apiKey = options.apiKey {
        self.auth = .apiKey(apiKey)
      } else {
        fatalError("HumeClient requires either accessToken, accessTokenProvider, or apiKey")
      }
      #else
      fatalError("HumeClient requires either accessToken or accessTokenProvider")
      #endif
    }
    
    let networkingService = NetworkingServiceImpl(
      session: URLNetworkingSession())
    self.networkClient = NetworkClientImpl.makeHumeClient(
      options: self.auth,
      networkingService: networkingService)
  }
  
  // MARK: - Convenience Initializers
  
  /// Initialize with an access token
  public convenience init(accessToken: String) {
    self.init(options: Options(accessToken: accessToken))
  }
  
  /// Initialize with an access token provider closure
  public convenience init(accessTokenProvider: @escaping () async throws -> String) {
    self.init(options: Options(accessTokenProvider: accessTokenProvider))
  }
  
  #if HUME_SERVER
  /// Initialize with an API key (server-side only)
  public convenience init(apiKey: String) {
    self.init(options: Options(apiKey: apiKey))
  }
  #endif

  public lazy var empathicVoice: EmpathicVoiceClient = {
    return EmpathicVoiceClient(networkClient: networkClient, options: auth)
  }()

  public lazy var tts: TTSClient = {
    return TTSClient(networkClient: networkClient)
  }()
}
