// This file is generated by generator.ts
public struct PostedUtteranceVoiceWithName: Codable, Hashable {
  public let name: String
  public let provider: TTSVoiceProvider?

  public init(
    name: String,
    provider: TTSVoiceProvider?
  ) {
    self.name = name
    self.provider = provider
  }
}
