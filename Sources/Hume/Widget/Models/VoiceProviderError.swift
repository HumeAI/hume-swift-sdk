//
//  VoiceProviderError.swift
//  Hume
//
//  Created by Chris on 6/12/25.
//

import Foundation

/// Represents errors that can occur in the VoiceProvider lifecycle.
public enum VoiceProviderError: Error {
    /// The socket is not connected or was disconnected unexpectedly.
    case socketDisconnected
    /// Failed to initialize the microphone.
    case microphoneInitializationError(Error)
    /// Failed to send data over the socket.
    case socketSendError(Error)
    /// Received a WebSocket error.
    case websocketError(WebSocketError)
    /// Failed to start the audio hub.
    case audioHubStartFailure(Error)
    /// Failed to stop the audio hub.
    case audioHubStopFailure(Error)
    /// Failed to configure the audio hub.
    case audioHubConfigurationFailure(Error)
    /// AudioHub encountered an error
    case audioHubError(AudioHubError)
    /// Failed to connect the socket.
    case socketConnectionFailure(Error)
    /// Invalid session settings provided.
    case invalidSessionSettings
    /// An unknown error occurred.
    case unknown(Error)
}
