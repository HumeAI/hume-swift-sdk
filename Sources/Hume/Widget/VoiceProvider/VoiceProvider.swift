#if HUME_WIDGET
  import AVFoundation
  import Combine
  import Foundation

  public class VoiceProvider: VoiceProvidable {
    public var state: AnyPublisher<VoiceProviderState, Never> {
      stateSubject.eraseToAnyPublisher()
    }
    private let stateSubject = CurrentValueSubject<VoiceProviderState, Never>(.disconnected)

    private let humeClient: HumeClient
    private var socket: StreamSocket?
    private let delegateQueue = DispatchQueue(
      label: "\(Constants.Namespace).delegate.queue", qos: .userInteractive)
    private var eventSubscription: Task<(), any Error>?

    private var audioHub: AudioHub = AudioHub.shared
    private var _soundPlayer: SoundPlayer?

    private var connectionContinuation: CheckedContinuation<(), any Error>?

    public weak var delegate: (any VoiceProviderDelegate)?

    // MARK: - Metering
    public var isOutputMeteringEnabled: Bool = false {
      didSet {
        Task {
          await _soundPlayer?.toggleMetering(enabled: isOutputMeteringEnabled)
        }
      }
    }

    // MARK: - Microphone

    public var microphoneMode: MicrophoneMode {
      return audioHub.microphoneMode
    }

    // MARK: Init/deinit

    public init(client: HumeClient) {
      self.humeClient = client
    }

    deinit {
      eventSubscription?.cancel()
    }

    // MARK: - Connection

    /// Starts a connection with EVI.
    /// - Parameters:
    ///   - with: The connection options for the chat.
    ///   - sessionSettings: Defines the session settings for the connection. Setting the `audio` configuration to `nil` will enable `VoiceProvider` to configure this automatically.
    public func connect(
      with options: ChatConnectOptions?,
      sessionSettings: SessionSettings
    ) async throws {
      Logger.info(
        "Connecting voice provider. options: \(String(describing: options))"
      )
      if stateSubject.value == .disconnecting {
        // need to wait to finish disconnecting
        Logger.debug("was in the middle of disconnecting, waiting to finish...")
        try await stateSubject.waitFor(.disconnected)
        Logger.debug("...disconnected")
      }
      stateSubject.send(.connecting)

      var defaultedSessionSettings: SessionSettings? = nil
      if sessionSettings.audio == nil {
        defaultedSessionSettings = sessionSettings.copy(
          audio: AudioConfiguration(
            channels: 1,
            encoding: .linear16,
            sampleRate: Int(Constants.SampleRate))
        )
      }

      try await withCheckedThrowingContinuation { [defaultedSessionSettings] continuation in
        // open socket
        Task {
          self.socket = try? await self.humeClient.empathicVoice.chat
            .connect(
              with: options,
              onOpen: { [weak self] response in
                Logger.info("Socket Opened")
                guard let self = self else { return }
                Task {
                  do {
                    Logger.info("Voice provider listening for events")
                    self.startListeningForEvents()
                    try await self.sendSessionSettings(
                      message: defaultedSessionSettings ?? sessionSettings)

                    Logger.info("Waiting to receive chat metadata to finalize AudioHub")
                    self.connectionContinuation = continuation
                  } catch {
                    self.stateSubject.send(.disconnected)
                    continuation.resume(throwing: error)
                  }
                }
              },
              onClose: { [weak self] closeCode, reason in
                Logger.warn("Socket Closed: \(closeCode). Reason: \(String(describing: reason))")
                if self?.stateSubject.value == .connected || self?.stateSubject.value == .connecting
                {
                  Task { await self?.disconnect() }
                }
              },
              onError: { [weak self] error, response in
                Logger.error("Socket Errored: \(error). Response: \(String(describing: response))")
                if let httpResponse = response as? HTTPURLResponse {
                  if httpResponse.statusCode == 401 {
                    guard let self else {
                      Logger.error("lost self")
                      return
                    }
                    self.delegate?.voiceProvider(self, didProduceError: .unauthorized)
                  }
                }

                if self?.stateSubject.value == .connecting {
                  Logger.warn("aborting connection attempt due to error")
                  Task { await self?.disconnect() }
                }
              }
            )
        }
      }
    }

    /// Starts a connection with EVI.
    /// - Parameters:
    ///   - configId: The unique identifier for an EVI configuration.
    ///   - configVersion: Include this parameter to apply a specific version of an EVI configuration. If omitted, the latest version will be applied.
    ///   - resumedChatGroupId: The unique identifier for a Chat Group. Use this field to preserve context from a previous Chat session.
    ///   - sessionSettings: Defines the session settings for the connection. Setting the `audio` configuration to `nil` will enable `VoiceProvider` to configure this automatically.
    @available(*, deprecated, message: "Use connect(options:sessionSettings:) instead")
    public func connect(
      configId: String?, configVersion: String?, resumedChatGroupId: String?,
      sessionSettings: SessionSettings
    ) async throws {
      let options = ChatConnectOptions(
        configId: configId,
        configVersion: configVersion,
        resumedChatGroupId: resumedChatGroupId
      )
      try await connect(with: options, sessionSettings: sessionSettings)
    }

    private func completeConnectionSetup() {
      guard let connectionContinuation else {
        Logger.error("missing connection continuation")
        Task { await self.disconnect() }
        return
      }

      Logger.info("Finalizing audio hub configuration")

      Task {
        do {
          try await self.audioHub.startMicrophone(handler: handleMicrophoneData)
        } catch {
          Logger.error("failed to start microphone", error)
          connectionContinuation.resume(throwing: error)
          self.connectionContinuation = nil
          return
        }
        self.stateSubject.send(.connected)
        self.delegate?.voiceProviderDidConnect(self)

        Logger.info("Voice Provider connected successfully")
        connectionContinuation.resume()
        self.connectionContinuation = nil
      }

    }

    public func disconnect() async {
      Logger.info("attempting to disconnect voice provider")
      guard [.connected, .connecting].contains(stateSubject.value) else {
        Logger.info("not connected")
        return
      }
      await MainActor.run { stateSubject.send(.disconnecting) }
      self.delegate?.voiceProviderWillDisconnect(self)
      Logger.info("Disconnecting voice provider")

      await self.audioHub.stopMicrophone()
      await _soundPlayer?.clearQueue()
      self.eventSubscription?.cancel()
      self.socket?.close()
      Logger.info("Voice provider disconnected")
      self.delegate?.voiceProviderDidDisconnect(self)
      stateSubject.send(.disconnected)
    }

    // MARK: - Controls
    public func mute(_ mute: Bool) {
      Task { await audioHub.muteMic(mute) }
    }

    public func sendUserInput(message: String) async throws {
      try await socket?.sendTextInput(text: message)
    }

    public func sendAssistantInput(message: String) async throws {
      try await socket?.sendAssistantInput(message: AssistantInput(text: message))
    }

    public func sendSessionSettings(message: SessionSettings) async throws {
      try await socket?.sendSessionSettings(message: message)
    }

    public func sendPauseAssistantMessage(message: PauseAssistantMessage) async throws {
      try await socket?.pauseAssistant(message: message)

    }

    public func sendResumeAssistantMessage(message: ResumeAssistantMessage) async throws {
      try await socket?.resumeAssistant(message: message)
    }
  }

  // MARK: - Event Handling
  extension VoiceProvider {
    // MARK: Event handling
    private func startListeningForEvents() {
      Logger.info("Starting to listen for events")

      // Wrap listening logic in an async block for better control
      eventSubscription = Task.detached(priority: .high) {
        try await withThrowingTaskGroup(of: Void.self) { group in
          guard let socket = self.socket else {
            throw VoiceProviderError.socketDisconnected
          }

          group.addTask { [weak self] in
            guard let self else {
              Logger.warn("lost self")
              return
            }

            do {
              Logger.info("Waiting for events on socket")
              for try await event in socket.receive() {
                try self.handleIncomingEvent(event)
              }
            } catch let error as StreamSocketError {
              switch error {
              case .connectionError, .transportError:
                Logger.error("Error receiving messages: \(error). Disconnecting...")
                Task { await self.disconnect() }
              case .closed, .disconnected:
                Logger.debug("Event subscription received \(error.rawValue) code.")
              case .encodingError, .decodingError:
                Logger.warn("Event subscription received \(error.rawValue) code")
              }
            } catch {
              Logger.error("Unknown error receiving messages: \(error). Disconnecting...")
              Task { await self.disconnect() }
            }
          }
        }
      }
    }

    /// Handles incoming audio output events by decoding and playing the audio clip.
    private func handleAudioOutput(_ audioOutput: AudioOutput) {
      guard let clip = SoundClip.from(audioOutput) else {
        Logger.error("Failed to decode audio output")
        return
      }

      guard let header = clip.header,
        let format = header.asAVAudioFormat
      else {
        Logger.error("Audio clip missing header")
        return
      }

      Task {
        do {
          let soundPlayer = try await getSoundPlayer(format: format)
          try await soundPlayer.enqueueAudio(soundClip: clip)
          self.delegate?.voiceProvider(self, didPlayClip: clip)
        } catch let error as AudioHubError {
          Logger.warn("Failed to enqueue audio output: \(error)")
          self.delegate?.voiceProvider(self, didProduceError: .audioHubError(error))
        } catch {
          Logger.error("Unknown error while trying to enqueue audio output: \(error)")
          self.delegate?.voiceProvider(self, didProduceError: .unknown(error))
        }
      }
    }

    /// Gets an existing SoundPlayer with the specified format or creates a new one if necessary.
    private func getSoundPlayer(format: AVAudioFormat) async throws -> SoundPlayer {
      if let _soundPlayer, await _soundPlayer.format == format {
        return _soundPlayer
      } else if let _soundPlayer, await _soundPlayer.format != format {
        Logger.debug("SoundPlayer format mismatch, detaching old node")
        try await audioHub.detachNode(_soundPlayer.audioSourceNode)
      }
      Logger.debug("Creating new SoundPlayer with format \(format.prettyPrinted)")
      _soundPlayer = SoundPlayer(format: format)
      await _soundPlayer!.startMetering(callback: self.handleOutputMeter)
      await _soundPlayer!.toggleMetering(enabled: self.isOutputMeteringEnabled)
      try await audioHub.addNode(_soundPlayer!.audioSourceNode, format: format)
      return _soundPlayer!
    }

    /// Handles individual incoming events
    private func handleIncomingEvent(_ event: SubscribeEvent) throws {
      switch event {
      case .audioOutput(let audioOutput):
        handleAudioOutput(audioOutput)
      case .userInterruption:
        Task { await self._soundPlayer?.clearQueue() }
      case .chatMetadata(let response):
        Logger.debug(
          """
          --Received metadata response--
          Chat ID: \(response.chatId)
          Chat Group ID: \(response.chatGroupId)
          """
        )
        Task {
          completeConnectionSetup()
        }
      case .webSocketError(let error):
        if error.slug == "inactivity_timeout" {
          Logger.warn("WebSocket error: \(error)")
        } else {
          Logger.error("WebSocket error: \(error)")
        }

        delegate?.voiceProvider(self, didProduceError: VoiceProviderError.websocketError(error))
        Task {
          await self.disconnect()
        }
      default: break
      }
      self.delegate?.voiceProvider(self, didProduceEvent: event)
    }

    // MARK: Handlers
    private func handleOutputMeter(_ meter: Float) {
      self.delegateQueue.async {
        self.delegate?.voiceProvider(self, didReceieveAudioOutputMeter: meter)
      }
    }

    private func handleMicrophoneData(_ data: Data, averagePower: Float) async {
      guard stateSubject.value == .connected else {
        Logger.warn("handleMicData called without being connected")
        return
      }
      do {
        self.delegate?.voiceProvider(self, didReceieveAudioInputMeter: averagePower)
        try await self.socket?.sendData(message: data)
      } catch let error as StreamSocketError {
        // disconnect VoiceProvider if needed
        switch error {
        case .closed, .disconnected:
          Logger.warn("received closed or disconnected error while sending mic data, cleaning up")
          // if the socket is closed or disconnected while we're attempting to send mic data, it means AudioHub didn't
          await self.audioHub.stopMicrophone()
        case .connectionError, .transportError, .encodingError, .decodingError:
          Logger.error("error sending mic data: \(error.rawValue), disconnecting...")
          self.delegate?.voiceProvider(
            self, didProduceError: VoiceProviderError.socketSendError(error))
          await self.disconnect()
        }
      } catch {
        Logger.error("error sending mic data: \(error)")
        self.delegate?.voiceProvider(
          self, didProduceError: VoiceProviderError.socketSendError(error))
      }
    }
  }
#endif
