//
//  AudioSessionConfiguration.swift
//  HumeAI2
//
//  Created by Chris on 4/4/25.
//

import AVFoundation
import Foundation

enum AudioHubConfiguration {
  case inputOutput
  case outputOnly

  internal var category: AVAudioSession.Category {
    switch self {
    case .inputOutput:
      return .playAndRecord
    case .outputOnly:
      return .playback
    }
  }

  internal var options: AVAudioSession.CategoryOptions {
    switch self {
    case .inputOutput:
      return [
        .allowBluetooth,
        .allowBluetoothA2DP,
        .defaultToSpeaker,
        .overrideMutedMicrophoneInterruption,
      ]
    case .outputOnly:
      // no option necessary
        return AVAudioSession.CategoryOptions(rawValue: 0)
    }
  }

  internal var mode: AVAudioSession.Mode {
    switch self {
    case .inputOutput: .videoChat
    case .outputOnly: .moviePlayback
    }
  }
}
