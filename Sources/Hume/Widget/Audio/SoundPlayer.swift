//
//  SoundPlayer.swift
//

import AVFAudio
import Foundation
import os

public actor SoundPlayer: Sendable {
  // MARK: - Public Properties
  var format: AVAudioFormat { rawAudioPlayer.format }

  var audioSourceNode: AVAudioSourceNode {
    rawAudioPlayer.meteredSourceNode.sourceNode
  }

  // MARK: - Private properties
  private var rawAudioPlayer: RawAudioPlayer

  private var isMeteringEnabled: Bool = false
  private var meteringCallback: ((Float) -> Void)?

  // MARK: - Initialization
  init(format: AVAudioFormat) {
    self.rawAudioPlayer = RawAudioPlayer(format: format)
  }

  public func enqueueAudio(soundClip: SoundClip) {
    Logger.debug("enqueueAudio called with \(soundClip.audioData.count) bytes of data")
    rawAudioPlayer.enqueueAudio(data: soundClip.headerlessData())
  }

  public func clearQueue() {
    Logger.info("clearQueue called")
    rawAudioPlayer.clearQueue()
  }

  // MARK: - Metering
  public func toggleMetering(enabled: Bool) {
    rawAudioPlayer.meteredSourceNode.isMetering = enabled
    isMeteringEnabled = enabled
  }

  public func startMetering(callback: ((Float) -> Void)?) {
    toggleMetering(enabled: true)

    rawAudioPlayer.meteredSourceNode.meterListener = callback
    meteringCallback = callback
  }
}
