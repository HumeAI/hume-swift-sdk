#if HUME_IOS
//
//  VoiceProviderFactory.swift
//  Hume
//
//  Created by Chris on 9/10/25.
//

import Foundation

public class VoiceProviderFactory {
  public static let shared = VoiceProviderFactory()

  private static var voiceProvider: VoiceProvider?

  /// Get a single instance of `VoiceProvider`. Subsequent calls will return the same instance.
  public func getVoiceProvider(client: HumeClient) -> VoiceProvider {
    if let existingProvider = Self.voiceProvider {
      return existingProvider
    }
    Self.voiceProvider = VoiceProvider(with: client)
    return Self.voiceProvider!
  }
}
#endif
