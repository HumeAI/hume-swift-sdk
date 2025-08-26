import AVFoundation

public enum MicrophoneError: Error {
  case configuration(Error)
  case audioConversionConfiguration
  case audioConversion(Error?)
  case engineStartFailure(Error)
  case bufferSizeTooSmall
}

public typealias MicrophoneDataChunkBlock = (Data, Float) async -> Void

internal final actor Microphone: NSObject {
  private let micConfig: MicConfig

  private var audioEngine: AVAudioEngine
  private var inputNode: AVAudioInputNode!
  var sinkNode: AVAudioSinkNode!

  private var resampler: Resampler?
  private var isPaused = false
  private let audioBufferProcessor = AudioBufferProcessor()
  private var lastSourceFormat: AVAudioFormat?

  var onChunk: MicrophoneDataChunkBlock = { _, _ in }
  var isMuted: Bool = false

  init(
    audioEngine: AVAudioEngine, sampleRate: Double, sampleSize: Int,
    audioFormat: AudioFormat? = nil,
    onChunk: @escaping MicrophoneDataChunkBlock
  ) throws {
    self.audioEngine = audioEngine
    micConfig = MicConfig(
      sampleRate: sampleRate, sampleSize: sampleSize,
      audioFormat: audioFormat ?? Constants.DefaultAudioFormat,
      channelCount: Constants.InputChannels)

    inputNode = audioEngine.inputNode
    self.onChunk = onChunk

    super.init()

    sinkNode = AVAudioSinkNode(receiverBlock: audioSinkNodeReceiverCallback)
  }

  // MARK: - Configuration

  /// Configures the resampler. This should be called after attaching and connecting the sink node to the engine
  func configureResampler() throws {
    isPaused = true
    Logger.info("Configuring resampler")

    // initialize audio engine and nodes
    let inputFormat = inputNode.outputFormat(forBus: 0)
    guard resamplerSourceFormatChanged(comparedTo: inputFormat) else {
      Logger.info("Input format unchanged, skipping reconfiguration")
      return
    }

    // sink node to listen for realtime input

    // configure resampler
    let desiredFormat = try micConfig.avAudioFormat(channelLayout: inputFormat.channelLayout)
    resampler = Resampler(
      sourceFormat: inputFormat,
      destinationFormat: desiredFormat,
      sampleSize: AVAudioFrameCount(micConfig.sampleSize))
    self.lastSourceFormat = inputFormat

    Logger.info("Resampler complete")
    isPaused = false
  }

  // MARK: - Interface

  public func mute() {
    isMuted = true
  }

  public func unmute() {
    isMuted = false
  }

  // MARK: - Private

  private func resamplerSourceFormatChanged(comparedTo fmt: AVAudioFormat) -> Bool {
    guard let last = lastSourceFormat else { return true }
    return last.sampleRate != fmt.sampleRate || last.channelCount != fmt.channelCount
  }

  private func audioSinkNodeReceiverCallback(
    timestamp: UnsafePointer<AudioTimeStamp>,
    frameCount: AVAudioFrameCount,
    audioBufferList: UnsafePointer<AudioBufferList>
  ) -> OSStatus {
    guard let resampler, !isPaused else {
      Logger.warn("waiting for resampler to be configured")
      return kAudioComponentErr_NotPermitted
    }
    do {
      // Resample and convert to PCM Int16
      let outputBuffer = try resampler.resample(
        inputBufferList: audioBufferList, frameCount: frameCount)

      // Pass the converted data to the buffer processor
      AudioBufferProcessor.process(buffer: outputBuffer, isMuted: isMuted, handler: onChunk)
    } catch {
      Logger.error("Resampling failed: \(error.localizedDescription)")
      return kAudioComponentErr_InvalidFormat
    }

    return noErr
  }
}

// MARK: - Mic Config

extension Microphone {
  fileprivate struct MicConfig {
    let sampleRate: Double
    let sampleSize: Int
    let audioFormat: AudioFormat
    let channelCount: Int

    func avAudioFormat(channelLayout: AVAudioChannelLayout?) throws -> AVAudioFormat {
      if let channelLayout {
        return AVAudioFormat(
          commonFormat: self.audioFormat.commonFormat,
          sampleRate: self.sampleRate,
          interleaved: false,
          channelLayout: channelLayout
        )
      } else {
        let desiredFormat = AVAudioFormat(
          commonFormat: audioFormat.commonFormat,
          sampleRate: self.sampleRate,
          channels: AVAudioChannelCount(self.channelCount),
          interleaved: false
        )

        guard let desiredFormat = desiredFormat else {
          throw MicrophoneError.audioConversionConfiguration
        }
        return desiredFormat
      }
    }
  }

}
