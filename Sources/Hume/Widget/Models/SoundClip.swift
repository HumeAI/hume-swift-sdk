//
//  SoundClip.swift
//  HumeAI2
//
//  Created by Chris on 12/16/24.
//

import Foundation

public struct SoundClip {
    public let id: String
    public var index: Int? = nil
    public let audioData: Data
    public let header: WAVHeader?
}

// MARK: - Convenient initializers
extension SoundClip {
    public static func from(_ audioOutput: AudioOutput) -> SoundClip? {
        guard let audioData = audioOutput.asBase64EncodedData else {
            return nil
        }
        
        return SoundClip(id: audioOutput.id,
                    index: audioOutput.index,
                    audioData: audioData,
                         header: audioData.parseWAVHeader())
    }
    
    public static func from(_ returnGeneration: ReturnGeneration) -> SoundClip? {
        guard let audioData = Data(base64Encoded: returnGeneration.audio) else {
            return nil
        }
        
        return SoundClip(id: returnGeneration.generationId,
                         audioData: audioData,
                         header: audioData.parseWAVHeader())
    }
    
    public static func from(_ snippet: Snippet) -> SoundClip? {
        guard let audioData = Data(base64Encoded: snippet.audio) else {
            return nil
        }
        
        return SoundClip(id: snippet.generationId,
                         audioData: audioData,
                         header: audioData.parseWAVHeader())
    }
    
    public static func from(_ snippetAudioChunk: SnippetAudioChunk) -> SoundClip? {
        guard let audioData = Data(base64Encoded: snippetAudioChunk.audio) else {
            return nil
        }
        
        return SoundClip(id: UUID().uuidString,
                         audioData: audioData,
                         header: audioData.isEmpty ? nil : audioData.parseWAVHeader())
    }
    
    public static func from(_ data: Data) -> SoundClip? {
        return SoundClip(id: UUID().uuidString,
                         audioData: data,
                         header: data.parseWAVHeader())
    }
}
