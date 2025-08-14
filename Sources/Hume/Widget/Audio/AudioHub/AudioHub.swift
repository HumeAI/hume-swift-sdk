//
//  AudioHub.swift
//  Hume
//
//  Created by Chris on 8/7/25.
//

import AVFoundation

public enum AudioHubError: Error {
  case audioSessionConfigError
  case soundPlayerDecodingError
  case soundPlayerInitializationError
  case headerMissing
  case notRunning
  case outputFormatError
  case microphoneUnavailable
}

public actor AudioHub {
  // MARK: - Properties
  // MARK: Audio Components
  private let audioSession = AudioSession.shared

  public var audioEngine: AVAudioEngine = AVAudioEngine()

  var inputNode: AVAudioInputNode { audioEngine.inputNode }
  var mainMixer: AVAudioMixerNode { audioEngine.mainMixerNode }
  var outputNode: AVAudioOutputNode { audioEngine.outputNode }

  // TODO: implement pause state management during interruption
  var pauseState: PauseState? = nil

  // MARK: Output Nodes
  public var outputNodes: [AVAudioNode] = []

  // MARK: Microphone
  private var microphone: Microphone?
  private let microphoneQueue = DispatchQueue(label: "\(Constants.Namespace).microphone.queue")
  public var microphoneDataChunkHandler: MicrophoneDataChunkBlock?

  // MARK: State
  var config: AudioHubConfiguration
  // MARK: - Initialization
  public static let shared = AudioHub()

  private init() {
    config = .outputOnly
    do {
      try audioSession.configure(with: config)
    } catch {
      Logger.error("Failed to configure audio session with \(config): \(error)")

    }
    audioSession.delegate = self
  }

  // MARK: - Lifecycle

  public func addNode(_ node: AVAudioNode, format: AVAudioFormat?) throws {
    Logger.debug("Adding node: \(node)")
    try audioSession.start()
    audioEngine.attach(node)
    audioEngine.connect(node, to: mainMixer, format: format)
    outputNodes.append(node)
    if !audioEngine.isRunning {
      Logger.debug("starting audio engine")
      try audioEngine.start()
    }
  }

  public func detachNode(_ node: AVAudioNode) {
    Logger.debug("Removing node: \(node)")
    guard let index = outputNodes.firstIndex(of: node) else {
      Logger.warn("Node not found in additional output nodes: \(node)")
      return
    }
    outputNodes.remove(at: index)
    guard audioEngine.attachedNodes.contains(node) else {
      Logger.warn("audio engine does not contain node: \(node)")
      return
    }

    Logger.debug("detaching node: \(node)")
    audioEngine.detach(node)
  }

  public func ensureRunning() throws {
    if !audioEngine.isRunning {
      try audioEngine.start()
    }
  }
}

// MARK: - Microphone
extension AudioHub {
  public nonisolated var microphoneMode: MicrophoneMode {
    return MicrophoneMode(
      preferredMode: AVCaptureDevice.preferredMicrophoneMode,
      activeMode: AVCaptureDevice.activeMicrophoneMode)
  }

  public func startMicrophone(handler: @escaping MicrophoneDataChunkBlock) throws {
    Logger.info("Starting microphone")
    try audioSession.configure(with: .inputOutput)
    try audioSession.start()

    #if !targetEnvironment(simulator)
      // enable voice processing. this doesn't work on simulator
      Logger.debug("stopping audio engine")
      audioEngine.stop()
      try toggleVoiceProcessing(enabled: true, inputNode: inputNode, outputNode: outputNode)
    #endif

    self.microphone = try Microphone(
      audioEngine: audioEngine,
      sampleRate: Constants.SampleRate,
      sampleSize: Constants.SampleSize,
      audioFormat: Constants.DefaultAudioFormat)

    guard let microphone else {
      throw AudioHubError.microphoneUnavailable
    }

    microphoneDataChunkHandler = handler
    self.microphone?.onChunk = handleMicrophoneDataChunk

    let inputFormat = inputNode.outputFormat(forBus: 0)
    audioEngine.attach(microphone.sinkNode)
    audioEngine.connect(inputNode, to: microphone.sinkNode, format: inputFormat)

    Logger.debug("starting audio engine")
    try audioEngine.start()
  }

  private func toggleVoiceProcessing(
    enabled: Bool, inputNode: AVAudioInputNode, outputNode: AVAudioOutputNode
  )
    throws
  {
    do {
      try inputNode.setVoiceProcessingEnabled(enabled)
      Logger.info("Voice Processing \(enabled) on input node")
      try outputNode.setVoiceProcessingEnabled(enabled)
      Logger.info("Voice Processing \(enabled) on output node")
    } catch {
      Logger.error(
        "Failed to enable voice processing on node: \(error.localizedDescription)")
      throw MicrophoneError.configuration(error)
    }

    if #available(iOS 17.0, *) {
      if enabled {
        let duckingConfig = AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
          enableAdvancedDucking: false, duckingLevel: .max)
        inputNode.voiceProcessingOtherAudioDuckingConfiguration = duckingConfig
      }
    }
  }

  public func stopMicrophone() {
    Logger.info("Stopping microphone")
    guard let microphone else {
      Logger.warn("No microphone to stop")
      return
    }
    audioEngine.detach(microphone.sinkNode)
    Logger.debug("stopping audio engine")
    audioEngine.stop()
    try? toggleVoiceProcessing(enabled: false, inputNode: inputNode, outputNode: outputNode)

    try? audioSession.configure(with: .outputOnly)

    microphoneDataChunkHandler = nil
    self.microphone = nil
  }

  public func muteMic(_ mute: Bool) {
    if mute {
      microphone?.mute()
    } else {
      microphone?.unmute()
    }
  }

  private func handleMicrophoneDataChunk(data: Data, averagePower: Float) {
    self.microphoneQueue.async { [weak self] in
      Task {
        // TODO: make averagePower configurable, currently omitting this data
        guard let self else {
          assertionFailure("lost AudioHub self")
          return
        }
        guard let handler = await self.microphoneDataChunkHandler else {
          Logger.warn("no mic data chunk handler set ")
          return
        }
        await handler(data, averagePower)
      }
    }
  }
}

// MARK: - AudioSession Delegate
extension AudioHub: AudioSessionDelegate {
  nonisolated func audioSessionRouteDidChange(reason: AVAudioSession.RouteChangeReason) {
    Logger.debug("Audio session route changed: \(reason.rawValue)")
    Task {
      Logger.debug("starting audio engine")
      try await audioEngine.start()
    }
  }

  nonisolated func audioSessionInterruptionDidBegin() {
    // TODO: pause session
  }

  nonisolated func audioSessionInterruptionDidEnd(shouldResume: Bool) {
    // TODO: restore state of session if needed
  }

  nonisolated func audioEngineDidChangeConfiguration() {

  }
}

// MARK: - AudioHub Types
extension AudioHub {

  struct PauseState {
    let wasMuted: Bool
  }

  enum State: Hashable {
    case unconfigured
    case configuring(AudioHubConfiguration)
    case running(AudioHubConfiguration)

    var activeConfig: AudioHubConfiguration? {
      switch self {
      case .configuring(let config): return config
      case .running(let config): return config
      case .unconfigured: return nil
      }
    }

    var isRunning: Bool {
      switch self {
      case .running: return true
      default: return false
      }
    }
  }
}
