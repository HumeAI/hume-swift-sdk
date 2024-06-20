//
//  PostedLanguageModelModelProvider.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public enum PostedLanguageModelModelProvider: String, Codable {
    case openAi = "OPEN_AI"
    case customLanguageModel = "CUSTOM_LANGUAGE_MODEL"
    case anthropic = "ANTHROPIC"
    case fireworks = "FIREWORKS"
    case groq = "GROQ"
}
