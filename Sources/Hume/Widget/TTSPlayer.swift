//
//  TTSProvider.swift
//  Hume
//
//  Created by Chris on 7/7/25.
//

/// Audio player that directly plays a TTS stream from a request
public protocol TTSPlayer {
    func playTtsStream(_ request: PostedTtsStream) async throws
    
    /// Prepares the audio player. Call this before attempting to play a strema
    func prepare() async throws
    /// Stops the audio player. Call this when navigating away from TTS functionality in your app.
    func teardown() async throws
}

/// Audio player that directly plays a TTS stream from a request. Use this widget for a quick and simple streaming solution.
public class TTSPlayerImpl: TTSPlayer {
    private var audioHub: AudioHub
    private let tts: TTS
    
    public init(audioHub: AudioHub, tts: TTS) {
        self.audioHub = audioHub
        self.tts = tts
    }
    
    public func playTtsStream(_ request: PostedTtsStream) async throws {
        if await audioHub.stateSubject.value != .running {
            try await prepare()
        }
        
        try await playFileStream(for: request)
    }
    
    // MARK: - Lifecycle
    
    public func prepare() async throws {
        try await audioHub.configure(with: .tts)
        try await audioHub.start()
    }
    
    public func teardown() async throws {
        try await audioHub.stop()
    }
    
    // MARK: - Playback
    
    private func playFileStream(for request: PostedTtsStream) async throws {
        let stream = tts.synthesizeFileStreaming(request: request)

        for try await data in stream {
            guard let soundClip = SoundClip.from(data) else {
                Logger.warn("failed to create sound clip")
                return
            }
            try await audioHub.enqueue(soundClip: soundClip)
            
        }
    }
}
