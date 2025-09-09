//
//  DataAdditionsTest.swift
//  Hume
//

import Foundation
import Testing

@testable import Hume

struct DataAdditionsTest {
  #if os(iOS)
    @Test func parseWAVHeader_parses_minimal_valid_header_and_maps_to_avformat() async throws {
      // Arrange: Build 44-byte RIFF/WAVE header (little-endian) matching WAVHeader expectations
      // Fields we care about: chunkID "RIFF", format "WAVE", subchunk1ID "fmt ",
      // audioFormat=1 (PCM), numChannels=2, sampleRate=48000, byteRate, blockAlign, bitsPerSample=16
      var bytes = [UInt8](repeating: 0, count: 44)

      func putString(_ s: String, at offset: Int) {
        let data = s.data(using: .ascii)!
        for (i, b) in data.enumerated() { bytes[offset + i] = b }
      }
      func putUInt16(_ v: UInt16, at offset: Int) {
        let le = withUnsafeBytes(of: v.littleEndian) { Array($0) }
        bytes[offset] = le[0]; bytes[offset + 1] = le[1]
      }
      func putUInt32(_ v: UInt32, at offset: Int) {
        let le = withUnsafeBytes(of: v.littleEndian) { Array($0) }
        bytes[offset] = le[0]; bytes[offset + 1] = le[1]; bytes[offset + 2] = le[2]; bytes[offset + 3] = le[3]
      }

      // RIFF header
      putString("RIFF", at: 0)
      putUInt32(36, at: 4) // chunk size (unused by parser)
      putString("WAVE", at: 8)
      // fmt subchunk
      putString("fmt ", at: 12)
      putUInt32(16, at: 16) // subchunk1 size (PCM)
      putUInt16(1, at: 20) // audioFormat = PCM
      putUInt16(2, at: 22) // numChannels = 2
      putUInt32(48000, at: 24) // sampleRate
      putUInt32(48000 * 2 * 16 / 8, at: 28) // byteRate = sampleRate * channels * blitsPerSample/8
      putUInt16(2 * 16 / 8, at: 32) // blockAlign = channels * bitsPerSample/8
      putUInt16(16, at: 34) // bitsPerSample
      // data subchunk header (not read by parser but include to make header realistic)
      putString("data", at: 36)
      putUInt32(0, at: 40)

      let data = Data(bytes)

      // Act
      let header = data.parseWAVHeader()

      // Assert header parsed
      #expect(header != nil)
      #expect(header!.isValid)

      // Verify fields and mapping to AVAudioFormat
      let asFormat = header!.asAVAudioFormat
      #expect(asFormat != nil)
      #expect(asFormat!.sampleRate == 48000)
      #expect(asFormat!.channelCount == 2)
    }
  #endif
}
