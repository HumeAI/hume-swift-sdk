//
//  TTSClient.swift
//  Hume
//
//  Created by Chris on 6/25/25.
//

import Foundation

public class TTSClient {
    private let networkClient: NetworkClient
    
    init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }
    
    public lazy var tts: TTS = { TTS(networkClient: networkClient) }()
//    public lazy var voices: Voices = { Voices(options: options) }()
}
