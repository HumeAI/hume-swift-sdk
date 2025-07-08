//
//  AudioSessionError.swift
//  Hume
//
//  Created by Chris on 6/30/25.
//

import AVFoundation

public enum AudioSessionError: Error {
    case unconfigured
    case noAvailableDevices
    case multipleOutputRoutes
    case unsupportedConfiguration(reason: String)

    var errorDescription: String? {
        switch self {
        case .unconfigured:
            return "AudioSession is unconfigured"
        case .noAvailableDevices:
            return "No available input or output devices in the current session."
        case .multipleOutputRoutes:
            return "Invalid output configuration: multiple or no output routes found."
        case .unsupportedConfiguration(let reason):
            return "Unsupported configuration: \(reason)"
        }
    }
}
