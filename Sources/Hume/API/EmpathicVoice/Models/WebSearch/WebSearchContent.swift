//
//  WebSearchContent.swift
//  HumeAI2
//
//  Created by Chris on 6/24/25.
//

import Foundation

public struct WebSearchContent: Codable {
    public let summary: String?
    public let references: [WebSearchReference]
}

public extension WebSearchContent {
    static func from(toolResponseMessage: ToolResponseMessage) -> WebSearchContent? {
        guard let data = toolResponseMessage.content.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(WebSearchContent.self, from: data)
    }
}
