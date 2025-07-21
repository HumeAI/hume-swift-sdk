//
//  ContextGenerationId.swift
//  Hume
//
//  Created by Chris on 7/8/25.
//

import Foundation

public struct ContextGenerationId: Codable, Hashable {
  public let generationId: String

  /// - Parameters:
  ///   - generationId: The ID of a prior TTS generation to use as context for generating consistent speech style and prosody across multiple requests. Including context may increase audio generation times.
  public init(generationId: String) {
    self.generationId = generationId
  }
}
