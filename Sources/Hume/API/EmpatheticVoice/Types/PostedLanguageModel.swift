//
//  PostedLanguageModel.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct PostedLanguageModel: Codable {
    
    enum CodingKeys: String, CodingKey {
        case modelProvider = "model_provider"
        case modelResource = "model_resource"
        case temperature = "temperature"
    }
    
    let modelProvider: PostedLanguageModelModelProvider?
    let modelResource: String?
    let temperature: Double?

    public init(modelProvider: PostedLanguageModelModelProvider? = nil, modelResource: String? = nil, temperature: Double? = nil) {
        self.modelProvider = modelProvider
        self.modelResource = modelResource
        self.temperature = temperature
    }

}
