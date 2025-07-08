//
//  File.swift
//  Hume
//
//  Created by Chris on 6/25/25.
//

import Foundation

public class TTS {
    
    // MARK: - Properties
    private let networkClient: NetworkClient
    
    // MARK: - Initialization
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    // MARK: - Public
    
    /// Synthesizes one or more input texts into speech using the specified voice.
    /// If no voice is provided, a novel voice will be generated dynamically.
    /// Optionally, additional context can be included to influence the speech’s style and prosody.
    public func synthesizeJson(
        request: PostedTts,
        timeoutDuration: TimeInterval = 120,
        maxRetries: Int = 0
    ) async throws -> ReturnTts {
        return try await networkClient.send(
            Endpoint.synthesizeJson(request: request,
                                    timeoutDuration: timeoutDuration,
                                    maxRetries: maxRetries)
        )
    }
    
    /// Synthesizes one or more input texts into speech using the specified voice.
    /// If no voice is provided, a novel voice will be generated dynamically.
    /// Optionally, additional context can be included to influence the speech's style and prosody.
    /// The response contains the generated audio file in the requested format.
    public func synthesizeFile(
        request: PostedTts,
        timeoutDuration: TimeInterval = 120,
        maxRetries: Int = 0) async throws -> Data {
            return try await networkClient.send(
                Endpoint.synthesizeFile(request: request,
                                        timeoutDuration: timeoutDuration,
                                        maxRetries: maxRetries)
            )
        }
    
    /// Streams synthesized speech using the specified voice. If no voice is provided, a novel voice will be generated dynamically.
    /// Optionally, additional context can be included to influence the speech's style and prosody.
    public func synthesizeFileStreaming(
        request: PostedTtsStream,
        timeoutDuration: TimeInterval = 300,
        maxRetries: Int = 0
    ) -> AsyncThrowingStream<Data, Error> {
        return networkClient.stream(
            Endpoint.synthesizeFileStream(request: request,
                                          timeoutDuration: timeoutDuration,
                                          maxRetries: maxRetries)
        )
    }
    
    /// Streams synthesized speech using the specified voice. If no voice is provided, a novel voice will be generated dynamically.
    /// Optionally, additional context can be included to influence the speech's style and prosody.
    /// The response is a stream of `SnippetAudioChunk` objects including audio encoded in base64.
    public func synthesizeJsonStreaming(
        request: PostedTtsStream,
        timeoutDuration: TimeInterval = 300,
        maxRetries: Int = 0
    ) -> AsyncThrowingStream<SnippetAudioChunk, Error> {
        return networkClient.stream(
            Endpoint.synthesizeJsonStream(request: request,
                                          timeoutDuration: timeoutDuration,
                                          maxRetries: maxRetries)
        )
    }
    
}

// MARK: - Endpoint Definitions
fileprivate extension Endpoint where Response == ReturnTts {
    static func synthesizeJson(
        request: PostedTts,
        timeoutDuration: TimeInterval,
        maxRetries: Int
    ) -> Endpoint<ReturnTts> {
        Endpoint(
            path: "/v0/tts",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: request,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutDuration: timeoutDuration,
            maxRetries: maxRetries)
    }
}

fileprivate extension Endpoint where Response == Data {
    static func synthesizeFile(
        request: PostedTts,
        timeoutDuration: TimeInterval,
        maxRetries: Int
    ) -> Endpoint<Data> {
        return Endpoint(
            path: "/v0/tts/file",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: request,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutDuration: timeoutDuration,
            maxRetries: maxRetries
        )
    }
}

// MARK: Streaming
fileprivate extension Endpoint where Response == SnippetAudioChunk {
    static func synthesizeJsonStream(
        request: PostedTtsStream,
        timeoutDuration: TimeInterval,
        maxRetries: Int
    ) -> Endpoint<SnippetAudioChunk> {
        print(request)
        return Endpoint(
            path: "/v0/tts/stream/json",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: request,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutDuration: timeoutDuration,
            maxRetries: maxRetries
        )
    }
}

fileprivate extension Endpoint where Response == Data {
    static func synthesizeFileStream(
        request: PostedTtsStream,
        timeoutDuration: TimeInterval,
        maxRetries: Int
    ) -> Endpoint<Data> {
        return Endpoint(
            path: "/v0/tts/stream/file",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: request,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutDuration: timeoutDuration,
            maxRetries: maxRetries
        )
    }
}
