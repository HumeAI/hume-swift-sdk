//
//  AssistantInputExtensionsTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct AssistantInputExtensionsTest {

  @Test func init_text_sets_nil_sessionId_and_text_matches() async throws {
    // Arrange
    let inputText = "Hello, Assistant!"

    // Act
    let sut = AssistantInput(text: inputText)

    // Assert
    #expect(sut.customSessionId == nil)
    #expect(sut.text == inputText)
  }

}
