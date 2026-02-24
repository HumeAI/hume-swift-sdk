//
//  AudioOutputExtensionsTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct AudioOutputExtensionsTest {

  @Test func asBase64EncodedData_returns_data_for_valid_base64() async throws {
    // Arrange
    let bytes = Data([0x61, 0x62, 0x63])  // "abc"
    let base64 = bytes.base64EncodedString()  // "YWJj"
    let model = AudioOutput(
      type: "audio_output",
      customSessionId: nil,
      id: "id1",
      index: 0,
      data: base64
    )

    // Act
    let decoded = model.asBase64EncodedData

    // Assert
    #expect(decoded == bytes)
  }

  @Test func asBase64EncodedData_returns_nil_for_invalid_base64() async throws {
    // Arrange
    let model = AudioOutput(
      type: "audio_output",
      customSessionId: nil,
      id: "id2",
      index: 1,
      data: "not-base64!!"
    )

    // Act
    let decoded = model.asBase64EncodedData

    // Assert
    #expect(decoded == nil)
  }

}
