//
//  ReturnPrompt.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnPrompt: Codable {

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case version = "version"
        case versionType = "version_type"
        case name = "name"
        case createdOn = "created_on"
        case modifiedOn = "modified_on"
        case text = "text"
        case versionDescription = "version_description"
    }
    
    let id: String
    let version: Int
    let versionType: String
    let name: String
    let createdOn: Int
    let modifiedOn: Int
    let text: String
    let versionDescription: String?

    public init(id: String, version: Int, versionType: String, name: String, createdOn: Int, modifiedOn: Int, text: String, versionDescription: String? = nil) {
        self.id = id
        self.version = version
        self.versionType = versionType
        self.name = name
        self.createdOn = createdOn
        self.modifiedOn = modifiedOn
        self.text = text
        self.versionDescription = versionDescription
    }

}
