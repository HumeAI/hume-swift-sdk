//
//  RequestBuilder.swift
//  Hume
//
//  Created by Chris on 6/11/25.
//
//

import Foundation

class RequestBuilder {
    private var baseURL: URL
    private var path: String = ""
    private var method: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var queryParams: [String: String] = [:]
    private var body: Data?
    private var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    private var timeoutInterval: TimeInterval = 60  // Default 60 second timeout
    
    private let jsonEncoder: JSONEncoder

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.jsonEncoder = Defaults.encoder
        jsonEncoder.outputFormatting = [.withoutEscapingSlashes]
    }
    
    func setPath(_ path: String) -> RequestBuilder {
        self.path = path
        return self
    }
    
    func setMethod(_ method: HTTPMethod) -> RequestBuilder {
        self.method = method
        return self
    }
    
    func addHeader(key: String, value: String) -> RequestBuilder {
        self.headers[key] = value
        return self
    }
    
    func setHeaders(_ headers: [String: String]) -> RequestBuilder {
        self.headers = headers
        return self
    }
    
    func setQueryParams(_ params: [String: String]) -> RequestBuilder {
        self.queryParams = params
        return self
    }
    
    func setBody(_ encodable: Encodable?) -> RequestBuilder {
        if let encodable = encodable {
            self.body = try? jsonEncoder.encode(encodable)
        }
        return self
    }
    
    func setCachePolicy(_ policy: URLRequest.CachePolicy) -> RequestBuilder {
        self.cachePolicy = policy
        return self
    }
    
    func setTimeout(_ timeout: TimeInterval) -> RequestBuilder {
        self.timeoutInterval = timeout
        return self
    }

    func build() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryParams.isEmpty {
            components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        request.cachePolicy = cachePolicy
        request.timeoutInterval = timeoutInterval
        return request
    }
}
