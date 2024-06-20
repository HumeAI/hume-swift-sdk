//
//  PostedConfigVersion.swift
//  
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedConfigVersion: Codable {
    
    enum CodingKeys: String, CodingKey {
        case versionDescription = "version_description"
        case prompt = "prompt"
        case voice = "voice"
        case languageModel = "language_model"
        case tools = "tools"
        case builtinTools = "builtin_tools"
    }
    
    let versionDescription: String?
    let prompt: PostedPromptSpec?
    let voice: PostedVoice?
    let languageModel: PostedLanguageModel?
    let tools: [PostedUserDefinedToolSpec?]?
    let builtinTools: [PostedBuiltinTool?]?
    
}
