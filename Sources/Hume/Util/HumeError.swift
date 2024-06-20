//
//  HumeError.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct HumeError: Swift.Error, Codable {
    
    enum CodingKeys: String, CodingKey {
        case timestamp = "timestamp"
        case status = "status"
        case error = "error"
        case message = "message"
        case path = "path"
    }
    
    let timestamp: String?
    let status: Int?
    let error: String?
    let message: String?
    let path: String?
    
    public init(timestamp: String? = nil, status: Int? = nil, error: String? = nil, message: String? = nil, path: String? = nil) {
        self.timestamp = timestamp
        self.status = status
        self.error = error
        self.message = message
        self.path = path
    }
    
}
