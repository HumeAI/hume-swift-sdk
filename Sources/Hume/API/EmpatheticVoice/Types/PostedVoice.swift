//
//  PostedVoice.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedVoice: Codable {
    
    enum CodingKeys: String, CodingKey {
        case provider = "provider"
        case name = "name"
    }
    
    let provider: String
    let name: PostedVoiceName

    public init(provider: String = "HUME_AI", name: PostedVoiceName) {
        self.provider = provider
        self.name = name
    }

}
