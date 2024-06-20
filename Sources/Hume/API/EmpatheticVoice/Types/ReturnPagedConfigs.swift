//
//  ReturnPagedConfigs.swift
//
//
//  Created by Michael Miller on 6/13/24.
//

import Foundation

public struct ReturnPagedConfigs: Codable {
    
    enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case pageSize = "page_size"
        case configsPage = "configs_page"
    }
    
    let pageNumber: Int?
    let pageSize: Int?
    let configsPage: [ReturnConfig]?
    
    public init(pageNumber: Int? = nil, pageSize: Int? = nil, configsPage: [ReturnConfig]? = nil) {
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        self.configsPage = configsPage
    }
    
}
