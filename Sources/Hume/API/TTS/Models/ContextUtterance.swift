//
//  ContextUtterance.swift
//  Hume
//
//  Created by Chris on 7/8/25.
//

import Foundation

public struct ContextUtterance: Codable, Hashable {
    public let utterances: [PostedUtterance]
    
    public init(utterances: [PostedUtterance]) {
        self.utterances = utterances
    }
}
