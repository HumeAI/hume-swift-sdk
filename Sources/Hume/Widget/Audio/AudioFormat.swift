//
//  AudioFormat.swift
//  Hume
//
//  Created by Chris on 6/30/25.
//

import AVFoundation

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
