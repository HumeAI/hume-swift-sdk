//
//  PostedBuiltinTool.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedBuiltinTool: Codable {
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case fallbackContent = "fallback_content"
    }
    
    let name: String
    let fallbackContent: String?

    public init(name: String, fallbackContent: String? = nil) {
        self.name = name
        self.fallbackContent = fallbackContent
    }

}
