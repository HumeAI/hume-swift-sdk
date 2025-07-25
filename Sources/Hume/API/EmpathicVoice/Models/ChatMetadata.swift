//
//  ChatMetaData.swift
//
//
//  Created by Daniel Rees on 6/2/24.
//

import Foundation

public struct ChatMetadata: Codable {
    /** ID of the chat group. Used to resume a chat. */
    public let chatGroupId: String
    /** ID of the chat. */
    public let chatId: String
    public let customSessionId: String?
    public let type: String;

    public init(chatGroupId: String,
                chatId: String,
                customSessionId: String?,
                type: String) {
        self.chatGroupId = chatGroupId
        self.chatId = chatId
        self.customSessionId = customSessionId
        self.type = type
    }
}
