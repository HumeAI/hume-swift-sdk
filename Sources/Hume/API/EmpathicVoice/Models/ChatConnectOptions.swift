
import Foundation

public struct ChatConnectOptions: Codable {
    public var configId: String?
    public var configVersion: String?
    public var resumedChatGroupId: String?
    public var voiceId: String?
    public var verboseTranscription: Bool?
    public var eventLimit: Int?

    public init(
        configId: String? = nil,
        configVersion: String? = nil,
        resumedChatGroupId: String? = nil,
        voiceId: String? = nil,
        verboseTranscription: Bool? = nil,
        eventLimit: Int? = nil
    ) {
        self.configId = configId
        self.configVersion = configVersion
        self.resumedChatGroupId = resumedChatGroupId
        self.voiceId = voiceId
        self.verboseTranscription = verboseTranscription
        self.eventLimit = eventLimit
    }
}
