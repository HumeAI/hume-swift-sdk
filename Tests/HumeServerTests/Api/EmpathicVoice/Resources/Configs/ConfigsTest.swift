//
//  ConfigsTest.swift
//
//
//  Created by AI Assistant on 12/19/24.
//

import XCTest

@testable import Hume

final class ConfigsTest: XCTestCase {
    
    var client: HumeClient!
    
    override func setUp() {
        // Get API key from environment variable
        guard let apiKey = ProcessInfo.processInfo.environment["HUME_API_KEY"] else {
            XCTFail("HUME_API_KEY environment variable not set")
            return
        }
        
        self.client = HumeClient(options: .accessToken(token: apiKey))
    }
    
    func test_createConfig_basicConfig() async throws {
        // Create a basic EVI config
        let request = EviPostedConfig(
            eviVersion: "3",
            name: "Test Config \(UUID().uuidString)",
            versionDescription: "A test configuration for testing purposes",
            prompt: EviPostedConfigPromptSpec(
                id: "test-prompt-id",
                version: "1.0",
                text: "You are a helpful AI assistant. Please respond to user queries in a friendly manner."
            ),
            voice: EviVoiceRef.voiceName(VoiceName(
                name: "test-voice",
                provider: .humeAi
            )),
            languageModel: EviPostedLanguageModel(
                modelProvider: "openai",
                modelResource: "gpt-4",
                temperature: 0.7
            ),
            ellmModel: EviPostedEllmModel(
                allowShortResponses: true
            ),
            tools: nil,
            builtinTools: [
                EviPostedBuiltinTool(
                    name: "web_search",
                    fallbackContent: "I couldn't search the web for that information."
                )
            ],
            eventMessages: EviPostedEventMessageSpecs(
                onNewChat: EviPostedEventMessageSpec(
                    enabled: true,
                    text: "Hello! I'm here to help you."
                ),
                onInactivityTimeout: EviPostedEventMessageSpec(
                    enabled: true,
                    text: "I haven't heard from you in a while. Are you still there?"
                ),
                onMaxDurationTimeout: EviPostedEventMessageSpec(
                    enabled: true,
                    text: "Our conversation has reached the maximum duration. Thank you for chatting with me!"
                )
            ),
            nudges: EviPostedNudgeSpec(
                enabled: true,
                intervalSecs: 30
            ),
            timeouts: EviPostedTimeoutSpecs(
                inactivity: Inactivity(
                    durationSecs: 300,
                    enabled: true
                ),
                maxDuration: MaxDuration(
                    durationSecs: 3600,
                    enabled: true
                )
            ),
            webhooks: nil
        )
        
        // Call the createConfig method
        let result = try await client.empathicVoice.configs.createConfig(request: request)
        
        // Verify the response structure
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.id)
        XCTAssertNotNil(result.name)
        XCTAssertNotNil(result.eviVersion)
        XCTAssertNotNil(result.version)
        
        // Verify the returned values match the request
        XCTAssertEqual(result.name, request.name)
        XCTAssertEqual(result.eviVersion, request.eviVersion)
        XCTAssertEqual(result.versionDescription, request.versionDescription)
        
        // Verify the config was created with the expected structure
        XCTAssertNotNil(result.prompt)
        XCTAssertNotNil(result.voice)
        XCTAssertNotNil(result.languageModel)
        XCTAssertNotNil(result.ellmModel)
        XCTAssertNotNil(result.builtinTools)
        XCTAssertNotNil(result.eventMessages)
        XCTAssertNotNil(result.nudges)
        XCTAssertNotNil(result.timeouts)
    }
    
    func test_createConfig_minimalConfig() async throws {
        // Create a minimal EVI config with only required fields
        let request = EviPostedConfig(
            eviVersion: "2",
            name: "Minimal Config \(UUID().uuidString)",
            versionDescription: nil,
            prompt: nil,
            voice: nil,
            languageModel: nil,
            ellmModel: nil,
            tools: nil,
            builtinTools: nil,
            eventMessages: nil,
            nudges: nil,
            timeouts: nil,
            webhooks: nil
        )
        
        // Call the createConfig method
        let result = try await client.empathicVoice.configs.createConfig(request: request)
        
        // Verify the response
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.name, request.name)
        XCTAssertEqual(result.eviVersion, request.eviVersion)
    }
    
    func test_createConfig_withCustomTools() async throws {
        // Create an EVI config with custom tools
        let request = EviPostedConfig(
            eviVersion: "3",
            name: "Custom Tools Config \(UUID().uuidString)",
            versionDescription: "Config with custom tools",
            prompt: EviPostedConfigPromptSpec(
                id: "custom-tools-prompt",
                version: "1.0",
                text: "You have access to custom tools. Use them when appropriate."
            ),
            voice: EviVoiceRef.voiceId(VoiceId(
                id: "custom-voice-id",
                provider: .customVoice
            )),
            languageModel: EviPostedLanguageModel(
                modelProvider: "anthropic",
                modelResource: "claude-3-sonnet",
                temperature: 0.5
            ),
            ellmModel: EviPostedEllmModel(
                allowShortResponses: false
            ),
            tools: [
                EviPostedUserDefinedToolSpec(
                    id: "custom-tool-1",
                    version: "1.0"
                ),
                EviPostedUserDefinedToolSpec(
                    id: "custom-tool-2",
                    version: "2.0"
                )
            ],
            builtinTools: [
                EviPostedBuiltinTool(
                    name: "web_search",
                    fallbackContent: "Web search unavailable"
                ),
                EviPostedBuiltinTool(
                    name: "hang_up",
                    fallbackContent: "Unable to end call"
                )
            ],
            eventMessages: nil,
            nudges: nil,
            timeouts: nil,
            webhooks: [
                EviPostedWebhookSpec(
                    url: "https://example.com/webhook",
                    events: ["chat_started", "chat_ended"]
                )
            ]
        )
        
        // Call the createConfig method
        let result = try await client.empathicVoice.configs.createConfig(request: request)
        
        // Verify the response
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.id)
        XCTAssertEqual(result.name, request.name)
        XCTAssertEqual(result.eviVersion, request.eviVersion)
        
        // Verify tools were created
        XCTAssertNotNil(result.tools)
        XCTAssertNotNil(result.builtinTools)
        XCTAssertNotNil(result.webhooks)
        
        if let tools = result.tools {
            XCTAssertEqual(tools.count, 2)
        }
        
        if let builtinTools = result.builtinTools {
            XCTAssertEqual(builtinTools.count, 2)
        }
        
        if let webhooks = result.webhooks {
            XCTAssertEqual(webhooks.count, 1)
        }
    }
    
    func test_createConfig_errorHandling() async throws {
        // Create an invalid config (missing required fields)
        let invalidRequest = EviPostedConfig(
            eviVersion: "", // Empty eviVersion should cause an error
            name: "", // Empty name should cause an error
            versionDescription: nil,
            prompt: nil,
            voice: nil,
            languageModel: nil,
            ellmModel: nil,
            tools: nil,
            builtinTools: nil,
            eventMessages: nil,
            nudges: nil,
            timeouts: nil,
            webhooks: nil
        )
        
        // This should throw an error due to invalid fields
        do {
            let _ = try await client.empathicVoice.configs.createConfig(request: invalidRequest)
            XCTFail("Expected error for invalid request")
        } catch {
            // Expected to fail
            XCTAssertTrue(error is Error)
        }
    }
    
    func test_listConfigs_basicListing() async throws {
        // Test listing configs
        let result = try await client.empathicVoice.configs.listConfigs(
            page_number: 1,
            page_size: 10,
            restrict_to_most_recent: true,
            name: nil
        )
        
        // Verify the response structure
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.totalPages)
        XCTAssertNotNil(result.configsPage)
        
        // Verify pagination info
        XCTAssertGreaterThanOrEqual(result.totalPages, 0)
        XCTAssertNotNil(result.pageNumber)
        XCTAssertNotNil(result.pageSize)
    }
    
    func test_listConfigs_withNameFilter() async throws {
        // Test listing configs with a name filter
        let result = try await client.empathicVoice.configs.listConfigs(
            page_number: 1,
            page_size: 5,
            restrict_to_most_recent: false,
            name: "Test Config"
        )
        
        // Verify the response
        XCTAssertNotNil(result)
        XCTAssertNotNil(result.configsPage)
        
        // If there are results, verify they match the filter
        if let configs = result.configsPage, !configs.isEmpty {
            for config in configs {
                if let name = config.name {
                    XCTAssertTrue(name.contains("Test Config"))
                }
            }
        }
    }
}
