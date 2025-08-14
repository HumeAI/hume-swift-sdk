//
//  WAVHeader.swift
//  Hume
//
//  Created by Chris on 6/30/25.
//

import AVFoundation
import Foundation

public struct WAVHeader {
  let chunkID: String
  let format: String
  let subchunk1ID: String
  let audioFormat: UInt16
  let numChannels: UInt16
  let sampleRate: UInt32
  let byteRate: UInt32
  let blockAlign: UInt16
  let bitsPerSample: UInt16
}

extension WAVHeader {
  var isValid: Bool {
    return chunkID == "RIFF" && format == "WAVE"
  }
}

// MARK: - AVFoundation Extensions
extension WAVHeader {
  var asAVAudioFormat: AVAudioFormat? {
    AVAudioFormat(
      commonFormat: Constants.DefaultAudioFormat.commonFormat,
      sampleRate: Double(self.sampleRate),
      channels: AVAudioChannelCount(self.numChannels),
      interleaved: self.numChannels > 1)
  }
}
