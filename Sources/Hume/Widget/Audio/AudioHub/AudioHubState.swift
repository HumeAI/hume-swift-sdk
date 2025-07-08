//
//  AudioHubState.swift
//  Hume
//
//  Created by Chris on 6/30/25.
//

import Foundation

public enum AudioHubState {
    case unconfigured
    case configuring
    case stopped
    case starting
    case running
    case stopping
}
