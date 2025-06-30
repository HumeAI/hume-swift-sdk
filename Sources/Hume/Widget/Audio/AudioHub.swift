//
//  AudioHub.swift
//  HumeAI2
//
//  Created by Chris on 12/17/24.
//

import AVFAudio
import AVFoundation
import Combine

public enum AudioHubError: Error {
    case audioSessionConfigError
    case soundPlayerDecodingError
    case outputFormatError
}

public protocol AudioHub {
    var outputMeterListener: ((Float) -> Void)? { get set }
    var isOutputMeteringEnabled: Bool { get set }
    
    var microphoneMode: MicrophoneMode { get }
    var microphoneDataChunkHandler: MicrophoneDataChunkBlock? { get set }
    
    var state: AnyPublisher<AudioHubState, Never> { get }
    var stateSubject: CurrentValueSubject<AudioHubState, Never> { get }

    func configure() async throws
    
    func enqueue(soundClip: SoundClip)
    
    func start() async throws
    func stop() async throws

    func handleInterruption()
    func muteMic(_ mute: Bool)
}

public enum AudioHubState {
    case unconfigured
    case configuring
    case stopped
    case starting
    case running
    case stopping
}

public protocol AudioHubDelegate {
    func audioHub(_ audioHub: AudioHub, did soundClip: SoundClip)
}

public class AudioHubImpl: AudioHub {
    // MARK: Audio gear
    internal let audioEngine = AVAudioEngine()
    private let audioSession = AudioSession.shared
    private var soundPlayer: SoundPlayer? {
        didSet {
            if let _pendingOutputMeterEnabled, let soundPlayer {
                isOutputMeteringEnabled = _pendingOutputMeterEnabled
            }
        }
    }
    private var microphone: Microphone!
    private var inputNode: AVAudioInputNode!
    internal var mainMixer: AVAudioMixerNode!
    private var outputNode: AVAudioOutputNode!
    
    public var microphoneMode: MicrophoneMode {
        return MicrophoneMode(
            preferredMode: AVCaptureDevice.preferredMicrophoneMode,
            activeMode: AVCaptureDevice.activeMicrophoneMode)
    }

    // MARK: Metering
    // FIXME: hacky solution to a crash when trying to set this when granting mic permissions. hacked because we're releasing beta, lets clean up the state management for this and incoroporate mic permsission handling in the SDK before public release of SDK.
    private var _pendingOutputMeterEnabled: Bool?
    public var isOutputMeteringEnabled: Bool = false {
        didSet {
            if let soundPlayer {
                soundPlayer.meteringNode.isMetering = isOutputMeteringEnabled
                _pendingOutputMeterEnabled = nil
            } else {
                _pendingOutputMeterEnabled = isOutputMeteringEnabled
            }
        }
    }
    public var outputMeterListener: ((Float) -> Void)? {
        didSet {
            if let soundPlayer {
                soundPlayer.meteringNode.meterListener = outputMeterListener
            }
            if outputMeterListener == nil && isOutputMeteringEnabled {
                // disable metering to save resources if there's no listener
                isOutputMeteringEnabled = false
            }
        }
    }
    
    // MARK: State
    @MainActor
    public var state: AnyPublisher<AudioHubState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    @MainActor
    public var stateSubject = CurrentValueSubject<AudioHubState, Never>(.unconfigured)
    
    // MARK: Queues
    private let microphoneQueue = DispatchQueue(label: "\(Constants.Namespace).microphone.queue")
    
    // MARK: Handlers
    public var microphoneDataChunkHandler: MicrophoneDataChunkBlock?
    
    /// - parameters:
    /// - microphoneHandler: Callback when microphone data is received. This block is executed on a serial queue to guarantee the sequence of samples
    ///
    /// - throws: `AudioSessionError`, `MicrophoneError`
    init() {
        Logger.info("initializing AudioHub")
        audioSession.delegate = self
    }

    public func configure() async throws {
        Logger.info("configuring audio hub ")
        guard case .unconfigured = await stateSubject.value else {
            Logger.warn("audio hub already configured")
            return
        }
        await stateSubject.send(.configuring)
        
        do {
            try audioSession.configure()
            try audioSession.start(for: .voiceChat)
            
            Logger.debug("Creating audio nodes")
            inputNode = audioEngine.inputNode
            mainMixer = audioEngine.mainMixerNode
            outputNode = audioEngine.outputNode
            
            Logger.debug("Initializing microphone")
            self.microphone = try Microphone(audioEngine: audioEngine,
                                             sampleRate: Constants.SampleRate,
                                             sampleSize: Constants.SampleSize,
                                             audioFormat: Constants.DefaultAudioFormat)
            
            self.microphone.onChunk = handleMicrophoneDataChunk
            connectAudioEngineInputs()
        } catch {
            await stateSubject.send(.unconfigured)
            throw error
        }
        
        await stateSubject.send(.stopped)
    }

    public func enqueue(soundClip: SoundClip) {
        Logger.info("Adding message to SoundPlayer: \(soundClip.id) (\(soundClip.index)")
        if soundPlayer == nil, let header = soundClip.header {
            initializeSoundPlayer(with: header)
        }
        soundPlayer?.enqueueAudio(soundClip: soundClip)
    }
    
    public func handleInterruption() {
        guard let soundPlayer else {
            Logger.warn("no sound player to clear queue")
            return
        }
        soundPlayer.clearQueue()
    }
    
    public func start() async throws {
        guard [.stopped, .stopping].contains(await stateSubject.value) else {
            assertionFailure("expected audio hub to be stopped before starting")
            return
        }
        await stateSubject.send(.starting)
        Logger.info("Starting AudioHub")
        try audioSession.start(for: .voiceChat)
        try audioEngine.start()
        await stateSubject.send(.running)
    }
    
    public func stop() async throws {
        Logger.info("Stopping AudioHub")
        let state = await stateSubject.value
        switch state {
        case .starting:
            Logger.warn("audio hub was starting, waiting to finish")
            try await stateSubject.waitFor(.running)
        case .stopped, .stopping, .unconfigured, .configuring:
            Logger.warn("attempted to stop audio hub from \(state) state")
            return
        case .running:
            break
        }

        await stateSubject.send(.stopping)

        microphoneDataChunkHandler = nil
        soundPlayer?.clearQueue()
        
        if audioEngine.isRunning {
            Logger.debug("Stopping audio engine")
            audioEngine.stop()
        }
        
        try audioSession.stop(configuration: .voiceChat)
        await stateSubject.send(.stopped)
    }
    
    public func muteMic(_ mute: Bool) {
        if mute {
            microphone.mute()
        } else {
            microphone.unmute()
        }
    }
    
    // MARK: - Helpers
    private func initializeSoundPlayer(with header: WAVHeader) {
        Logger.info("Initializing sound player with header: \(header)")
        guard let inputFormat = AVAudioFormat(commonFormat: Constants.DefaultAudioFormat.commonFormat,
                                        sampleRate: Double(header.sampleRate),
                                        channels: AVAudioChannelCount(header.numChannels),
                                              interleaved: header.numChannels > 1) else {
            Logger.error("Failed to create input format for sound player")
            return
        }
        soundPlayer = SoundPlayer(inputFormat: inputFormat)
        
        guard let soundPlayer else {
            Logger.error("Sound player is not initialized")
            return
        }
        connectAudioEngineOutputs(outputFormat: outputNode.outputFormat(forBus: 0))
    }
    
    // MARK: - Connections
    private func disconnectAudioGraph() {
        Logger.info("Disconnecting audio graph")
        if let inputNode {
            audioEngine.disconnectNodeOutput(inputNode)
        } else {
            Logger.warn("missing input node while disconnecting audio graph")
        }
        
        if let soundPlayer {
            audioEngine.disconnectNodeOutput(soundPlayer.audioNode)
        } else {
            Logger.warn("missing output node while disconnecting audio graph")
        }
    }
    
    private func connectAudioEngineInputs() {
        Logger.debug("Connecting input chain")
        audioEngine.attach(microphone.sinkNode)
        audioEngine.connect(inputNode, to: microphone.sinkNode, format: nil)
    }
    
    private func connectAudioEngineOutputs(outputFormat: AVAudioFormat?) {
        guard let soundPlayer else {
            Logger.error("Sound player is not initialized")
            return
        }
        audioEngine.attach(soundPlayer.audioNode)
        let actualOutputFormat = outputFormat
        audioEngine.connect(soundPlayer.audioNode, to: mainMixer, format: actualOutputFormat)
    }
    
    // MARK: - Handlers
    
    private func handleMicrophoneDataChunk(data: Data, averagePower: Float)  {
        self.microphoneQueue.async { [weak self] in
            Task {
                // TODO: make averagePower configurable, currently omitting this data
                guard let self else { assertionFailure("lost AudioHub self"); return }
                if self.microphoneDataChunkHandler == nil {
                    Logger.warn("no mic data chunk handler set ")
                }
                await self.microphoneDataChunkHandler?(data, averagePower)
            }
        }
    }
}

// MARK: - Audio Session Delegate

extension AudioHubImpl: AudioSessionDelegate {
    func audioEngineDidChangeConfiguration() {
        Logger.info("AudioHubImpl responding to audio engine configuration change")
        microphoneQueue.async { [weak self] in
            Task {
                guard let self else { assertionFailure("AudioHub is missing self"); return }
                try? await self.reconfigure()
            }
        }
    }
    
    private func reconfigure() async throws {
        guard await stateSubject.value != .configuring, soundPlayer != nil else {
            Logger.warn("attempted to reconfigure while audio hub is configuring")
            return
        }
        
        Logger.debug("Reconfiguring audio hub")
        audioEngine.stop()
        
        disconnectAudioGraph()
        connectAudioEngineInputs()
        connectAudioEngineOutputs(outputFormat: outputNode.outputFormat(forBus: 0))

        if await stateSubject.value == .running {
            // only start back up if we're running
            try? audioEngine.start()
        }
    }
}
