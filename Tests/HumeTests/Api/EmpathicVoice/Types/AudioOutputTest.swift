//
//  AudioOutputTest.swift
//
//
//  Created by Daniel Rees on 5/22/24.
//

import XCTest
@testable import Hume

final class AudioOutputTest: XCTestCase {
    
    let decoder = Defaults.decoder
    
    func test_decodesAudioOutput() throws {
        let json = """
        {
           "type": "audio_output",
           "id": "1f32aed9948045578e0c1756ccc23fa6",
           "data": "base_64_encoded_audio",
           "index": 0
        }
        """
        
        let message = try! decoder.decode(SubscribeEvent.self, from: json.data(using: .utf8)!)
        guard case SubscribeEvent.audioOutput(let audioOutput) = message else { fatalError() }
        
        XCTAssertEqual(audioOutput.type, "audio_output")
        XCTAssertEqual(audioOutput.id, "1f32aed9948045578e0c1756ccc23fa6")
        XCTAssertEqual(audioOutput.data, "base_64_encoded_audio")
    }
}
