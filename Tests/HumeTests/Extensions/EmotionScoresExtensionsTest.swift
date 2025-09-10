//
//  EmotionScoresExtensionsTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct EmotionScoresExtensionsTest {
  @Test func topThree_returns_top3_sorted_desc() async throws {
    // Arrange
    let scores: EmotionScores = [
      "Joy": 0.9,
      "Sadness": 0.1,
      "Anger": 0.7,
      "Calmness": 0.8,
      "Boredom": 0.05,
    ]

    // Act
    let top = scores.topThree

    // Assert
    #expect(top.count == 3)
    #expect(top[0].name == "Joy" && top[0].value == 0.9)
    #expect(top[1].name == "Calmness" && top[1].value == 0.8)
    #expect(top[2].name == "Anger" && top[2].value == 0.7)
  }

  @Test func topThree_handles_fewer_than_three_entries() async throws {
    // Arrange
    let scores: EmotionScores = ["Joy": 0.2, "Calmness": 0.3]

    // Act
    let top = scores.topThree

    // Assert
    #expect(top.count == 2)
    #expect(Set(top.map { $0.name }) == Set(["Calmness", "Joy"]))
    #expect(top[0].value >= top[1].value)
  }

  @Test func topThree_on_empty_returns_empty() async throws {
    // Arrange
    let scores: EmotionScores = [:]

    // Act
    let top = scores.topThree

    // Assert
    #expect(top.isEmpty)
  }
}
