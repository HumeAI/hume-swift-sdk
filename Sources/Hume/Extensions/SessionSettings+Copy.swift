// Adds a convenience `copy` helper to non-generated SessionSettings without modifying generated code.

import Foundation

extension SessionSettings {
  public func copy(
    audio: AudioConfiguration? = nil,
    builtinTools: [BuiltinToolConfig]? = nil,
    context: Context? = nil,
    customSessionId: String? = nil,
    languageModelApiKey: String? = nil,
    systemPrompt: String? = nil,
    tools: [Tool]? = nil,
    variables: [String: String]? = nil,
    voiceId: String? = nil
  ) -> SessionSettings {
    SessionSettings(
      audio: audio ?? self.audio,
      builtinTools: builtinTools ?? self.builtinTools,
      context: context ?? self.context,
      customSessionId: customSessionId ?? self.customSessionId,
      languageModelApiKey: languageModelApiKey ?? self.languageModelApiKey,
      systemPrompt: systemPrompt ?? self.systemPrompt,
      tools: tools ?? self.tools,
      variables: variables ?? self.variables,
      voiceId: voiceId ?? self.voiceId
    )
  }
}
