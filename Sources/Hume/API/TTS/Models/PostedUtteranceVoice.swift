//
//  PostedUtteranceVoice.swift
//  Hume
//
//  Created by Chris on 7/1/25.
//

import Foundation

public enum PostedUtteranceVoice: Codable, Hashable {
  case id(PostedUtteranceVoiceWithId)
  case name(PostedUtteranceVoiceWithName)

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let voiceWithId = try? container.decode(PostedUtteranceVoiceWithId.self) {
      self = .id(voiceWithId)
      return
    }
    if let voiceWithName = try? container.decode(PostedUtteranceVoiceWithName.self) {
      self = .name(voiceWithName)
      return
    }

    throw DecodingError.typeMismatch(
      PostedUtteranceVoice.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription:
          "Object does not match either PostedUtteranceVoiceWithId or PostedUtteranceVoiceWithName"
      )
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .id(let value):
      try container.encode(value)
    case .name(let value):
      try container.encode(value)
    }
  }
}
