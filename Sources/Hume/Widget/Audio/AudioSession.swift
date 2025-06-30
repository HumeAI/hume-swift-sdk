import AVFAudio
import Combine
import Foundation

public enum AudioFormat {
    case PCM_16BIT
    
    var commonFormat: AVAudioCommonFormat {
        switch self {
        case .PCM_16BIT: return .pcmFormatInt16
        }
    }
    
    var encoding: Encoding {
        switch self {
        case .PCM_16BIT: return .linear16
        }
    }
    
    var description: String {
        switch self {
        case .PCM_16BIT: return "16-bit PCM"
        }
    }
}

enum AudioSessionError: Error {
    case noAvailableDevices
    case multipleOutputRoutes
    case unsupportedConfiguration(reason: String)

    var errorDescription: String? {
        switch self {
        case .noAvailableDevices:
            return "No available input or output devices in the current session."
        case .multipleOutputRoutes:
            return "Invalid output configuration: multiple or no output routes found."
        case .unsupportedConfiguration(let reason):
            return "Unsupported configuration: \(reason)"
        }
    }
}


struct AudioSessionIO {
    var input: AVAudioSessionPortDescription
    var output: AVAudioSessionPortDescription
}

protocol AudioSessionDelegate: AnyObject {
    func audioEngineDidChangeConfiguration()
}

class AudioSession {
    private let audioSession = AVAudioSession.sharedInstance()
    internal var lastInputPort: AVAudioSessionPortDescription?
    
    static let shared = AudioSession()
    
    /// Keeps track of configs for audio session. This is used to restore
    /// a past configuration if we start another one during an active session.
    /// The specific case this was added for is when we're in an active call, and the user wants to edit the voice, we need to enable the sample player momentarily
    private var activeConfig: Configuration? = nil
    
    @Published var isDeviceSpeakerActive: Bool = false
    weak var delegate: (any AudioSessionDelegate)? = nil

    // Track observer registration
    private var observersRegistered = false

    func start(for configuration: AudioSession.Configuration) throws {
        Logger.debug("Starting audio session for config: \(configuration)")
        try updateCategory(config: configuration)
        try audioSession.setActive(true)
        activeConfig = configuration
        try handleAudioRouting()
        Logger.debug("Starting audio engine")
    }
    
    func stop(configuration: AudioSession.Configuration) throws {
        guard activeConfig == configuration else {
            return
        }
        
        activeConfig = nil
        try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
    }
    
    // MARK: Configuring
    func configure() throws {
        Logger.info("Configuring audio session")

        do {
            try audioSession.setPreferredIOBufferDuration(Constants.InputBufferDuration)  //20 ms as per EVI docs
            try audioSession.setPreferredSampleRate(Constants.SampleRate)
            
            registerAVObservers()
            Logger.info("Audio session configured successfully")
        } catch {
            throw AudioSessionError.unsupportedConfiguration(reason: "Failed to configure audio session")
        }
    }
    
    private func updateCategory(config: Configuration) throws {
        let (category, mode, options) = (config.category, config.mode, config.options)
        guard AVAudioSession.sharedInstance().availableCategories.contains(category) else {
            throw AudioSessionError.unsupportedConfiguration(reason: "\(category) is not supported.")
        }
        try audioSession.setCategory(category, mode: mode, options: options)
    }
    
    private func registerAVObservers() {
        guard !observersRegistered else { return }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleConfigurationChange),
                                               name: .AVAudioEngineConfigurationChange,
                                               object: nil)
        observersRegistered = true
    }
    
    private func unregisterAVObservers() {
        NotificationCenter.default.removeObserver(self)
        observersRegistered = false
    }
    
    // MARK: - Audio Routing
    private func overrideReceiverIfNeeded(ioConfig: AudioSessionIO) throws {
        if ioConfig.output.portType == .builtInReceiver || ioConfig.output.portType == .builtInSpeaker {
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
            inputPort = inputs.first! // already checked that non-empty
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
        // TODO: implement interruption handling
        Logger.info("Interruption notification received")
    }
    
    @objc
    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else {
            Logger.warn("Route change reason is missing")
            return
        }
        
        Logger.info("Route change notification received: \(reason)")
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .unknown, .wakeFromSleep, .routeConfigurationChange:
            Task {
                do {
                    try handleAudioRouting()
                } catch {
                    Logger.error("Route change error: \(error.localizedDescription)")
                }
            }
        case .noSuitableRouteForCategory, .override, .categoryChange:
            Logger.info("Skipping route change, handling separately as interruption: \(reason)")
        @unknown default:
            Logger.warn("Unhandled route change type: \(reason)")
        }
    }
}
