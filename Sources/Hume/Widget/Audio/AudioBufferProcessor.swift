#if HUME_IOS
  //
  //  AudioBufferProcessor.swift
  //  HumeAI2
  //
  //  Created by Chris on 12/17/24.
  //

  import AVFoundation
  import Accelerate

  class AudioBufferProcessor {
    internal var meteringEnabled: Bool = false

    private let queue = DispatchQueue(
      label: "\(Constants.Namespace).audioBufferProcessor", qos: .userInteractive)

    func process(
      buffer: AVAudioPCMBuffer, isMuted: Bool, handler: @escaping MicrophoneDataChunkBlock
    ) {
      queue.async { [weak self] in
        Task {
          let bufferList = buffer.audioBufferList
          let audioBuffer = bufferList.pointee.mBuffers
          guard let mData = audioBuffer.mData else {
            Logger.error("AudioBuffer missing data")
            return
          }
          let dataSize = Int(audioBuffer.mDataByteSize)
          let data = Data(bytes: mData, count: dataSize)

          if !isMuted {
            // Optional: Calculate average power if needed
            let avgPower: Float = self?.averagePower(buffer: buffer) ?? 0
            await handler(data, avgPower)
          } else {
            // Create a zero-filled array for simulated silence
            let emptyData = Data(count: dataSize)
            await handler(emptyData, 0.0)
          }
        }
      }
    }

    /// Computes average power (RMS amplitude in 0...1) across all channels in the buffer.
    /// - Note: For signed PCM formats, samples are expected in [-1, 1] (Float32) or [-32768, 32767] (Int16).
    func averagePower(buffer: AVAudioPCMBuffer) -> Float {
      guard meteringEnabled else { return 0 }
      let format = buffer.format
      let channels = Int(format.channelCount)
      let frames = Int(buffer.frameLength)
      guard channels > 0, frames > 0 else { return 0 }

      // Helper to clamp to 0...1
      @inline(__always)
      func clamp01(_ x: Float) -> Float { max(0, min(1, x)) }

      switch format.commonFormat {
      case .pcmFormatFloat32:
        // Handle both non-interleaved and interleaved Float32
        if let channelData = buffer.floatChannelData {
          // Non-interleaved: channelData[ch] points to contiguous frames for that channel
          var accum: Float = 0
          for ch in 0..<channels {
            let ptr = channelData[ch]
            var rms: Float = 0
            vDSP_rmsqv(ptr, 1, &rms, vDSP_Length(frames))
            accum += rms * rms  // accumulate mean-square to combine later
          }
          // Average mean-square across channels, then sqrt
          let meanSquare = accum / Float(channels)
          let rmsAll = sqrtf(meanSquare)
          return clamp01(rmsAll)
        } else {
          // Interleaved Float32: single buffer with channels interleaved
          let audioBuffer = buffer.audioBufferList.pointee.mBuffers
          guard let mData = audioBuffer.mData else { return 0 }
          let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Float>.size
          let ptr = mData.bindMemory(to: Float.self, capacity: sampleCount)

          // Compute RMS across all samples directly
          var rms: Float = 0
          vDSP_rmsqv(ptr, 1, &rms, vDSP_Length(sampleCount))
          return clamp01(rms)
        }

      case .pcmFormatInt16:
        // Handle both non-interleaved and interleaved Int16
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData else { return 0 }
        let sampleCount = Int(audioBuffer.mDataByteSize) / MemoryLayout<Int16>.size
        let int16Ptr = mData.bindMemory(to: Int16.self, capacity: sampleCount)

        // Convert to Float in [-1, 1] and compute RMS
        var rms: Float = 0
        // Scale factor to map Int16 [-32768, 32767] to [-1, 1]
        let scale: Float = 1.0 / 32768.0
        // vDSP has a convenience to compute RMS on integer with scaling: convert to Float then RMS
        // Allocate a temporary buffer for conversion
        var temp = [Float](repeating: 0, count: sampleCount)
        vDSP.convertElements(
          of: UnsafeBufferPointer(start: int16Ptr, count: sampleCount), to: &temp)
        vDSP.multiply(scale, temp, result: &temp)  // normalize
        vDSP_rmsqv(temp, 1, &rms, vDSP_Length(sampleCount))
        let clamped = clamp01(rms)
        return clamped

      default:
        // Unsupported formats fall back to 0
        return 0
      }
    }

  }
#endif
