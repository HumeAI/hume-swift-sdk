//
//  ReturnConfig.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnConfig: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case version = "version"
        case versionDescription = "version_description"
        case name = "name"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case prompt = "prompt"
        case voice = "voice"
        case languageModel = "language_model"
        case tools = "tools"
        case builtinTools = "builtin_tools"
    }
    
    let id: String?
    let version: Int?
    let versionDescription: String?
    let name: String?
    let createdOn: Int?
    let modifiedOn: Int?
    let prompt: ReturnPrompt?
    let voice: ReturnVoice?
    let languageModel: ReturnLanguageModel?
    let tools: [ReturnUserDefinedTool?]?
    let builtinTools: [ReturnBuiltinTool?]?
    
    public init(id: String? = nil, version: Int? = nil, versionDescription: String? = nil, name: String? = nil, createdOn: Int? = nil, modifiedOn: Int? = nil, prompt: ReturnPrompt? = nil, voice: ReturnVoice? = nil, languageModel: ReturnLanguageModel? = nil, tools: [ReturnUserDefinedTool?]? = nil, builtinTools: [ReturnBuiltinTool?]? = nil) {
        self.id = id
        self.version = version
        self.versionDescription = versionDescription
        self.name = name
        self.createdOn = createdOn
        self.modifiedOn = modifiedOn
        self.prompt = prompt
        self.voice = voice
        self.languageModel = languageModel
        self.tools = tools
        self.builtinTools = builtinTools
    }
    
}
