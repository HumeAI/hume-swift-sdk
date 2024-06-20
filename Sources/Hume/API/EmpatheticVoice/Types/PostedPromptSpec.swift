//
//  PostedPromptSpec.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedPromptSpec: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case version = "version"
    }
    
    let id: String
    let version: Int?

    public init(id: String, version: Int? = nil) {
        self.id = id
        self.version = version
    }

}
