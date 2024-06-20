//
//  ReturnUserDefinedTool.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

public struct ReturnUserDefinedTool: Codable {
    
    enum CodingKeys: String, CodingKey {
        case toolType = "tool_type"
        case id = "id"
        case version = "version"
        case versionType = "version_type"
        case name = "name"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case parameters = "parameters"
        case versionDescription = "version_description"
        case fallbackContent = "fallback_content"
        case description = "description"
    }
    
    let toolType: String
    let id: String
    let version: Int
    let versionType: String
    let name: String
    let createdOn: Int
    let modifiedOn: Int
    let parameters: String
    let versionDescription: String?
    let fallbackContent: String?
    let description: String?

    public init(toolType: String, id: String, version: Int, versionType: String, name: String, createdOn: Int, modifiedOn: Int, parameters: String, versionDescription: String? = nil, fallbackContent: String? = nil, description: String? = nil) {
        self.toolType = toolType
        self.id = id
        self.version = version
        self.versionType = versionType
        self.name = name
        self.createdOn = createdOn
        self.modifiedOn = modifiedOn
        self.parameters = parameters
        self.versionDescription = versionDescription
        self.fallbackContent = fallbackContent
        self.description = description
    }

}
