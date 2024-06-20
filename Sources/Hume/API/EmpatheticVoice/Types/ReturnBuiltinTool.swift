//
//  ReturnBuiltinTool.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnBuiltinTool: Codable {
    
    enum CodingKeys: String, CodingKey {
        case toolType = "tool_type"
        case name = "name"
        case fallbackContent = "fallback_content"
    }
    
    let toolType: String
    let name: String
    let fallbackContent: String?

    public init(toolType: String, name: String, fallbackContent: String? = nil) {
        self.toolType = toolType
        self.name = name
        self.fallbackContent = fallbackContent
    }

}
