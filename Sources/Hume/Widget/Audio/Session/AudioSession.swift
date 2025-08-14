import AVFAudio
import Combine
import Foundation

protocol AudioSessionDelegate: AnyObject {
  func audioEngineDidChangeConfiguration()
  func audioSessionRouteDidChange(reason: AVAudioSession.RouteChangeReason)
  func audioSessionInterruptionDidBegin()
  func audioSessionInterruptionDidEnd(shouldResume: Bool)
}

class AudioSession {
  private let audioSession = AVAudioSession.sharedInstance()
  internal var lastInputPort: AVAudioSessionPortDescription?

  static let shared = AudioSession()

  private var activeConfig: AudioHubConfiguration? = nil
  private var isActive: Bool = false

  @Published var isDeviceSpeakerActive: Bool = false
  weak var delegate: (any AudioSessionDelegate)? = nil

  init() {
    registerAVObservers()
  }

  func start() throws {
    Logger.info("Starting audio session")
    guard activeConfig != nil else {
      throw AudioSessionError.unconfigured
    }
    guard !isActive else {
      Logger.warn("Audio session is already active.")
      return
    }
    try audioSession.setActive(true)
    isActive = true
    try handleAudioRouting()
  }

  func stop() throws {
    Logger.info("Stopping audio session")
    try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    isActive = false
  }

  // MARK: Configuring
  func configure(with configuration: AudioHubConfiguration) throws {
    Logger.info("Configuring audio session with \(configuration)")
    guard activeConfig != configuration else {
      Logger.warn("Audio session already configured for \(configuration).")
      return
    }
    activeConfig = configuration

    do {
      switch configuration {
      case .inputOutput:
        try audioSession.setPreferredIOBufferDuration(Constants.InputBufferDuration)  //20 ms as per EVI docs
        try audioSession.setPreferredSampleRate(Constants.SampleRate)
      case .outputOnly:
        break
      }

      try update(with: configuration)
      Logger.info("Audio session configured successfully")
    } catch let error as AudioSessionError {
      throw error
    } catch {
      Logger.error("Failed to configure audio session", error)
      throw AudioSessionError.unsupportedConfiguration(reason: "Failed to configure audio session")
    }
  }

  private func update(with config: AudioHubConfiguration) throws {
    let (category, mode, options) = (config.category, config.mode, config.options)
    guard AVAudioSession.sharedInstance().availableCategories.contains(category) else {
      throw AudioSessionError.unsupportedConfiguration(reason: "\(category) is not supported.")
    }
    Logger.debug(
      "Updating audio session to category: \(category), mode: \(mode), options: \(options)")
    try audioSession.setCategory(category, mode: mode, options: options)
  }

  private func registerAVObservers() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleConfigurationChange),
      name: .AVAudioEngineConfigurationChange,
      object: nil)
  }

  // MARK: - Audio Routing
  private func overrideReceiverIfNeeded(ioConfig: AudioSessionIO) throws {
    let defaultToSpeaker = activeConfig?.options.contains(.defaultToSpeaker) ?? false
    if (ioConfig.output.portType == .builtInReceiver || ioConfig.output.portType == .builtInSpeaker)
      && defaultToSpeaker
    {
      Logger.info("Overriding to speaker output")
      try audioSession.overrideOutputAudioPort(.speaker)
      self.isDeviceSpeakerActive = true
    } else {
      Logger.info("Setting output override to none")
      try audioSession.overrideOutputAudioPort(.none)
      isDeviceSpeakerActive = false
    }
  }

  private func handleAudioRouting() throws {
    let ioConfig = try getBestFitAudioPorts()

    // Handle speaker override
    Logger.info("Handling audio routing change")
    Logger.info("Output name: \(ioConfig.output.portName)")
    Logger.info("Input name: \(ioConfig.input.portName)")

    if let lastInputPort, lastInputPort.portName != ioConfig.input.portName {
      Logger.debug("input did change from \(lastInputPort.portName) to \(ioConfig.input.portName)")

      // Set preferred input
      Logger.debug("setting preferred input route to \(ioConfig.input.portName)")
      try audioSession.setPreferredInput(ioConfig.input)
    }
    self.lastInputPort = ioConfig.input

    try overrideReceiverIfNeeded(ioConfig: ioConfig)
  }

  private func getBestFitAudioPorts() throws -> AudioSessionIO {
    let (inputPort, outputPort): (AVAudioSessionPortDescription, AVAudioSessionPortDescription)

    // Get the current outputs and available inputs
    let outputs = audioSession.currentRoute.outputs
    guard let inputs = audioSession.availableInputs, !inputs.isEmpty else {
      throw AudioSessionError.noAvailableDevices
    }

    // Validate the outputs for correct configuration
    guard let output = outputs.first, outputs.count == 1 else {
      throw AudioSessionError.multipleOutputRoutes
    }
    outputPort = output

    // Check for a matching I/O port type, otherwise check for a non-built-in input
    if let matchingPort = inputs.first(where: { $0.portType == output.portType }) {
      inputPort = matchingPort
    } else if let externalInput = inputs.first(where: { $0.portType != .builtInMic }) {
      inputPort = externalInput
    } else {
      inputPort = inputs.first!  // already checked that non-empty
    }

    return AudioSessionIO(input: inputPort, output: outputPort)
  }
}

// MARK: - Notification Handlers

extension AudioSession {
  @objc private func handleConfigurationChange() {
    self.delegate?.audioEngineDidChangeConfiguration()
  }

  @objc
  private func handleInterruption(_ notification: Notification) {
    Logger.debug("Interruption notification received")
    guard let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }
    switch type {
    case .began:
      self.delegate?.audioSessionInterruptionDidBegin()
    case .ended:
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
        return
      }
      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume) {
        self.delegate?.audioSessionInterruptionDidEnd(shouldResume: true)
      } else {
        self.delegate?.audioSessionInterruptionDidEnd(shouldResume: false)
      }
    @unknown default:
      Logger.warn("Unhandled interruption type: \(type)")
    }
  }

  @objc
  private func handleRouteChange(_ notification: Notification) {
    guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason)
    else {
      Logger.warn("Route change reason is missing")
      return
    }

    Logger.info("Route change notification received: \(reason)")

    switch reason {
    case .newDeviceAvailable, .oldDeviceUnavailable, .unknown, .wakeFromSleep,
      .routeConfigurationChange:
      Task {
        do {
          try handleAudioRouting()
          delegate?.audioSessionRouteDidChange(reason: reason)
        } catch {
          Logger.error("Route change error: \(error.localizedDescription)")
        }
      }
    case .noSuitableRouteForCategory, .override, .categoryChange:
      Logger.info("Skipping route change reason: \(reason)")
    @unknown default:
      Logger.warn("Unhandled route change type: \(reason)")
    }
  }
}
