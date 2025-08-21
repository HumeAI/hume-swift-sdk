//
//  TTSProvider.swift
//  Hume
//
//  Created by Chris on 7/7/25.
//

import AVFoundation

enum TTSError: Error {
  case uninitializedPlayer
}

/// Audio player that directly plays a TTS stream from a request. Use this widget for a quick and simple streaming solution.
public class TTSPlayer {
  private var audioHub: AudioHub
  private var _wavPlayer: SoundPlayer?

  private let defaultFormat: AVAudioFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)!

  public init(audioHub: AudioHub) {
    self.audioHub = audioHub
    //    self.tts = tts
  }

  public func play(soundClip: SoundClip, format: Format?) async throws {
    // TODO: decide which format
    let player: SoundPlayer
    if let wavFormat = soundClip.header?.asAVAudioFormat {
      player = try await getWavPlayer(format: wavFormat)
    } else if let _wavPlayer {
      player = _wavPlayer
    } else {
      throw TTSError.uninitializedPlayer
    }

    try await audioHub.startEngineIfNeeded()
    Task {
      await player.enqueueAudio(soundClip: soundClip)
    }
  }

  // MARK: - Playback

  //  private func playFileStream(for request: PostedTts) async throws {
  //    let stream = tts.synthesizeFileStreaming(request: request)
  //
  //    for try await data in stream {
  //      guard let soundClip = SoundClip.from(data), let format = soundClip.header?.asAVAudioFormat
  //      else {
  //        Logger.warn("failed to create sound clip")
  //        return
  //      }
  //
  //      let soundPlayer = try await getSoundPlayer(format: format)
  //
  //      try await soundPlayer.enqueueAudio(soundClip: soundClip)
  //
  //    }
  //  }

  private func getWavPlayer(format: AVAudioFormat) async throws -> SoundPlayer {
    if let _wavPlayer, await _wavPlayer.format == format {
      return _wavPlayer
    } else if let _wavPlayer, await _wavPlayer.format != format {
      Logger.debug("SoundPlayer format mismatch, detaching old node")
      try await audioHub.detachNode(_wavPlayer.audioSourceNode)
    }
    Logger.debug("Creating new SoundPlayer with format \(format.prettyPrinted)")
    _wavPlayer = SoundPlayer(format: format)
    try await audioHub.addNode(_wavPlayer!.audioSourceNode, format: format)
    return _wavPlayer!
  }
}
