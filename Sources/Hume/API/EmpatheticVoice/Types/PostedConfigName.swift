//
//  PostedConfigName.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedConfigName: Codable {
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
    }
    
    let name: String?
    
}
