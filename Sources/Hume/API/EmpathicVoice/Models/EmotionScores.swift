//
//  EmotionScores.swift
//
//
//  Created by Daniel Rees on 5/19/24.
//

import Foundation

public typealias EmotionScores = [String: Double]
public struct ExpressionMeasurement {
    public let name: String
    public let value: Double
    
    package init(_ name: String, _ value: Double) {
        self.name = name
        self.value = value
    }
}

extension EmotionScores {
    public var topThree: [ExpressionMeasurement] {
        get {
            return self
                .sorted { $0.value >= $1.value }
                .prefix(3)
                .map(ExpressionMeasurement.init)
        }
    }
}
