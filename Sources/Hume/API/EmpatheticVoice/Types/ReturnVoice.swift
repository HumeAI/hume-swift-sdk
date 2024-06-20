//
//  File.swift
//  
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnVoice: Codable {
    
    enum CodingKeys: String, CodingKey {
        case provider = "provider"
        case name = "name"
    }
    
    let provider: String
    let name: String
    
    public init(provider: String, name: String) {
        self.provider = provider
        self.name = name
    }

}
