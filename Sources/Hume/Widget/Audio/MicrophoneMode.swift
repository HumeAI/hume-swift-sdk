#if HUME_WIDGET
  //
  //  MicrophoneMode.swift
  //  HumeAI2
  //
  //  Created by Chris on 1/28/25.
  //

  import AVFoundation

  public struct MicrophoneMode {
    /// The microphone mode the user explicitly selected
    public let preferredMode: AVCaptureDevice.MicrophoneMode
    /// The microphone mode currently active on the device
    public let activeMode: AVCaptureDevice.MicrophoneMode

    public init(
      preferredMode: AVCaptureDevice.MicrophoneMode, activeMode: AVCaptureDevice.MicrophoneMode
    ) {
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
#endif
