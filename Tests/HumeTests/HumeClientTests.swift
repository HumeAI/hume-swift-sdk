import XCTest
@testable import Hume

final class HumeClientTests: XCTestCase {
    
    var client: HumeClient!
    
    override func setUp() {
        self.client = HumeClient(apiKey: Env.apiKey, clientSecret: Env.clientSecret)
    }
    
    func test_list_configs() async throws {
        
        print("🧪 GET - List Configs")
        
        let pageNumber = 0
        
        let response = try await self.client.empatheticVoice.configs.listConfigs(pageNumber: pageNumber)
        
        print(response.toJSON())
        
        XCTAssertEqual(response.pageNumber, pageNumber)
        XCTAssertEqual(response.pageSize, 10) // 10 is Default
        
    }
    
    func test_create_config() async throws {
        
        print("🧪 POST - Create Config")
        
        let randomConfigName = UUID().uuidString
        
        let response = try await self.client.empatheticVoice.configs.createConfig(name: randomConfigName)
        
        print(response.toJSON())
        
        XCTAssertEqual(randomConfigName, response.name)
        
    }
    
    func test_list_config_versions() async throws {
        
        print("🧪 GET - List Config Versions")
        
        let id = "245bcc49-21b0-4bcf-a831-aa9b145eafcb"
        let pageNumber = 0
        
        let response = try await self.client.empatheticVoice.configs.listConfigVersions(id: id, pageNumber: pageNumber)
        
        print(response.toJSON())
        
        XCTAssertEqual(response.pageNumber, pageNumber)
        XCTAssertEqual(response.pageSize, 10) // 10 is Default
        
    }
    
    func test_create_config_version() async throws {
        
        print("🧪 POST - Create Config Version")
        
        let id = "de3c3c79-512f-43be-bf35-937f4c95b13a"
        let description = "This is an awesome config version description"
        
        let response = try await self.client.empatheticVoice.configs.createConfigVersion(id: id, versionDescription: description)
        
        print(response.toJSON())
        
        XCTAssertEqual(response.id, id)
        XCTAssertEqual(response.versionDescription, description)
        
    }
    
    func test_delete_config() async throws {
        
        print("🧪 DELETE - Delete Config")
        
        let id = "f370db71-a0df-4f87-aa2b-4eebfba999e1"
        
        try await self.client.empatheticVoice.configs.deleteConfig(id: id)
        
    }
    
    func test_update_config_name() async throws {
        
        print("🧪 PATCH - Update Config Name")
        
        let id = "d467869c-8590-4c15-acda-097412224585"
        let name = "New Name"
        
        try await self.client.empatheticVoice.configs.updateConfigName(id: id, name: name)
        
    }
    
    func test_get_config_version() async throws {
        
        print("🧪 GET - Get Config Version")
        
        let id = "245bcc49-21b0-4bcf-a831-aa9b145eafcb"
        let version = 2
        
        let response = try await self.client.empatheticVoice.configs.getConfigVersion(id: id, version: version)
        
        print(response.toJSON())
        
        XCTAssertEqual(response.id, id)
        XCTAssertEqual(response.version, version)
        
    }
    
    func test_delete_config_version() async throws {
        
        print("🧪 DELETE - Delete Config Version")
        
        let id = "327a3e29-2658-4c7a-8b0b-0bbcf7562180"
        let version = 0
        
        try await self.client.empatheticVoice.configs.deleteConfigVersion(id: id, version: version)
        
    }
    
    func test_update_config_description() async throws {
        
        print("🧪 PATH - Update Config Description")
        
        let id = "398561fc-c849-4d4a-a2e1-f70fd5d2884d"
        let version = 0
        let description = "This is a version description"
        
        let response = try await self.client.empatheticVoice.configs.updateConfigDescription(id: id, version: version, versionDescription: description)
        
        print(response.toJSON())
        
        XCTAssertEqual(response.id, id)
        XCTAssertEqual(response.version, version)
        XCTAssertEqual(response.versionDescription, description)
        
    }
    
    func test_sequence() async throws {
        
        // Create a config
        let name = "New_Config_\(UUID().uuidString)"
        
        let createConfigRes = try await self.client.empatheticVoice.configs.createConfig(
            name: name,
            versionDescription: "This is a description",
//                prompt: PostedPromptSpec(
//                    id: UUID().uuidString,
//                    version: 1
//                ),
            voice: PostedVoice(
                name: .dacher
            ),
            languageModel: PostedLanguageModel(
                modelProvider: .groq,
                modelResource: "some_resource",
                temperature: 99.9
            )
//                tools: [
//                    PostedUserDefinedToolSpec(
//                        id: UUID().uuidString,
//                        version: 1
//                    )
//                ],
//                builtinTools: [
//                    PostedBuiltinTool(
//                        name: "some_builtin_tool",
//                        fallbackContent: "some_fallback_content"
//                    )
//                ]
        )
        
        print(createConfigRes)
        XCTAssertEqual(createConfigRes.name, name)
        XCTAssertNotNil(createConfigRes.id)
        
        // Delete the config
        try await self.client.empatheticVoice.configs.deleteConfig(id: createConfigRes.id!)
        
        // Create another config
        let createConfigRes2 = try await self.client.empatheticVoice.configs.createConfig(name: name)
        print(createConfigRes2)
        XCTAssertEqual(createConfigRes2.name, name)
        XCTAssertNotNil(createConfigRes2.id)
        
        // List Configs
        let listConfigsRes = try await self.client.empatheticVoice.configs.listConfigs()
        print(listConfigsRes)
        let ids = (listConfigsRes.configsPage ?? []).map { $0.id }
        XCTAssertTrue(ids.contains(createConfigRes2.id))
        
        let configId = createConfigRes2.id!
        
        // Create Config Version
        let description = "This is an awesome config version description"
        let createConfigVersionRes = try await self.client.empatheticVoice.configs.createConfigVersion(id: configId, versionDescription: description)
        XCTAssertEqual(createConfigVersionRes.id, configId)
        XCTAssertNotNil(createConfigVersionRes.version)
        
        let configVersionId = createConfigVersionRes.version!
        
        // List Config Version
        let listConfigVersionsRes = try await self.client.empatheticVoice.configs.listConfigVersions(id: configId)
        let configVersionIds = (listConfigVersionsRes.configsPage ?? []).map { $0.id }
        XCTAssertTrue(configVersionIds.contains(configId))
        
        // Update Config Name
        let updatedName = "Updated_Config_\(UUID().uuidString)"
        try await self.client.empatheticVoice.configs.updateConfigName(id: configId, name: updatedName)
        
        // Get Config Name
        let getConfigVersionRes = try await self.client.empatheticVoice.configs.getConfigVersion(id: configId, version: configVersionId)
        XCTAssertEqual(getConfigVersionRes.id, configId)
        
        // Update Config Description
        let updatedDescription = "Updated_Config_Description_\(UUID().uuidString)"
        let updatedDescriptionRes = try await self.client.empatheticVoice.configs.updateConfigDescription(id: configId, version: configVersionId, versionDescription: updatedDescription)
        XCTAssertEqual(updatedDescriptionRes.versionDescription, updatedDescription)
        
        // Delete Config Version
        try await self.client.empatheticVoice.configs.deleteConfigVersion(id: configId, version: configVersionId)
        
    }
    
}
