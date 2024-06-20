//
//  Utils.swift
//
//
//  Created by Michael Miller on 6/11/24.
//

import Foundation

extension Encodable {
    
    func toJSON() -> String {
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(self)
            guard let str = String(data: data, encoding: .utf8) else { throw URLError(.cannotParseResponse) }
            return str
        } catch {
            return "Failed to encode \(Self.self): \(error)"
        }
        
    }
    
}
