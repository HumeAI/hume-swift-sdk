//
//  HttpRequest.swift
//
//
//  Created by Michael Miller on 6/11/24.
//

import Foundation

internal class HttpRequest {
    
    struct RequestError: Swift.Error {
        let data: Data?
    }
    
    private let baseURL: String
    private let headers: [String: String]?
    private let queryParams: [String: Any?]?
    
    init(_ url: String, headers: [String : String]? = nil, queryParams: [String : Any?]? = nil) {
        self.baseURL = url
        self.headers = headers
        self.queryParams = queryParams
    }
    
    private func buildURL() throws -> URL {
        
        var components = URLComponents(string: self.baseURL)
        
        if let params = self.queryParams {
            
            let queryItems: [URLQueryItem] = params.compactMap { key, value in
                guard let value = value else { return nil }
                return URLQueryItem(name: key, value: String(describing: value))
            }
            
            if !queryItems.isEmpty {
                components?.queryItems = queryItems
            }
            
        }
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        return url
        
    }
    
    private func buildRequest(_ method: String, body: Encodable? = nil) throws -> URLRequest {
        
        let url = try buildURL()
        var request = URLRequest(url: url)
        
        self.headers?.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }
        
        request.httpMethod = method
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        return request
        
    }
    
    @discardableResult internal func perform(method: String, successCodes: [Int] = [200, 201, 202, 204], timeoutInterval: TimeInterval = 60.0, body: Encodable? = nil) async throws -> Data {
    
        let request = try buildRequest(method, body: body)
        
        // Create a URLSession with a custom configuration
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        let session = URLSession(configuration: configuration)
        
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Handle and return error
        if !successCodes.contains(httpResponse.statusCode) {
            throw RequestError(data: data)
        }
        
        // Return the success object
        return data
        
    }
    
}
