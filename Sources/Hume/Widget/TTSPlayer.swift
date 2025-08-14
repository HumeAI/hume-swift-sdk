//
//  TTSProvider.swift
//  Hume
//
//  Created by Chris on 7/7/25.
//

import AVFoundation

/// Audio player that directly plays a TTS stream from a request
public protocol TTSPlayer {
  func playTtsStream(_ request: PostedTts) async throws

  /// Stops the audio player. Call this when navigating away from TTS functionality in your app.
  func teardown() async throws
}

/// Audio player that directly plays a TTS stream from a request. Use this widget for a quick and simple streaming solution.
public class TTSPlayerImpl: TTSPlayer {
  private var audioHub: AudioHub
  private var _soundPlayer: SoundPlayer?
  private let tts: TTS

  public init(audioHub: AudioHub, tts: TTS) {
    self.audioHub = audioHub
    self.tts = tts
  }

  public func playTtsStream(_ request: PostedTts) async throws {
    try await playFileStream(for: request)
  }

  // MARK: - Lifecycle

  public func teardown() async throws {
    //    try await audioHub.stop()
  }

  // MARK: - Playback

  private func playFileStream(for request: PostedTts) async throws {
    let stream = tts.synthesizeFileStreaming(request: request)

    for try await data in stream {
      guard let soundClip = SoundClip.from(data), let format = soundClip.header?.asAVAudioFormat
      else {
        Logger.warn("failed to create sound clip")
        return
      }

      let soundPlayer = try await getSoundPlayer(format: format)

      try await soundPlayer.enqueueAudio(soundClip: soundClip)

    }
  }

  private func getSoundPlayer(format: AVAudioFormat) async throws -> SoundPlayer {
    if let _soundPlayer, await _soundPlayer.format == format {
      return _soundPlayer
    } else if let _soundPlayer, await _soundPlayer.format != format {
      Logger.debug("SoundPlayer format mismatch, detaching old node")
      try await audioHub.detachNode(_soundPlayer.audioSourceNode)
    }
    Logger.debug("Creating new SoundPlayer with format \(format.prettyPrinted)")
    _soundPlayer = SoundPlayer(format: format)
    try await audioHub.addNode(_soundPlayer!.audioSourceNode, format: format)
    return _soundPlayer!
  }
}
