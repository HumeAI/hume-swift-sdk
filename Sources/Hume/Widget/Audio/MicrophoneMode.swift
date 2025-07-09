//
//  MicrophoneMode.swift
//  HumeAI2
//
//  Created by Chris on 1/28/25.
//

import AVFoundation

public struct MicrophoneMode {
    public let preferredMode: AVCaptureDevice.MicrophoneMode
    public let activeMode: AVCaptureDevice.MicrophoneMode
    
    package init(preferredMode: AVCaptureDevice.MicrophoneMode, activeMode: AVCaptureDevice.MicrophoneMode) {
        self.preferredMode = preferredMode
        self.activeMode = activeMode
    }
}

extension AVCaptureDevice.MicrophoneMode {
    public var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .wideSpectrum:
            return "Wide Spectrum"
        case .voiceIsolation:
            return "Voice Isolation"
        @unknown default:
            return "Unknown"
        }
    }
}
