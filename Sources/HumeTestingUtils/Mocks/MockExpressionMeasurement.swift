//
//  File.swift
//  Hume
//
//  Created by Chris on 6/24/25.
//

import Foundation
import Hume

public extension ExpressionMeasurement {
    public static func mock(_ name: String, _ value: Double) -> ExpressionMeasurement {
        return ExpressionMeasurement(name, value)
    }
}
