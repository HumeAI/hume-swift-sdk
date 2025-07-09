//
//  MockMicrophoneMode.swift
//  Hume
//
//  Created by Chris on 6/24/25.
//

import AVFoundation
import Foundation
import Hume

public extension MicrophoneMode {
    public static func mock(preferredMode: AVCaptureDevice.MicrophoneMode, activeMode: AVCaptureDevice.MicrophoneMode) -> MicrophoneMode {
        return MicrophoneMode(preferredMode: preferredMode, activeMode: activeMode)
    }
}
