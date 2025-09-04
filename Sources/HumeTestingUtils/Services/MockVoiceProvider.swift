#if HUME_IOS
  //
  //  MockVoiceProvider.swift
  //  HumeAI2
  //
  //  Created by Chris on 2/26/25.
  //

  import Combine
  import Foundation
  import Hume

  public class MockVoiceProvider: VoiceProvidable {
    public var microphoneMode: MicrophoneMode = .init(
      preferredMode: .standard, activeMode: .standard)

    // MARK: - Properties
    private let stateSubject = CurrentValueSubject<VoiceProviderState, Never>(.disconnected)
    public var state: AnyPublisher<VoiceProviderState, Never> {
      stateSubject.eraseToAnyPublisher()
    }

    weak public var delegate: VoiceProviderDelegate?
    public var isOutputMeteringEnabled: Bool = false
    private var isConnected: Bool = false
    private var mockEventsTask: Task<Void, Never>?

    // Simulated behaviors
    var shouldFailConnection = false
    var simulatedError: Error = VoiceProviderError.microphoneInitializationError(
      NSError(domain: "MockError", code: 1))

    // MARK: - Initialization
    public init() {}

    // MARK: - Methods
    @MainActor
    public func connect(
      configId: String?, configVersion: String?, resumedChatGroupId: String?,
      sessionSettings: SessionSettings
    ) async throws {
      guard !shouldFailConnection else {
        throw VoiceProviderError.socketDisconnected
      }
      stateSubject.send(.connecting)
      try await Task.sleep(nanoseconds: 1_000_000_000)
      stateSubject.send(.connected)
      isConnected = true
      startSimulatingEvents()
    }

    @MainActor
    public func disconnect() {
      guard isConnected else { return }
      stateSubject.send(.disconnecting)
      isConnected = false
      mockEventsTask?.cancel()
      mockEventsTask = nil
      stateSubject.send(.disconnected)
      delegate?.voiceProviderDidDisconnect(self)
    }

    public func mute(_ mute: Bool) {

    }

    public func muteOutput(_ mute: Bool) async {
      // Mock implementation - no actual audio to mute
    }

    // MARK: - Event Simulation
    private func startSimulatingEvents() {
      mockEventsTask = Task.detached(priority: .userInitiated) {
        while self.isConnected {
          try? await Task.sleep(nanoseconds: 2_000_000_000)
          self.delegate?.voiceProvider(self, didProduceEvent: .userMessage(UserMessage.mock))
        }
      }
    }
  }

  extension UserMessage {
    fileprivate static var mock: UserMessage {
      let json = """
        {
          "custom_session_id": null,
          "from_text": false,
          "interim": false,
          "message": {
            "content": "Mock message",
            "role": "user"
          },
          "models": {
            "prosody": null
          },
          "time": {
            "begin": 0,
            "end": 0
          },
          "type": "mock"
        }
        """
      let data = json.data(using: .utf8)!
      return try! JSONDecoder().decode(UserMessage.self, from: data)
    }
  }
#endif
