#if HUME_IOS
  //
  //  AudioHub.swift
  //  Hume
  //
  //  Created by Chris on 8/7/25.
  //

  import AVFoundation

  public actor AudioHub {
    // MARK: - Properties
    // MARK: Audio Components
    private let audioSession = AudioSession.shared

    public var audioEngine: AVAudioEngine = AVAudioEngine()

    var inputNode: AVAudioInputNode { audioEngine.inputNode }
    var mainMixer: AVAudioMixerNode { audioEngine.mainMixerNode }
    var outputNode: AVAudioOutputNode { audioEngine.outputNode }

    // MARK: Output Nodes
    public var outputNodes: [(AVAudioNode, AVAudioFormat?)] = []

    // MARK: Microphone
    public private(set) var isRecording: Bool = false
    private var microphone: Microphone?
    private let microphoneQueue = DispatchQueue(label: "\(Constants.Namespace).microphone.queue")
    public var microphoneDataChunkHandler: MicrophoneDataChunkBlock?

    // MARK: State
    private var config: AudioHubConfiguration = .outputOnly
    private var isPrepared: Bool = false
    // MARK: - Initialization
    public static let shared = AudioHub()

    public func prepare() async {
      guard !isPrepared else {
        Logger.debug("AudioHub is already prepared")
        return
      }
      Logger.debug("Preparing audio hub")
      await audioSession.setDelegate(self)
      do {
        try await audioSession.configure(with: config)
        try await audioSession.start()
        isPrepared = true
      } catch {
        Logger.error("Failed to configure audio session with \(config): \(error)")
      }
    }

    // MARK: - Lifecycle

    public func addNode(_ node: AVAudioNode, format: AVAudioFormat?) throws {
      Logger.debug("Adding node: \(node)")
      guard !audioEngine.attachedNodes.contains(node) else {
        Logger.warn("Node already attached: \(node)")
        return
      }
      //    try audioSession.start()
      audioEngine.attach(node)
      audioEngine.connect(node, to: mainMixer, format: format)
      outputNodes.append((node, format))
      if !audioEngine.isRunning {
        Logger.debug("preparing audio engine")
        try audioEngine.prepare()
      }

      Logger.debug(audioEngine.description)
    }

    public func detachNode(_ node: AVAudioNode) {
      Logger.debug("Removing node: \(node)")
      var index: Int?
      for i in 0..<outputNodes.count {
        if outputNodes[i].0 == node {
          index = i
          break
        }
      }
      guard let index else {
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

      Logger.debug(audioEngine.description)
    }

    public func startEngineIfNeeded() throws {
      guard !audioEngine.isRunning else {
        return
      }

      Logger.debug("Starting audio engine")
      Logger.debug(
        "Session category: \(AVAudioSession.sharedInstance().category.rawValue ?? "unknown")")
      try audioEngine.start()

      Logger.debug(audioEngine.description)
    }

    public func stopEngine() {
      Logger.debug("Stopping audio engine")
      audioEngine.stop()
      Logger.debug(audioEngine.description)
    }
  }

  // MARK: - Microphone
  extension AudioHub {
    public nonisolated var microphoneMode: MicrophoneMode {
      return MicrophoneMode(
        preferredMode: AVCaptureDevice.preferredMicrophoneMode,
        activeMode: AVCaptureDevice.activeMicrophoneMode)
    }

    public func startMicrophone(handler: @escaping MicrophoneDataChunkBlock) async throws {
      Logger.info("Starting microphone")
      guard !isRecording else {
        Logger.warn("Microphone is already running")
        return
      }

      do {
        try await audioSession.configure(with: .inputOutput)
        try await audioSession.start()
      } catch {
        Logger.error("Failed to configure audio session for input/output: \(error)")
        throw AudioHubError.audioSessionConfigError
      }

      #if !targetEnvironment(simulator)
        // enable voice processing. this doesn't work on simulator
        Logger.debug("stopping audio engine")
        audioEngine.stop()
        do {
          try toggleVoiceProcessing(enabled: true, inputNode: inputNode, outputNode: outputNode)
        } catch {
          Logger.error("Failed to enable voice processing: \(error.localizedDescription)")
        }
      #endif

      do {
        self.microphone = try Microphone(
          audioEngine: audioEngine,
          sampleRate: Constants.SampleRate,
          sampleSize: Constants.SampleSize,
          audioFormat: Constants.DefaultAudioFormat)
      } catch {
        Logger.error("Failed to initialize microphone: \(error.localizedDescription)")
        throw AudioHubError.microphoneUnavailable
      }
      guard let microphone else {
        throw AudioHubError.microphoneUnavailable
      }

      microphoneDataChunkHandler = handler
      self.microphone?.onChunk = handleMicrophoneDataChunk

      let inputFormat = microphone.inputFormat
      audioEngine.attach(microphone.sinkNode)
      audioEngine.connect(inputNode, to: microphone.sinkNode, format: inputFormat)

      Logger.debug("starting audio engine")
      do {
        try audioEngine.start()
      } catch {
        throw AudioHubError.engineFailed
      }
      isRecording = true

      Logger.debug(audioEngine.description)
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
          inputNode.voiceProcessingOtherAudioDuckingConfiguration =
            AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
              enableAdvancedDucking: true, duckingLevel: .max)
        } else {
          inputNode.voiceProcessingOtherAudioDuckingConfiguration =
            AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
              enableAdvancedDucking: false, duckingLevel: .default)
        }
      }

      Logger.debug(audioEngine.description)
    }

    public func stopMicrophone() async {
      Logger.info("Stopping microphone")
      guard let microphone else {
        Logger.warn("No microphone to stop")
        return
      }
      audioEngine.stop()
      audioEngine.disconnectNodeOutput(inputNode)
      audioEngine.detach(microphone.sinkNode)
      isRecording = false
      //    audioEngine.reset()

      do {

        try toggleVoiceProcessing(enabled: false, inputNode: inputNode, outputNode: outputNode)

        try await audioSession.stop()
        //          Thread.sleep(forTimeInterval: 1) // Allow session to reset
        try await audioSession.configure(with: .outputOnly)

        try await audioSession.start()

        let newEngine = AVAudioEngine()
        for (node, fmt) in outputNodes {
          audioEngine.detach(node)
        }

        for (node, fmt) in outputNodes {
          newEngine.attach(node)
          newEngine.connect(node, to: newEngine.mainMixerNode, format: fmt)
        }

        self.audioEngine = newEngine
        try audioEngine.prepare()
        //          try audioEngine.start()
      } catch {
        Logger.error("Failed to reset audio session: \(error)")
      }

      microphoneDataChunkHandler = nil
      self.microphone = nil

      Logger.debug(audioEngine.description)
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
#endif
