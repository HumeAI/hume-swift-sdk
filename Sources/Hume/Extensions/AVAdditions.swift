//
//  AVAdditions.swift
//  HumeAI2
//
//  Created by Chris on 1/10/25.
//

import AVFoundation

#if HUME_IOS
  // MARK: - Microphone permissions
  public enum MicrophonePermission {
    case undetermined
    case denied
    case granted

    public static var current: MicrophonePermission {
      if #available(iOS 17.0, *) {
        return AVAudioApplication.shared.recordPermission.asMicrophonePermission
      } else {
        return AVAudioSession.sharedInstance().recordPermission.asMicrophonePermission
      }
    }

    public static func requestPermissions() async -> Bool {
      if #available(iOS 17.0, *) {
        return await AVAudioApplication.requestRecordPermission()
      } else {
        return await withCheckedContinuation { cont in
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            cont.resume(with: .success(granted))
          }
        }
      }
    }
  }

  @available(iOS 17.0, *)
  extension AVAudioApplication.recordPermission {
    var asMicrophonePermission: MicrophonePermission {
      switch self {
      case .undetermined: return .undetermined
      case .denied: return .denied
      case .granted: return .granted
      default: return .undetermined
      }
    }
  }

  extension AVAudioSession.RecordPermission {
    var asMicrophonePermission: MicrophonePermission {
      switch self {
      case .undetermined: return .undetermined
      case .denied: return .denied
      case .granted: return .granted
      default: return .undetermined
      }
    }
  }
#endif

// MARK: - Pretty printing
// Protocol declaration
internal protocol Prettifiable {
  var prettyPrinted: String { get }
}

// Extension for AVAudioConverter
extension AVAudioConverter: Prettifiable {
  internal var prettyPrinted: String {
    var description = "AVAudioConverter Properties:\n"
    description += "Input Format: \(inputFormat)\n"
    description += "Output Format: \(outputFormat)\n"
    description += "Channel Map: \(channelMap.description)\n"
    description += "Bit Rate: \(bitRate)\n"
    description += "Bit Rate Strategy: \(bitRateStrategy ?? "nil")\n"
    description +=
      "Sample Rate Converter Algorithm: \(sampleRateConverterAlgorithm?.description ?? "nil")\n"
    description += "Available Encode Bit Rates: \(availableEncodeBitRates?.description ?? "nil")\n"
    description +=
      "Available Encode Channel Layout Tags: \(availableEncodeChannelLayoutTags?.description ?? "nil")\n"
    return description
  }
}

// Extension for AVAudioNode
extension AVAudioNode: Prettifiable {
  internal var prettyPrinted: String {
    var description = "AVAudioNode Properties:\n"
    description += "Engine: \(engine?.description ?? "nil")\n"
    description += "Input format: \(inputFormat(forBus: 0))\n"
    description += "Output format: \(outputFormat(forBus: 0))\n"
    description += "Number of Inputs: \(numberOfInputs)\n"
    description += "Number of Outputs: \(numberOfOutputs)\n"
    description += "Latency: \(latency)\n"
    description += "AUAudioUnit: \(auAudioUnit)\n"
    description += "Last Render Time: \(lastRenderTime?.description ?? "nil")\n"
    description += "Output Presentation Latency: \(outputPresentationLatency)\n"
    return description
  }
}

// Extension for AVAudioFormat
extension AVAudioFormat: Prettifiable {
  internal var prettyPrinted: String {
    var description = "AVAudioFormat Properties:\n"
    description += "Sample Rate: \(sampleRate)\n"
    description += "Channel Count: \(channelCount)\n"
    description += "Common Format: \(commonFormat.readableDescription)\n"
    description += "Interleaved: \(isInterleaved)\n"
    if let layout = channelLayout {
      description += "Channel Layout: \(layout.description)\n"
    } else {
      description += "Channel Layout: nil\n"
    }
    return description
  }
}

// Adding readable description for AVAudioCommonFormat for internal debugging
extension AVAudioCommonFormat {
  var readableDescription: String {
    switch self {
    case .pcmFormatFloat32: return "PCM Float32"
    case .pcmFormatFloat64: return "PCM Float64"
    case .pcmFormatInt16: return "PCM Int16"
    case .pcmFormatInt32: return "PCM Int32"
    case .otherFormat: return "Other Format"
    @unknown default: return "Unknown Format"
    }
  }
}

extension AVAudioEngine: Prettifiable {
  internal var prettyPrinted: String {
    var description = "AVAudioEngine Configuration:\n"

    description += "\nInput Node:\n"
    description += "\(describeNode(inputNode))\n"

    description += "\nOutput Node:\n"
    description += "\(describeNode(outputNode))\n"

    description += "\nAttached Nodes:\n"
    if attachedNodes.isEmpty {
      description += "None\n"
    } else {
      for node in attachedNodes {
        description += "\(describeNode(node))\n"
      }
    }

    description += "\nConnections:\n"
    for node in attachedNodes {
      for point in outputConnectionPoints(for: node, outputBus: 0) {
        description += "From: \(describeNode(node)) -> To: \(describeConnectionPoint(point))\n"
      }
    }

    return description
  }

  private func describeNode(_ node: AVAudioNode?) -> String {
    guard let node = node else { return "nil" }

    var nodeDescription = "\(type(of: node)): "

    if let format = node.outputFormat(forBus: 0) as AVAudioFormat? {
      nodeDescription += "[Channels: \(format.channelCount), SampleRate: \(format.sampleRate)]"
    } else {
      nodeDescription += "No Output"
    }

    return nodeDescription
  }

  private func describeConnectionPoint(_ point: AVAudioConnectionPoint) -> String {
    guard let node = point.node else { return "Unknown Node" }
    guard point.bus < node.numberOfOutputs else {
      return "\(type(of: node)) [Invalid bus: \(point.bus), Max: \(node.numberOfOutputs - 1)]"
    }
    let format = node.outputFormat(forBus: point.bus)
    return
      "\(type(of: node)) [Bus: \(point.bus), Channels: \(format.channelCount), SampleRate: \(format.sampleRate)]"
  }
}
