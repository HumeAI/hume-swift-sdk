//
//  AudioBufferProcessor.swift
//  HumeAI2
//
//  Created by Chris on 12/17/24.
//

import AVFoundation
import Accelerate

class AudioBufferProcessor {
    static private let queue = DispatchQueue(label: "\(Constants.Namespace).audioBufferProcessor", qos: .userInteractive)
    
    static func process(buffer: AVAudioPCMBuffer, isMuted: Bool, handler: @escaping MicrophoneDataChunkBlock) {
        queue.async {
            Task {
                let bufferList = buffer.audioBufferList
                let audioBuffer = bufferList.pointee.mBuffers
                guard let mData = audioBuffer.mData else {
                    Logger.error("AudioBuffer missing data")
                    return
                }
                let dataSize = Int(audioBuffer.mDataByteSize)
                let data = Data(bytes: mData, count: dataSize)
                
                if (!isMuted) {
                    // Optional: Calculate average power if needed
                    let avgPower: Float = 0.0
                    await handler(data, avgPower)
                } else {
                    // Create a zero-filled array for simulated silence
                    let emptyData = Data(count: dataSize)
                    await handler(emptyData, 0.0)
                }
            }
        }
    }
}
