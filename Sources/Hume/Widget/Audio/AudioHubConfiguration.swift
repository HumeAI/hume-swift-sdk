//
//  AudioSessionConfiguration.swift
//  HumeAI2
//
//  Created by Chris on 4/4/25.
//

import Foundation
import AVFoundation

public enum AudioHubConfiguration {
    case voiceChat
    case tts
    
    internal var category: AVAudioSession.Category {
        switch self {
        case .voiceChat:
            return .playAndRecord
        case .tts:
            return .playback
        }
    }
    
    internal var options: AVAudioSession.CategoryOptions {
        switch self {
        case .voiceChat: return [
            .allowBluetooth,
            .allowBluetoothA2DP,
            .allowAirPlay,
            .defaultToSpeaker,
            .overrideMutedMicrophoneInterruption
        ]
        case .tts:
            // no option necessary
            return [] 
        }
    }
    
    internal var mode: AVAudioSession.Mode {
        switch self {
        case .voiceChat: .videoChat
        case .tts: .moviePlayback
        }
    }
    
    internal var requiresMicrophone: Bool {
        switch self {
        case .voiceChat: true
        case .tts: false 
        }
    }
}

