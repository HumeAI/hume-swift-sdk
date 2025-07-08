//
//  PostedContext.swift
//  Hume
//
//  Created by Chris on 7/8/25.
//

import Foundation

public enum PostedContext: Codable, Hashable {
    case generationId(ContextGenerationId)
    case utterance(ContextUtterance)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let generationId = try? container.decode(ContextGenerationId.self) {
            self = .generationId(generationId)
        } else if let utterances = try? container.decode([PostedUtterance].self) {
            self = .utterance(.init(utterances: utterances))
        }
        
        throw DecodingError.typeMismatch(
            PostedContext.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid value for PostedContext"
            )
        )
    }
}
