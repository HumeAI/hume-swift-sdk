//
//  TTSProvider.swift
//  Hume
//
//  Created by Chris on 7/7/25.
//

import AVFoundation
import AudioToolbox

enum TTSError: Error {
  /// Player has not been initialized with a format
  case uninitializedPlayer
  /// Thrown when allocation of `AVAudioPCMBuffer` fails when decodfing mp3s
  case bufferAllocationFailed
  /// Thrown when decoding of mp3 data does not contain data in `floatChannelData`
  case unexpectedDataChannel
}

/// Handles playback of TTS audio clips in various formats (WAV, PCM, MP3).
public class TTSPlayer {
  private var audioHub: AudioHub
  private var _wavPlayer: SoundPlayer?
  private var _pcmPlayer: SoundPlayer?

  private let defaultPcmFormat: AVAudioFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16, sampleRate: 48000, channels: 1, interleaved: false)!

  public init(audioHub: AudioHub) {
    self.audioHub = audioHub
  }

  /// Play a `SoundClip` for a requested `Format`. Ensures the AudioHub's engine is running
  public func play(soundClip: SoundClip, format: Format) async throws {
    switch format {
    case .wav: try await playWav(soundClip: soundClip)
    case .pcm: try await playPcm(soundClip: soundClip)
    case .mp3: try await playMp3(soundClip: soundClip)
    }
  }

  // MARK: - Playback
  private func playPcm(soundClip: SoundClip) async throws {
    let player = try await getPcmPlayer(format: defaultPcmFormat)
    try await play(soundClip: soundClip, on: player)
  }

  private func playWav(soundClip: SoundClip) async throws {
    let player = try await getWavPlayer(format: soundClip.header?.asAVAudioFormat)
    try await play(soundClip: soundClip, on: player)
  }

  private func playMp3(soundClip: SoundClip) async throws {
    Logger.debug("ID: \(soundClip.id) -- \(soundClip.index).")
    let (data, format) = try decodeMP3ToPCMData(mp3Data: soundClip.audioData)
    let player = try await getPcmPlayer(format: format)
    let mp3SoundClip = SoundClip(id: soundClip.id, audioData: data, header: nil)
    Logger.debug("Decoded MP3 to PCM data of size \(data.count) bytes. ")
    try await play(soundClip: mp3SoundClip, on: player)
  }

  private func play(soundClip: SoundClip, on player: SoundPlayer) async throws {
    try await audioHub.startEngineIfNeeded()
    await player.enqueueAudio(soundClip: soundClip)
  }

  private func decodeMP3ToPCMData(mp3Data: Data) throws -> (Data, AVAudioFormat) {
    let tempURL = FileManager.default
      .temporaryDirectory
      .appendingPathComponent(UUID().uuidString + ".mp3")
    try mp3Data.write(to: tempURL)
    let mp3File = try AVAudioFile(forReading: tempURL)
    let format = mp3File.processingFormat
    let frameCount = AVAudioFrameCount(mp3File.length)

    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: frameCount)
    else {
      throw TTSError.bufferAllocationFailed
    }

    try mp3File.read(into: buffer)
    guard let channelData = buffer.floatChannelData else {
      throw TTSError.unexpectedDataChannel
    }
    let sampleCount = Int(buffer.frameLength) * Int(format.channelCount)
    return (
      Data(bytes: channelData[0], count: sampleCount * MemoryLayout<Float>.size),
      format
    )
  }

  // MARK: - Players

  private func getWavPlayer(format: AVAudioFormat?) async throws -> SoundPlayer {
    guard let format else {
      if let _wavPlayer {
        return _wavPlayer
      } else {
        throw TTSError.uninitializedPlayer
      }
    }

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

  private func getPcmPlayer(format: AVAudioFormat) async throws -> SoundPlayer {
    if let _pcmPlayer, await _pcmPlayer.format == format {
      return _pcmPlayer
    } else if let _pcmPlayer, await _pcmPlayer.format != format {
      Logger.debug("SoundPlayer format mismatch, detaching old node")
      try await audioHub.detachNode(_pcmPlayer.audioSourceNode)
    }
    Logger.debug("Creating new SoundPlayer with format \(format.prettyPrinted)")
    _pcmPlayer = SoundPlayer(format: format)
    try await audioHub.addNode(_pcmPlayer!.audioSourceNode, format: format)
    return _pcmPlayer!
  }
}
