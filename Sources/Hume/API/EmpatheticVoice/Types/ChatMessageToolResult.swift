//
//  ChatMessageToolResult.swift
//  
//
//  Created by Daniel Rees on 5/27/24.
//

import Foundation


public enum ChatMessageToolResult: Codable {
    case toolResponseMessage(ToolResponseMessage)
    case toolErrorMessage(ToolErrorMessage)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "tool_response":
            self = .toolResponseMessage(try ToolResponseMessage(from: decoder))
        case "tool_error":
            self = .toolErrorMessage(try ToolErrorMessage(from: decoder))
        default:
            throw HumeError(message: type)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .toolErrorMessage(let message):
            try message.encode(to: encoder)
        case .toolResponseMessage(let message):
            try message.encode(to: encoder)
        }
    }
}
