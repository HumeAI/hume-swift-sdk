#if HUME_IOS
  //
  //  AudioHubError.swift
  //  Hume
  //
  //  Created by Chris on 8/21/25.
  //

  import Foundation

  public enum AudioHubError: Error {
    case audioSessionConfigError
    case soundPlayerDecodingError
    case soundPlayerInitializationError
    case headerMissing
    case engineFailed
    case outputFormatError
    case microphoneUnavailable
  }
#endif
