import Compression
import Foundation

enum ZipError: Error, Equatable {
    case notAZip
    case corrupt(String)
    case unsupported(String)
    case tooLarge
}

/// Minimal ZIP support for backups (no third-party code, CLAUDE.md §10).
///
/// - Writing: "stored" entries (our data is already compressed: LZFSE strokes, PNG thumbnails).
/// - Reading: stored and deflate entries, CRC-checked, with size limits so a hostile or
///   damaged file can't exhaust memory. No ZIP64, encryption or multi-disk archives.
enum ZipArchive {
    struct Entry: Equatable {
        let path: String
        let data: Data
    }

    static let maxEntries = 20_000
    static let maxTotalBytes = 512 * 1024 * 1024

    // MARK: Writing

    static func write(_ entries: [Entry], date: Date = Date()) throws -> Data {
        guard entries.count <= maxEntries else { throw ZipError.tooLarge }
        let (dosTime, dosDate) = dosDateTime(date)
        var out = Data()
        var central = Data()
        for entry in entries {
            let name = Data(entry.path.utf8)
            guard name.count <= UInt16.max, entry.data.count < Int(UInt32.max), out.count < Int(UInt32.max) else {
                throw ZipError.tooLarge
            }
            let offset = UInt32(out.count)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)

            out.append(le32: 0x0403_4B50)
            out.append(le16: 20)            // version needed
            out.append(le16: 0x0800)        // UTF-8 names
            out.append(le16: 0)             // stored
            out.append(le16: dosTime)
            out.append(le16: dosDate)
            out.append(le32: crc)
            out.append(le32: size)
            out.append(le32: size)
            out.append(le16: UInt16(name.count))
            out.append(le16: 0)
            out.append(name)
            out.append(entry.data)

            central.append(le32: 0x0201_4B50)
            central.append(le16: 20)        // version made by
            central.append(le16: 20)
            central.append(le16: 0x0800)
            central.append(le16: 0)
            central.append(le16: dosTime)
            central.append(le16: dosDate)
            central.append(le32: crc)
            central.append(le32: size)
            central.append(le32: size)
            central.append(le16: UInt16(name.count))
            central.append(le16: 0)         // extra
            central.append(le16: 0)         // comment
            central.append(le16: 0)         // disk
            central.append(le16: 0)         // internal attributes
            central.append(le32: 0)         // external attributes
            central.append(le32: offset)
            central.append(name)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        out.append(le32: 0x0605_4B50)
        out.append(le16: 0)
        out.append(le16: 0)
        out.append(le16: UInt16(entries.count))
        out.append(le16: UInt16(entries.count))
        out.append(le32: UInt32(central.count))
        out.append(le32: centralOffset)
        out.append(le16: 0)
        return out
    }

    // MARK: Reading

    static func read(_ data: Data) throws -> [Entry] {
        let bytes = [UInt8](data)
        guard bytes.count >= 22 else { throw ZipError.notAZip }

        // End of central directory: scan back over a possible trailing comment.
        var eocd = -1
        var index = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 65_535)
        while index >= lowest {
            if le32(bytes, index) == 0x0605_4B50 { eocd = index; break }
            index -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }
        let count = Int(le16(bytes, eocd + 10))
        let centralSize = Int(le32(bytes, eocd + 12))
        let centralOffset = Int(le32(bytes, eocd + 16))
        guard count <= maxEntries else { throw ZipError.tooLarge }
        guard centralOffset >= 0, centralOffset + centralSize <= eocd else { throw ZipError.corrupt("central directory") }

        var entries: [Entry] = []
        var total = 0
        var cursor = centralOffset
        for _ in 0..<count {
            guard cursor + 46 <= bytes.count, le32(bytes, cursor) == 0x0201_4B50 else {
                throw ZipError.corrupt("central entry")
            }
            let flags = le16(bytes, cursor + 8)
            let method = le16(bytes, cursor + 10)
            let crc = le32(bytes, cursor + 16)
            let compressedSize = Int(le32(bytes, cursor + 20))
            let size = Int(le32(bytes, cursor + 24))
            let nameLength = Int(le16(bytes, cursor + 28))
            let extraLength = Int(le16(bytes, cursor + 30))
            let commentLength = Int(le16(bytes, cursor + 32))
            let localOffset = Int(le32(bytes, cursor + 42))
            guard cursor + 46 + nameLength <= bytes.count,
                  let path = String(bytes: bytes[(cursor + 46)..<(cursor + 46 + nameLength)], encoding: .utf8) else {
                throw ZipError.corrupt("name")
            }
            cursor += 46 + nameLength + extraLength + commentLength

            guard flags & 0x1 == 0 else { throw ZipError.unsupported("encrypted") }
            total += size
            guard total <= maxTotalBytes else { throw ZipError.tooLarge }
            if path.hasSuffix("/") { continue }   // directory entry

            guard localOffset + 30 <= bytes.count, le32(bytes, localOffset) == 0x0403_4B50 else {
                throw ZipError.corrupt("local header")
            }
            let start = localOffset + 30 + Int(le16(bytes, localOffset + 26)) + Int(le16(bytes, localOffset + 28))
            guard start + compressedSize <= bytes.count else { throw ZipError.corrupt("data") }
            let raw = Data(bytes[start..<(start + compressedSize)])

            let content: Data
            switch method {
            case 0:
                content = raw
            case 8:
                content = try inflate(raw, expectedSize: size)
            default:
                throw ZipError.unsupported("method \(method)")
            }
            guard content.count == size, CRC32.checksum(content) == crc else { throw ZipError.corrupt("checksum \(path)") }
            entries.append(Entry(path: path, data: content))
        }
        return entries
    }

    // MARK: Helpers

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { (out: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (input: UnsafeRawBufferPointer) -> Int in
                guard let dst = out.bindMemory(to: UInt8.self).baseAddress,
                      let src = input.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                // COMPRESSION_ZLIB is raw DEFLATE (RFC 1951), which is what ZIP uses.
                return compression_decode_buffer(dst, expectedSize, src, data.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt("deflate") }
        return output
    }

    private static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        let year = max(1980, c.year ?? 1980)
        let time = UInt16(((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2))
        let day = UInt16(((year - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1))
        return (time, day)
    }

    private static func le16(_ b: [UInt8], _ i: Int) -> UInt16 {
        guard i + 1 < b.count else { return 0 }
        return UInt16(b[i]) | UInt16(b[i + 1]) << 8
    }

    private static func le32(_ b: [UInt8], _ i: Int) -> UInt32 {
        guard i + 3 < b.count else { return 0 }
        return UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        data.withUnsafeBytes { buffer in
            for byte in buffer { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func append(le16 value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(le32 value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
