import AVFoundation

public enum MicrophoneError: Error {
  case configuration(Error)
  case audioConversionConfiguration
  case audioConversion(Error?)
  case engineStartFailure(Error)
  case bufferSizeTooSmall
}

public typealias MicrophoneDataChunkBlock = (Data, Float) async -> Void

internal final class Microphone: NSObject {
  private let micConfig: MicConfig

  private var audioEngine: AVAudioEngine
  private var inputNode: AVAudioInputNode!
  var inputFormat: AVAudioFormat!
  var sinkNode: AVAudioSinkNode!

  private var resampler: Resampler!
  private let audioBufferProcessor = AudioBufferProcessor()

  var onChunk: MicrophoneDataChunkBlock = { _, _ in }
  var isMuted: Bool = false

  init(
    audioEngine: AVAudioEngine, sampleRate: Double, sampleSize: Int, audioFormat: AudioFormat? = nil
  ) throws {
    self.audioEngine = audioEngine
    micConfig = MicConfig(
      sampleRate: sampleRate, sampleSize: sampleSize,
      audioFormat: audioFormat ?? Constants.DefaultAudioFormat,
      channelCount: Constants.InputChannels)
    super.init()
    try configureInput()
  }

  // MARK: - Configuration

  func configureInput() throws {
    Logger.info("Configuring microphone")

    // initialize audio engine and nodes
    inputNode = audioEngine.inputNode
    inputFormat = inputNode.outputFormat(forBus: 0)
    let outputNode = audioEngine.outputNode

    // sink node to listen for realtime input
    sinkNode = AVAudioSinkNode(receiverBlock: audioSinkNodeReceiverCallback)

    // configure resampler
    let desiredFormat = try micConfig.avAudioFormat(channelLayout: inputFormat.channelLayout)
    resampler = Resampler(
      sourceFormat: inputFormat, destinationFormat: desiredFormat,
      sampleSize: AVAudioFrameCount(micConfig.sampleSize))

    Logger.info("Mic configuration complete")
  }

  // MARK: - Interface

  public func mute() {
    isMuted = true
  }

  public func unmute() {
    isMuted = false
  }

  // MARK: - Private

  private func audioSinkNodeReceiverCallback(
    timestamp: UnsafePointer<AudioTimeStamp>,
    frameCount: AVAudioFrameCount,
    audioBufferList: UnsafePointer<AudioBufferList>
  ) -> OSStatus {
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
