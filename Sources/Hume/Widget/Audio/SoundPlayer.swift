//
//  SoundPlayer.swift
//

import AVFAudio
import Foundation
import os

public class SoundPlayer {
    private let rawAudioPlayer: RawAudioPlayer
    var audioNode: AVAudioSourceNode {
        rawAudioPlayer.sourceNode.sourceNode
    }
    
    var meteringNode: MeteredAudioSourceNode {
        rawAudioPlayer.sourceNode
    }

    init(inputFormat: AVAudioFormat) {
        self.rawAudioPlayer = RawAudioPlayer(format: inputFormat)!
        Logger.info("Initializing SoundPlayer with RawAudioPlayer")
    }

    func enqueueAudio(soundClip: SoundClip) {
        Logger.info("enqueueAudio called with \(soundClip.audioData.count) bytes of data")
        Task {
            rawAudioPlayer.enqueueAudio(clip: soundClip)
        }
    }

    func clearQueue() {
        Logger.info("clearQueue called")
        rawAudioPlayer.clearQueue()
    }
}


// Adjusted RawAudioPlayer with crossfade support
private class RawAudioPlayer {
    var sourceNode: MeteredAudioSourceNode!
    fileprivate var audioQueue: [Data] = []
    private let syncQueue = DispatchQueue(label: "\(Constants.Namespace).audioOutput.queue")
    private let format: AVAudioFormat

    // Fade-in/out config
    private var isStartingPlayback = true
    private var wasSilenceLastTime = true
    private let fadeLength = 1024

    // Crossfade configuration
    // Similar logic as fade-in can be applied, but we do it at enqueue time
    private let crossfadeLength = 1024
    private var previousClip: SoundClip?

    init?(format: AVAudioFormat) {
        self.format = format
        sourceNode = MeteredAudioSourceNode(format: format, renderBlock: supplyAudioData)
    }

    func enqueueAudio(clip: SoundClip) {
        syncQueue.sync {
            let clipData = clip.audioData

            // Check for potential consecutive clip crossfade
            if let lastData = audioQueue.last {
                if let crossfadedData = crossfadeAudioData(oldData: lastData,
                                                           newData: clipData,
                                                           crossfadeSamples: crossfadeLength) {
                    // Replace last queued data with crossfaded result
                    audioQueue.removeLast()
                    audioQueue.append(crossfadedData)
                    return
                }
            }

            audioQueue.append(clipData)
            previousClip = clip
        }
    }

    func clearQueue() {
        syncQueue.sync {
            audioQueue.removeAll()
            isStartingPlayback = true
            wasSilenceLastTime = true
            previousClip = nil
            
            Logger.debug("Queue Cleared: Reset to initial state")
        }
        
    }

    private func supplyAudioData(isSilence: UnsafeMutablePointer<ObjCBool>,
                                 timestamp: UnsafePointer<AudioTimeStamp>,
                                 frameCount: AVAudioFrameCount,
                                 outputData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {

        let ablPointer = UnsafeMutableAudioBufferListPointer(outputData)

        return syncQueue.sync {
            // Zero out buffers
            for buffer in ablPointer {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            guard !audioQueue.isEmpty else {
                // Full silence if empty at start
                isSilence.pointee = true
                if !wasSilenceLastTime {
                    Logger.debug("Transitioning to Silence: No data in queue")
                }
                wasSilenceLastTime = true
                return noErr
            }

            // If we had silence last time, note that we are potentially starting playback again
            if wasSilenceLastTime {
                isStartingPlayback = true
            }

            // Transition from silence logging
            if wasSilenceLastTime {
                isStartingPlayback = true
            }

            let streamDesc = format.streamDescription.pointee
            let bytesPerFrame = Int(streamDesc.mBytesPerFrame)
            let bytesRequested = Int(frameCount) * bytesPerFrame

            // Each Int16 sample is 2 bytes
            let sampleCount = bytesRequested / 2
            var tempBuffer = [Int16](repeating: 0, count: sampleCount)
            var bytesProvided = 0

            while bytesProvided < bytesRequested && !audioQueue.isEmpty {
                let chunk = audioQueue.removeFirst()
                let remainingBytes = bytesRequested - bytesProvided
                let chunkSize = min(chunk.count, remainingBytes)

                chunk.withUnsafeBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress else { return }
                    let offsetPointer = UnsafeMutableRawPointer(
                        mutating: tempBuffer.withUnsafeMutableBytes { $0.baseAddress! }
                    ).advanced(by: bytesProvided)
                    memcpy(offsetPointer, baseAddress, chunkSize)
                }

                bytesProvided += chunkSize

                // Handle leftover chunk data
                if chunkSize < chunk.count {
                    let leftover = chunk.subdata(in: chunkSize..<chunk.count)
                    audioQueue.insert(leftover, at: 0)
                }
            }

            // Fade-in processing
            if isStartingPlayback && bytesProvided > 0 {
                applyFadeIn(to: &tempBuffer, fadeLength: fadeLength)
                isStartingPlayback = false
            }

            // Copy to output buffers
            for buffer in ablPointer {
                let copyCount = min(Int(buffer.mDataByteSize), bytesProvided)
                _ = tempBuffer.withUnsafeBytes { rawBuffer in
                    memcpy(buffer.mData, rawBuffer.baseAddress, copyCount)
                }
            }

            if bytesProvided < bytesRequested {
                Logger.debug("Partial Silence: queue starved mid-callback.")
                wasSilenceLastTime = true
            }
            else {
                wasSilenceLastTime = false
            }
            isSilence.pointee = (wasSilenceLastTime == true) ? true : false
            return noErr
        }
    }

    private func applyFadeIn(to buffer: inout [Int16], fadeLength: Int) {
        let length = min(fadeLength, buffer.count)

        // Raised cosine (smooth) fade-in curve
        for i in 0..<length {
            let fadeFactor = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(length)))
            let original = buffer[i]
            let adjustedSample = Int16(Float(original) * fadeFactor)
            
            buffer[i] = adjustedSample
        }
    }

    private func crossfadeAudioData(oldData: Data, newData: Data, crossfadeSamples: Int) -> Data? {
        // Ensure both oldData and newData are at least crossfadeSamples*2 bytes (for 16-bit samples)
        let bytesPerSample = 2
        let crossfadeBytes = crossfadeSamples * bytesPerSample

        guard oldData.count >= crossfadeBytes,
              newData.count >= crossfadeBytes else {
            return nil
        }

        // Convert to Int16 arrays
        let oldSamples = oldData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Int16] in
            Array(UnsafeBufferPointer(start: ptr.bindMemory(to: Int16.self).baseAddress!,
                                      count: oldData.count / bytesPerSample))
        }

        let newSamples = newData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> [Int16] in
            Array(UnsafeBufferPointer(start: ptr.bindMemory(to: Int16.self).baseAddress!,
                                      count: newData.count / bytesPerSample))
        }

        // Prepare output
        // We'll take oldSamples except its last crossfadeSamples, then add crossfaded samples, then the rest of newSamples after crossfade.
        let oldTailStart = oldSamples.count - crossfadeSamples
        let oldHead = Array(oldSamples[..<oldTailStart])
        let oldTail = Array(oldSamples[oldTailStart...]) // last crossfadeSamples
        let newHead = Array(newSamples[..<crossfadeSamples])
        let newTail = Array(newSamples[crossfadeSamples...])

        // Crossfade
        var crossfadedPortion = [Int16](repeating: 0, count: crossfadeSamples)
        for i in 0..<crossfadeSamples {
            let fadeOutFactor = Float(crossfadeSamples - i) / Float(crossfadeSamples)  // goes 1.0 -> 0.0
            let fadeInFactor = Float(i) / Float(crossfadeSamples)                      // goes 0.0 -> 1.0

            let oldVal = Float(oldTail[i])
            let newVal = Float(newHead[i])

            let mixed = oldVal * fadeOutFactor + newVal * fadeInFactor
            crossfadedPortion[i] = Int16(mixed)
        }

        // Combine: oldHead + crossfadedPortion + newTail
        let combinedSamples = oldHead + crossfadedPortion + newTail

        // Convert back to Data
        let combinedData = combinedSamples.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }

        return combinedData
    }
}
