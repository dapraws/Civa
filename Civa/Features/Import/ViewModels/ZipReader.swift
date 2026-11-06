//
//  ZipReader.swift
//  Civa
//
//  Created by Muhammad Darrel Prawira on 06/11/26.
//

import Compression
import Foundation

/// Reads files out of a ZIP archive, such as LinkedIn's data export. Foundation has no public
/// unzip, so this reads the archive's directory and inflates entries with the Compression framework.
// ponytail: stored and deflate entries only, no ZIP64 or encryption; LinkedIn exports need neither.
nonisolated enum ZipReader {
    enum Failure: Error, Equatable {
        case notZip, unsupported
    }

    /// The files whose paths pass `wanted`, keyed by path inside the archive.
    static func files(in data: Data, where wanted: (String) -> Bool) throws -> [String: Data] {
        let bytes = [UInt8](data)
        func u16(_ offset: Int) -> Int { Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 }
        func u32(_ offset: Int) -> Int { u16(offset) | u16(offset + 2) << 16 }

        // The end-of-directory record sits in the last 64 KB (it may be followed by a comment).
        guard bytes.count >= 22 else { throw Failure.notZip }
        let lowest = max(0, bytes.count - 22 - 65_535)
        guard let end = stride(from: bytes.count - 22, through: lowest, by: -1).first(where: { u32($0) == 0x0605_4B50 })
        else { throw Failure.notZip }

        let count = u16(end + 10)
        var entry = u32(end + 16)
        guard count != 0xFFFF, entry != 0xFFFF_FFFF else { throw Failure.unsupported }  // ZIP64

        var files: [String: Data] = [:]
        for _ in 0..<count {
            guard entry + 46 <= bytes.count, u32(entry) == 0x0201_4B50 else { throw Failure.notZip }
            let method = u16(entry + 10)
            let compressedSize = u32(entry + 20)
            let size = u32(entry + 24)
            let nameLength = u16(entry + 28)
            let extraLength = u16(entry + 30)
            let commentLength = u16(entry + 32)
            let header = u32(entry + 42)
            let name = String(decoding: bytes[(entry + 46)..<(entry + 46 + nameLength)], as: UTF8.self)
            entry += 46 + nameLength + extraLength + commentLength

            guard !name.hasSuffix("/"), wanted(name) else { continue }
            guard header + 30 <= bytes.count, u32(header) == 0x0403_4B50 else { throw Failure.notZip }
            let start = header + 30 + u16(header + 26) + u16(header + 28)
            guard start + compressedSize <= bytes.count else { throw Failure.notZip }
            let stored = Array(bytes[start..<(start + compressedSize)])

            switch method {
            case 0:
                files[name] = Data(stored)
            case 8:
                files[name] = try inflate(stored, size: size)
            default:
                throw Failure.unsupported
            }
        }
        return files
    }

    /// Raw DEFLATE, which is what ZIP stores and what `COMPRESSION_ZLIB` decodes.
    private static func inflate(_ input: [UInt8], size: Int) throws -> Data {
        guard size > 0 else { return Data() }
        var output = [UInt8](repeating: 0, count: size)
        let written = compression_decode_buffer(&output, size, input, input.count, nil, COMPRESSION_ZLIB)
        guard written == size else { throw Failure.unsupported }
        return Data(output)
    }
}
