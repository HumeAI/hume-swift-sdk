//
//  SoundClip.swift
//  HumeAI2
//
//  Created by Chris on 12/16/24.
//

import Foundation

public struct SoundClip {
    public let id: String
    public let index: Int
    public let audioData: Data
    public let header: WAVHeader?
    
    public static func from(_ audioOutput: AudioOutput) -> SoundClip? {
        guard let audioData = audioOutput.asBase64EncodedData else {
            return nil
        }
        
        return SoundClip(id: audioOutput.id,
                    index: audioOutput.index,
                    audioData: audioData,
                         header: audioData.parseWAVHeader())
    }
}

public struct WAVHeader {
    let chunkID: String
    let format: String
    let subchunk1ID: String
    let audioFormat: UInt16
    let numChannels: UInt16
    let sampleRate: UInt32
    let byteRate: UInt32
    let blockAlign: UInt16
    let bitsPerSample: UInt16
}
