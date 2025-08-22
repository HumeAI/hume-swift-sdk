//
//  TTSTest.swift
//
//
//  Created by AI Assistant on 12/19/24.
//

import XCTest

@testable import Hume

final class TTSTest: XCTestCase {
    
    var client: HumeClient!
    
    override func setUp() {
        // Get API key from environment variable
        guard let apiKey = ProcessInfo.processInfo.environment["HUME_API_KEY"] else {
            XCTFail("HUME_API_KEY environment variable not set")
            return
        }
        
        self.client = HumeClient(options: .accessToken(token: apiKey))
    }
    
    func test_synthesizeJson_basicRequest() async throws {
        // Create a basic TTS request
        let request = PostedTts(
            context: PostedContextWithUtterances(
                utterances: [
                    PostedUtterance(
                        description: "Test utterance",
                        speed: 1.0,
                        trailingSilence: 0.5,
                        text: "Hello, this is a test of the TTS API.",
                        voice: PostedUtteranceVoiceWithName(
                            name: "test-voice",
                            provider: .humeAi
                        )
                    )
                ]
            ),
            format: Format.mp3(FormatMp3()),
            numGenerations: 1,
            splitUtterances: false,
            stripHeaders: false,
            utterances: [
                PostedUtterance(
                    description: "Test utterance",
                    speed: 1.0,
                    trailingSilence: 0.5,
                    text: "Hello, this is a test of the TTS API.",
                    voice: PostedUtteranceVoiceWithName(
                        name: "test-voice",
                        provider: .humeAi
                    )
                )
            ],
            instantMode: false
        )
        
        // Call the synthesizeJson method
        let result = try await client.tts.tts.synthesizeJson(request: request)
        
        // Verify the response structure
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.generations)
        XCTAssertNotNil(result.requestId)
        
        if let generations = result.generations {
            XCTAssertFalse(generations.isEmpty)
            
            let firstGeneration = generations[0]
            XCTAssertNotNil(firstGeneration.generationId)
            XCTAssertNotNil(firstGeneration.audio)
            XCTAssertNotNil(firstGeneration.encoding)
            XCTAssertNotNil(firstGeneration.snippets)
        }
    }
    
    func test_synthesizeJson_withCustomVoice() async throws {
        // Create a TTS request with a custom voice
        let request = PostedTts(
            context: PostedContextWithUtterances(
                utterances: [
                    PostedUtterance(
                        description: "Custom voice test",
                        speed: 1.2,
                        trailingSilence: 1.0,
                        text: "This is a test with a custom voice configuration.",
                        voice: PostedUtteranceVoiceWithName(
                            name: "custom-voice",
                            provider: .customVoice
                        )
                    )
                ]
            ),
            format: Format.wav(FormatWav()),
            numGenerations: 1,
            splitUtterances: true,
            stripHeaders: true,
            utterances: [
                PostedUtterance(
                    description: "Custom voice test",
                    speed: 1.2,
                    trailingSilence: 1.0,
                    text: "This is a test with a custom voice configuration.",
                    voice: PostedUtteranceVoiceWithName(
                        name: "custom-voice",
                        provider: .customVoice
                    )
                )
            ],
            instantMode: true
        )
        
        // Call the synthesizeJson method
        let result = try await client.tts.tts.synthesizeJson(request: request)
        
        // Verify the response
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.generations)
        XCTAssertNotNil(result.requestId)
    }
    
    func test_synthesizeJson_withMultipleUtterances() async throws {
        // Create a TTS request with multiple utterances
        let request = PostedTts(
            context: PostedContextWithUtterances(
                utterances: [
                    PostedUtterance(
                        description: "First utterance",
                        speed: 1.0,
                        trailingSilence: 0.5,
                        text: "First sentence.",
                        voice: PostedUtteranceVoiceWithName(
                            name: "test-voice",
                            provider: .humeAi
                        )
                    ),
                    PostedUtterance(
                        description: "Second utterance",
                        speed: 0.8,
                        trailingSilence: 1.0,
                        text: "Second sentence with different settings.",
                        voice: PostedUtteranceVoiceWithName(
                            name: "test-voice",
                            provider: .humeAi
                        )
                    )
                ]
            ),
            format: Format.pcm(FormatPcm()),
            numGenerations: 2,
            splitUtterances: true,
            stripHeaders: false,
            utterances: [
                PostedUtterance(
                    description: "First utterance",
                    speed: 1.0,
                    trailingSilence: 0.5,
                    text: "First sentence.",
                    voice: PostedUtteranceVoiceWithName(
                        name: "test-voice",
                        provider: .humeAi
                    )
                ),
                PostedUtterance(
                    description: "Second utterance",
                    speed: 0.8,
                    trailingSilence: 1.0,
                    text: "Second sentence with different settings.",
                    voice: PostedUtteranceVoiceWithName(
                        name: "test-voice",
                        provider: .humeAi
                    )
                )
            ],
            instantMode: false
        )
        
        // Call the synthesizeJson method
        let result = try await client.tts.tts.synthesizeJson(request: request)
        
        // Verify the response
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.generations)
        XCTAssertNotNil(result.requestId)
        
        if let generations = result.generations {
            XCTAssertEqual(generations.count, 2)
        }
    }
    
    func test_synthesizeJson_errorHandling() async throws {
        // Create an invalid request (missing required fields)
        let invalidRequest = PostedTts(
            context: PostedContextWithUtterances(
                utterances: []
            ),
            format: Format.mp3(FormatMp3()),
            numGenerations: 1,
            splitUtterances: false,
            stripHeaders: false,
            utterances: [],
            instantMode: false
        )
        
        // This should throw an error due to empty utterances
        do {
            let _ = try await client.tts.tts.synthesizeJson(request: invalidRequest)
            XCTFail("Expected error for invalid request")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is Error)
        }
    }
}
