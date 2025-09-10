//
//  SessionSettingsCopyTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct SessionSettingsCopyTest {
  private func makeSettings() -> SessionSettings {
    SessionSettings(
      audio: AudioConfiguration(channels: 1, encoding: .linear16, sampleRate: 16000),
      builtinTools: [BuiltinToolConfig(fallbackContent: nil, name: .hangUp)],
      context: Context(text: "ctx", type: .temporary),
      customSessionId: "sid",
      languageModelApiKey: "lm-key",
      systemPrompt: "sys",
      tools: [
        Tool(description: nil, fallbackContent: nil, name: "t1", parameters: "{}", type: .builtin)
      ],
      variables: ["k": "v"]
    )
  }

  @Test func copy_without_overrides_returns_identical_values() async throws {
    // Arrange
    let original = makeSettings()

    // Act
    let copied = original.copy()

    // Assert
    #expect(copied.audio == original.audio)
    #expect(copied.builtinTools == original.builtinTools)
    #expect(copied.context == original.context)
    #expect(copied.customSessionId == original.customSessionId)
    #expect(copied.languageModelApiKey == original.languageModelApiKey)
    #expect(copied.systemPrompt == original.systemPrompt)
    #expect(copied.tools == original.tools)
    #expect(copied.variables == original.variables)
    #expect(copied.type == "session_settings")
  }

  @Test func copy_with_overrides_applies_new_values_and_keeps_others() async throws {
    // Arrange
    let original = makeSettings()
    let newAudio = AudioConfiguration(channels: 2, encoding: .linear16, sampleRate: 44100)
    let newBuiltinTools = [BuiltinToolConfig(fallbackContent: "fb", name: .webSearch)]
    let newContext = Context(text: "newctx", type: .persistent)
    let newTools = [
      Tool(
        description: "d", fallbackContent: "fc", name: "t2", parameters: "{\"x\":1}", type: .builtin
      )
    ]
    let newVars = ["a": "b"]

    // Act
    let copied = original.copy(
      audio: newAudio,
      builtinTools: newBuiltinTools,
      context: newContext,
      customSessionId: "sid2",
      languageModelApiKey: "lm2",
      systemPrompt: "sys2",
      tools: newTools,
      variables: newVars
    )

    // Assert
    #expect(copied.audio == newAudio)
    #expect(copied.builtinTools == newBuiltinTools)
    #expect(copied.context == newContext)
    #expect(copied.customSessionId == "sid2")
    #expect(copied.languageModelApiKey == "lm2")
    #expect(copied.systemPrompt == "sys2")
    #expect(copied.tools == newTools)
    #expect(copied.variables == newVars)
    #expect(copied.type == "session_settings")
  }
}
