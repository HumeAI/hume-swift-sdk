//
//  NetworkStreamingClient.swift
//  Hume
//
//  Created by Chris on 7/1/25.
//

import Foundation

class NetworkStreamingClient: NSObject, URLSessionDataDelegate {
    // MARK: - Typealiases
    typealias DataHandler = (_ data: Data?) -> Void
    typealias ResponseHandler = (_ response: URLResponse?) -> Void
    typealias CompleteHandler = (_ error: Error?) -> Void
    
    // MARK: - Properties
    private var urlSession: URLSession!
    private var dataHandler: DataHandler?
    private var responseHandler: ResponseHandler?
    private var completeHandler: CompleteHandler?
    
    // MARK: - Init
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public API
    func startStreaming(
        request: URLRequest,
        onData: @escaping DataHandler,
        onResponse: @escaping ResponseHandler,
        onComplete: @escaping CompleteHandler
    ) {
        // Store handlers for delegate callbacks
        self.dataHandler = onData
        self.responseHandler = onResponse
        self.completeHandler = onComplete
        
        let task = urlSession.dataTask(with: request)
        task.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataHandler?(data)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Call response handler once with the URLResponse
        responseHandler?(response)
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completeHandler?(error)
    }
}
