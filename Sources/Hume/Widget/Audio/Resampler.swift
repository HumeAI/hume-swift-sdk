#if HUME_WIDGET
  //
  //  Resampler.swift
  //  HumeAI2
  //
  //  Source code adapted from https://developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions#Creating-a-protocol-for-providing-samples
  //

  import AVFoundation
  import Accelerate

  enum ResamplerError: Error {
    case conversionFailed(Error?)
    case inputBufferFailure
    case outputBufferMissingFloatChannelData
    case outputBufferFailure
    case quantizationFailure
  }

  /// A utility class for resampling and converting audio data between different sample rates and formats.
  ///
  /// The `Resampler` class uses the `AVAudioConverter` API to perform sample rate conversion. It supports applying dithering during the
  /// quantization process to reduce harmonic distortion and improve perceived audio quality when downsizing the bit depth.
  class Resampler {
    let sampleRateConverter: AVAudioConverter
    let sourceFormat: AVAudioFormat
    let destinationFormat: AVAudioFormat
    private let outputBuffer: AVAudioPCMBuffer

    /// Initializes a new `Resampler` instance with the given source and destination audio formats.
    ///
    /// - Parameters:
    ///   - sourceFormat: The format of the input audio.
    ///   - destinationFormat: The desired output audio format.
    ///   - sampleSize: The number of audio frames to process per conversion cycle.
    init(
      sourceFormat: AVAudioFormat, destinationFormat: AVAudioFormat, sampleSize: AVAudioFrameCount
    ) {
      self.sourceFormat = sourceFormat
      self.destinationFormat = destinationFormat

      self.outputBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: sampleSize)!
      self.sampleRateConverter = AVAudioConverter(from: sourceFormat, to: destinationFormat)!
      // min phase is best for low latency and preserves enough voice quality
      sampleRateConverter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_MinimumPhase
      sampleRateConverter.sampleRateConverterQuality = AVAudioQuality.medium.rawValue

      Logger.debug("Resampler initialized")
      Logger.debug("- Sample size: \(sampleSize)")
      Logger.debug("- Source format\n\(sourceFormat.prettyPrinted)")
      Logger.debug("- Destination format\n\(destinationFormat.prettyPrinted)")
    }

    /// Resamples the input `AudioBufferList` and writes the result to the provided output buffer.
    func resample(inputBufferList: UnsafePointer<AudioBufferList>, frameCount: AVAudioFrameCount)
      throws -> AVAudioPCMBuffer
    {
      guard
        let inputBuffer = AVAudioPCMBuffer(
          pcmFormat: sourceFormat, bufferListNoCopy: inputBufferList)
      else {
        throw ResamplerError.inputBufferFailure
      }
      inputBuffer.frameLength = frameCount

      var error: NSError?
      let status = sampleRateConverter.convert(to: outputBuffer, error: &error) { _, inputStatus in
        inputStatus.pointee = .haveData
        return inputBuffer
      }

      if status == .error {
        throw ResamplerError.conversionFailed(error)
      }
      return outputBuffer
    }

    /// Resamples the input `AVAudioPCMBuffer` to match the destination format.
    ///
    /// - Parameter inputBuffer: The input audio buffer to be resampled.
    /// - Returns: A new `AVAudioPCMBuffer` containing the resampled audio.
    /// - Throws: A `ResamplerError` if the resampling process fails.
    func resample(inputBuffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
      // Ensure the input buffer matches the source format
      guard inputBuffer.format == sourceFormat else {
        throw ResamplerError.inputBufferFailure
      }

      // Perform the resampling
      var error: NSError?
      let status = sampleRateConverter.convert(to: outputBuffer, error: &error) { _, inputStatus in
        inputStatus.pointee = .haveData
        return inputBuffer
      }

      if status == .error {
        throw ResamplerError.conversionFailed(error)
      }

      return outputBuffer
    }
  }

  // NOTE:
  // Keeping this around for now. Was having issues with bit depth conversions with AVAudioConverter, so
  // i ended up rolling a custom quantized dither solution and just use the audioConverter to do the sample rate
  // conversion, then pass that buffer through the following flow to convert the bit depth. eventually the audio
  // converter's bit depth conversion worked which produces a satisfactory output, but this quantization logic
  // results in higher fidelity. i'm sticking with the audio converter for now cuz this solution assumes
  // input is always 32bit and output is always 16bit, so we'd need robust error and format handling
  // to confidently ship this
  //
  @available(*, deprecated, message: "Manually applied dithering, see note above")
  extension Resampler {

    fileprivate func convertTo16Bit() throws -> AVAudioPCMBuffer {
      guard let floatChannelData = outputBuffer.floatChannelData?[0] else {
        throw ResamplerError.outputBufferMissingFloatChannelData
      }

      let frameLength = Int(outputBuffer.frameLength)
      let floatData = UnsafeBufferPointer(start: floatChannelData, count: frameLength)

      guard
        let int16Buffer = AVAudioPCMBuffer(
          pcmFormat: destinationFormat,
          frameCapacity: outputBuffer.frameCapacity
        )
      else {
        throw ResamplerError.outputBufferFailure
      }

      int16Buffer.frameLength = AVAudioFrameCount(frameLength)

      let int16Data = applyDitheredQuantization(floatData: Array(floatData), ditherAmount: 0.5)
      guard let channelData = int16Buffer.int16ChannelData?[0] else {
        throw ResamplerError.quantizationFailure
      }
      channelData.update(from: int16Data, count: int16Data.count)

      return int16Buffer
    }

    /// Applies dithering and quantization to a buffer of Float samples to produce Int16 samples.
    ///  This method was generated with the help of ChatGPT
    ///
    /// - Parameters:
    ///   - floatData: An array of Float samples in the range [-1.0, 1.0].
    ///   - ditherAmount: The amplitude of the dither. Typically 0.5 for uniform dither to cover half an LSB.
    ///                    This effectively randomizes rounding errors and reduces harmonic distortion.
    /// - Returns: An array of Int16 quantized samples with dithering applied.
    fileprivate func applyDitheredQuantization(floatData: [Float], ditherAmount: Float = 0.5)
      -> [Int16]
    {
      let count = floatData.count
      guard count > 0 else { return [] }

      // Prepare buffers
      var clampedData = [Float](repeating: 0, count: count)
      var scaledData = [Float](repeating: 0, count: count)

      var int16MaxFloat = Float(Int16.max)
      var int16MinFloat = Float(Int16.min)

      // Step 1: Clamp values to [-1.0, 1.0] using vDSP
      var negOne: Float = -1.0
      var posOne: Float = 1.0
      floatData.withUnsafeBufferPointer { srcPtr in
        clampedData.withUnsafeMutableBufferPointer { dstPtr in
          vDSP_vclip(
            srcPtr.baseAddress!, 1,
            &negOne, &posOne,
            dstPtr.baseAddress!, 1,
            vDSP_Length(count))
        }
      }

      // Step 2: Scale from [-1.0, 1.0] to [-32767, 32767]
      clampedData.withUnsafeBufferPointer { srcPtr in
        scaledData.withUnsafeMutableBufferPointer { dstPtr in
          vDSP_vsmul(
            srcPtr.baseAddress!, 1,
            &int16MaxFloat,
            dstPtr.baseAddress!, 1,
            vDSP_Length(count))
        }
      }

      // Step 3: Generate dither and add it to the scaled data
      addDitherToScaledData(scaledData: &scaledData, ditherAmount: ditherAmount)

      // Step 4: Round to nearest integer and store in Int16
      // At this point, values may be in range [-32767.5, 32767.5] due to dithering.
      // Rounding brings them into the Int16 range.
      return convertScaledDataToInt16(
        scaledData: scaledData, int16MinFloat: &int16MinFloat, int16MaxFloat: &int16MaxFloat)
    }

    private func addDitherToScaledData(scaledData: inout [Float], ditherAmount: Float) {
      let count = scaledData.count

      // Step 1: Generate random dither values in the range [-ditherAmount, ditherAmount]
      var dither = [Float](repeating: 0, count: count)

      // Generate random values uniformly distributed in the range [-1, 1] using vDSP_vgen
      let minRange: Float = -1.0
      let maxRange: Float = 1.0
      vDSP_vgen([minRange], [maxRange], &dither, 1, vDSP_Length(count))

      // Scale the dither values to the range [-ditherAmount, ditherAmount]
      vDSP_vsmul(dither, 1, [ditherAmount], &dither, 1, vDSP_Length(count))

      // Step 2: Add the dither to scaledData
      vDSP_vadd(scaledData, 1, dither, 1, &scaledData, 1, vDSP_Length(count))
    }

    private func convertScaledDataToInt16(
      scaledData: [Float], int16MinFloat: inout Float, int16MaxFloat: inout Float
    ) -> [Int16] {
      let count = scaledData.count
      var clampedData = [Float](repeating: 0, count: count)
      var int16Data = [Int16](repeating: 0, count: count)

      // Step 1: Clamp scaledData to [int16MinFloat, int16MaxFloat]
      scaledData.withUnsafeBufferPointer { srcPtr in
        clampedData.withUnsafeMutableBufferPointer { dstPtr in
          vDSP_vclip(
            srcPtr.baseAddress!, 1,
            &int16MinFloat, &int16MaxFloat,
            dstPtr.baseAddress!, 1,
            vDSP_Length(count))
        }
      }

      // Step 2: Convert clamped Float values to Int16 with rounding
      clampedData.withUnsafeBufferPointer { srcPtr in
        int16Data.withUnsafeMutableBufferPointer { dstPtr in
          vDSP_vfixr16(
            srcPtr.baseAddress!, 1,
            dstPtr.baseAddress!, 1,
            vDSP_Length(count))
        }
      }

      return int16Data
    }
  }
#endif
