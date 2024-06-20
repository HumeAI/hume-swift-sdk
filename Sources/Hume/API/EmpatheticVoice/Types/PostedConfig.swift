//
//  PostedConfig.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedConfig: Codable {
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case versionDescription = "version_description"
        case prompt = "prompt"
        case voice = "voice"
        case languageModel = "language_model"
        case tools = "tools"
        case builtinTools = "builtin_tools"
    }
    
    let name: String
    let versionDescription: String?
    let prompt: PostedPromptSpec?
    let voice: PostedVoice?
    let languageModel: PostedLanguageModel?
    let tools: [PostedUserDefinedToolSpec?]?
    let builtinTools: [PostedBuiltinTool?]?
    
}
