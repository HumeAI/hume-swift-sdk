//
//  Data+Additions.swift
//  HumeAI
//
//  Created by Chris on 4/2/25.
//

import Foundation

extension Data {
    /// Attempts to pretty-print the Data as a JSON string.
    var prettyPrintedJSONString: String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: self, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            print("Failed to pretty-print JSON: \(error)")
            return nil
        }
    }
}

extension Data {
    func parseWAVHeader() -> WAVHeader? {
        guard count >= 44 else { return nil }
        
        func readString(_ offset: Int, _ length: Int) -> String {
            let subdata = subdata(in: offset..<offset+length)
            return String(decoding: subdata, as: UTF8.self)
        }
        
        func readUInt16(_ offset: Int) -> UInt16 {
            return subdata(in: offset..<offset+2).withUnsafeBytes { $0.load(as: UInt16.self) }
        }
        
        func readUInt32(_ offset: Int) -> UInt32 {
            return subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
        }
        
        return WAVHeader(
            chunkID: readString(0, 4),
            format: readString(8, 4),
            subchunk1ID: readString(12, 4),
            audioFormat: readUInt16(20),
            numChannels: readUInt16(22),
            sampleRate: readUInt32(24),
            byteRate: readUInt32(28),
            blockAlign: readUInt16(32),
            bitsPerSample: readUInt16(34)
        )
    }
}
