//
//  WebSearchReference.swift
//  HumeAI2
//
//  Created by Chris on 6/24/25.
//

import Foundation

public struct WebSearchReference: Identifiable, Codable {
    public var id: String { "\(name)_\(UUID())" }
    public let name: String
    public let url: String?
    public let content: String?
    public let opengraph: OpenGraph
    
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case content
        case opengraph
    }
}
