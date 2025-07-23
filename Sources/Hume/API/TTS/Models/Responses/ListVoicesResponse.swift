//
//  ListVoicesResponse.swift
//  Hume
//
//  Created by Chris on 7/18/25.
//

import Foundation

public struct ListVoicesResponse: Codable, Hashable {
    public let pageNumber: Int?
    public let pageSize: Int?
    public let totalPages: Int?
    public let voicesPage: [ReturnVoice]?

    enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case pageSize = "page_size"
        case totalPages = "total_pages"
        case voicesPage = "voices_page"
    }
}
