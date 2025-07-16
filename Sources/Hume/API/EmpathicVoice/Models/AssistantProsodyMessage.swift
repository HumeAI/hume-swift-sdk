//
//  AssistantProsodyMessage.swift
//  Hume
//
//  Created by Chris on 7/15/25.
//


import Foundation

public struct AssistantProsodyMessage: Codable {
    /** ID of the message. */
    public let id: String
    /** Inference model results. */
    public let models: Inference
    public let type: String

    public init(id: String, models: Inference, type: String) {
        self.id = id
        self.models = models
        self.type = type
    }
}
