#if HUME_IOS
  //
  //  VoiceProvidable.swift
  //  Hume
  //
  //  Created by Chris on 6/12/25.
  //

  import Combine
  import Foundation

  public protocol VoiceProvidable {
    var state: AnyPublisher<VoiceProviderState, Never> { get }
    var delegate: VoiceProviderDelegate? { get set }
    var isOutputMeteringEnabled: Bool { get set }
    var isInputMeteringEnabled: Bool { get set }
    var microphoneMode: MicrophoneMode { get }

    /// Connects the VoiceProvider to the backend and prepares audio streaming.
    /// - Throws: `VoiceProviderError` for connection, configuration, or audio errors.
    @MainActor func connect(
      with options: ChatConnectOptions?,
      sessionSettings: SessionSettings
    ) async throws
    /// Connects the VoiceProvider to the backend and prepares audio streaming.
    /// - Throws: `VoiceProviderError` for connection, configuration, or audio errors.
    @MainActor func connect(
      configId: String?, configVersion: String?, resumedChatGroupId: String?,
      sessionSettings: SessionSettings) async throws
    /// Disconnects the VoiceProvider and stops audio streaming.
    @MainActor func disconnect() async

    /// Mutes or unmutes the microphone.
    /// - Parameter mute: Pass `true` to mute, `false` to unmute.
    func mute(_ mute: Bool)

    /// Mutes or unmutes the output audio (sound player).
    /// - Parameter mute: Pass `true` to mute, `false` to unmute.
    func muteOutput(_ mute: Bool) async
  }
#endif
