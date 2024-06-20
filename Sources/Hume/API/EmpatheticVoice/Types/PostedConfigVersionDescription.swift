//
//  PostedConfigVersionDescription.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedConfigVersionDescription: Codable {
    
    enum CodingKeys: String, CodingKey {
        case versionDescription = "version_description"
    }
    
    let versionDescription: String?
    
}
