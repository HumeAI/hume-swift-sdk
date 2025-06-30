//
//  MeteredAudioSourceNode.swift
//  HumeAI
//
//  Created by Chris on 1/21/25.
//

import AVFoundation

class MeteredAudioSourceNode {
    var sourceNode: AVAudioSourceNode!
    var meterListener: ((Float) -> Void)?
    private var meterTable: [Float] = []
    private let meterUpdateQueue = DispatchQueue(label: "\(Constants.Namespace).audioOutput.metering", qos: .userInteractive)
    
    var isMetering = true
    
    init(format: AVAudioFormat, renderBlock: @escaping AVAudioSourceNodeRenderBlock) {
        // Create source node with metering render block
        sourceNode = AVAudioSourceNode(format: format) { [weak self] (isSilence, timestamp, frameCount, outputBuffer) -> OSStatus in
            // Your existing render block logic
            let result = renderBlock(isSilence, timestamp, frameCount, outputBuffer)
            
            // Metering logic
            self?.calculateMeters(outputBuffer: outputBuffer, frameCount: frameCount)
            
            return result
        }
    }
    
    private func calculateMeters(outputBuffer: UnsafeMutablePointer<AudioBufferList>, frameCount: AVAudioFrameCount) {
        guard isMetering else { return }
        meterUpdateQueue.sync { [weak self] in
            guard let self = self else { return }
            
            let bufferList = UnsafeMutableAudioBufferListPointer(outputBuffer)
            var peakLevel: Float = 0
            
            for buffer in bufferList {
                guard let audioBuffer = buffer.mData else { continue }
                
                let samples = audioBuffer.bindMemory(to: Float.self, capacity: Int(frameCount))
                
                // Calculate peak level
                let absoluteSamples = (0..<Int(frameCount)).map { abs(samples[$0]) }
                let bufferPeak = absoluteSamples.max() ?? 0
                
                peakLevel = max(peakLevel, bufferPeak)
            }
            
            // Convert to decibels
            let decibelLevel = peakLevel > 0 ? 20 * log10(peakLevel) : -Float.infinity
            
            if meterTable.count > 10 && decibelLevel < 0 &&
                meterTable[meterTable.count - 10 ..< meterTable.count - 1].filter({ $0 > 0 }).isEmpty {
                return
            }
            // Update meter table or notify observers
            self.updateMeterTable(peakLevel: peakLevel, decibelLevel: decibelLevel)
            meterListener?(getCurrentMeterLevels().decibels)
        }
    }
    
    private func updateMeterTable(peakLevel: Float, decibelLevel: Float) {
        // Thread-safe meter table update
        meterUpdateQueue.async { [weak self] in
            guard let self else { return }
            // Store or process meter levels
            self.meterTable.append(peakLevel)
            
            // Optional: Limit historical meter readings
            if self.meterTable.count > 100 {
                self.meterTable.removeFirst()
            }
        }
    }
    
    func getCurrentMeterLevels() -> (peak: Float, decibels: Float) {
        guard !meterTable.isEmpty else { return (0, -Float.infinity) }
        
        let currentPeak = meterTable.last!
        let currentDecibels = currentPeak > 0 ? 20 * log10(currentPeak) : -Float.infinity
        
        return (currentPeak, currentDecibels)
    }
}
