//
//  ReturnLanguageModel.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnLanguageModel: Codable {
    
    let modelProvider: String? = nil
    let modelResource: String? = nil
    let temperature: Double? = nil
    
    enum CodingKeys: String, CodingKey {
        case modelProvider = "model_provider"
        case modelResource = "model_resource"
        case temperature = "temperature"
    }
    
}
