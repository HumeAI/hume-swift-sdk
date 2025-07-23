//
//  Voices.swift
//  Hume
//
//  Created by Chris on 6/25/25.
//

import Foundation

public class Voices {
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    // MARK: - Public

    /// Lists voices you have saved in your account, or voices from the Voice Library.
    public func list(
        provider: VoiceSourceProvider,
        pageNumber: Int? = nil,
        pageSize: Int? = nil,
        ascendingOrder: Bool? = nil,
        timeoutDuration: TimeInterval = 60,
        maxRetries: Int = 0
    ) async throws -> ListVoicesResponse {
        return try await networkClient.send(
            Endpoint.listVoices(
                provider: provider,
                pageNumber: pageNumber,
                pageSize: pageSize,
                ascendingOrder: ascendingOrder,
                timeoutDuration: timeoutDuration,
                maxRetries: maxRetries
            )
        )
    }
}


// MARK: - Endpoint Definitions
fileprivate extension Endpoint where Response == ListVoicesResponse {
    static func listVoices(
        provider: VoiceSourceProvider,
        pageNumber: Int?,
        pageSize: Int?,
        ascendingOrder: Bool?,
        timeoutDuration: TimeInterval,
        maxRetries: Int
    ) -> Endpoint<ListVoicesResponse> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "provider", value: provider.rawValue)
        ]
        if let pageNumber = pageNumber {
            queryItems.append(URLQueryItem(name: "page_number", value: String(pageNumber)))
        }
        if let pageSize = pageSize {
            queryItems.append(URLQueryItem(name: "page_size", value: String(pageSize)))
        }
        if let ascendingOrder = ascendingOrder {
            queryItems.append(URLQueryItem(name: "ascending_order", value: String(ascendingOrder)))
        }
        return Endpoint(
            path: "/v0/tts/voices",
            method: .get,
            headers: ["Content-Type": "application/json"],
            queryParams: queryItems,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutDuration: timeoutDuration,
            maxRetries: maxRetries
        )
    }
}
