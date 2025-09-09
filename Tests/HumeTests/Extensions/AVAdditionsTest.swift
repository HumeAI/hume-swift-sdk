//
//  AVAdditionsTest.swift
//  Hume
//

import AVFoundation
import Foundation
import Testing

@testable import Hume

struct AVAdditionsTest {
  #if os(iOS)
    @Test func avAudioSession_recordPermission_maps_to_MicrophonePermission() async throws {
      // Assert direct mapping values compile and map correctly
      #expect(AVAudioSession.RecordPermission.undetermined.asMicrophonePermission == .undetermined)
      #expect(AVAudioSession.RecordPermission.denied.asMicrophonePermission == .denied)
      #expect(AVAudioSession.RecordPermission.granted.asMicrophonePermission == .granted)
    }

    @Test func avAudioApplication_recordPermission_maps_to_MicrophonePermission() async throws {
      if #available(iOS 17.0, *) {
        #expect(AVAudioApplication.recordPermission.undetermined.asMicrophonePermission == .undetermined)
        #expect(AVAudioApplication.recordPermission.denied.asMicrophonePermission == .denied)
        #expect(AVAudioApplication.recordPermission.granted.asMicrophonePermission == .granted)
      } else {
        // Can't reference AVAudioApplication on earlier iOS; ensure test doesn't run
        #expect(true)
      }
    }
  #endif
}
