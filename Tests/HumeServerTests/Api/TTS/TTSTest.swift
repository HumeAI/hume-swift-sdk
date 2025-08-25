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
    if let apiKey = ProcessInfo.processInfo.environment["HUME_API_KEY"] {
      // Test both authentication methods when available
      #if HUME_SERVER
      // Use API key for server-side testing
      self.client = HumeClient(options: .apiKey(key: apiKey))
      #else
      // Use access token for client-side testing
      self.client = HumeClient(options: .accessToken(token: apiKey))
      #endif
    } else {
      self.client = nil
    }
  }

  func test_synthesizeJson_basicRequest() async throws {
    // Skip test if no API key is available
    guard let client = self.client else {
      XCTSkip("HUME_API_KEY environment variable not set")
      return
    }

    // Create a basic TTS request
    let request = PostedTts(
      context: .postedContextWithUtterances(
        PostedContextWithUtterances(
          utterances: [
            PostedUtterance(
              description: "Test utterance",
              speed: 1.0,
              trailingSilence: 0.5,
              text: "Hello, this is a test of the TTS API.",
              voice: .postedUtteranceVoiceWithName(
                PostedUtteranceVoiceWithName(
                  name: "test-voice",
                  provider: .humeAi
                )
              )
            )
          ]
        )
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
          voice: .postedUtteranceVoiceWithName(
            PostedUtteranceVoiceWithName(
              name: "test-voice",
              provider: .humeAi
            )
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

    let generations = result.generations
    XCTAssertFalse(generations.isEmpty)

    let firstGeneration = generations[0]
    XCTAssertNotNil(firstGeneration.generationId)
    XCTAssertNotNil(firstGeneration.audio)
    XCTAssertNotNil(firstGeneration.encoding)
    XCTAssertNotNil(firstGeneration.snippets)
  }

  func test_synthesizeJson_errorHandling() async throws {
    // Skip test if no API key is available
    guard let client = self.client else {
      XCTSkip("HUME_API_KEY environment variable not set")
      return
    }

    // Create an invalid request (missing required fields)
    let invalidRequest = PostedTts(
      context: .postedContextWithUtterances(
        PostedContextWithUtterances(
          utterances: []
        )
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
  
  #if HUME_SERVER
  func test_apiKeyAuthentication() async throws {
    // Skip test if no API key is available
    guard let client = self.client else {
      XCTSkip("HUME_API_KEY environment variable not set")
      return
    }
    
    // Verify that the client was initialized with API key authentication
    // This test ensures that the API key option is working correctly
    XCTAssertNotNil(client)
    
    // Test a simple TTS request to verify API key authentication works
    let request = PostedTts(
      context: .postedContextWithUtterances(
        PostedContextWithUtterances(
          utterances: [
            PostedUtterance(
              description: "API Key test",
              speed: 1.0,
              trailingSilence: 0.5,
              text: "Testing API key authentication.",
              voice: .postedUtteranceVoiceWithName(
                PostedUtteranceVoiceWithName(
                  name: "test-voice",
                  provider: .humeAi
                )
              )
            )
          ]
        )
      ),
      format: Format.mp3(FormatMp3()),
      numGenerations: 1,
      splitUtterances: false,
      stripHeaders: false,
      utterances: [
        PostedUtterance(
          description: "API Key test",
          speed: 1.0,
          trailingSilence: 0.5,
          text: "Testing API key authentication.",
          voice: .postedUtteranceVoiceWithName(
            PostedUtteranceVoiceWithName(
              name: "test-voice",
              provider: .humeAi
            )
          )
        )
      ],
      instantMode: false
    )
    
    // This should work with API key authentication
    let result = try await client.tts.tts.synthesizeJson(request: request)
    XCTAssertNotNil(result)
  }
  #endif
}
