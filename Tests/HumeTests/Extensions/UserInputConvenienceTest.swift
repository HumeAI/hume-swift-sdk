//
//  UserInputConvenienceTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct UserInputConvenienceTest {
  @Test func init_text_sets_properties_and_type() async throws {
    // Act
    let model = UserInput(text: "hello")

    // Assert
    #expect(model.text == "hello")
    #expect(model.customSessionId == nil)
    #expect(model.type == "user_input")
  }
}
