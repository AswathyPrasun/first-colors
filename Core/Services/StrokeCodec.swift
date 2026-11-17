import Foundation

enum StrokeCodecError: Error, Equatable {
    case badMagic
    case unsupportedVersion(UInt16)
    case truncated
    case decompressionFailed
}

/// Compact binary format for `<itemId>.strokes`, LZFSE-compressed (CLAUDE.md §8).
///
/// Layout (little endian), before compression:
/// ```
/// "KCS1"                    magic (4 bytes)
/// UInt16 version            currently 1
/// UInt32 strokeCount
/// per stroke:
///   16 bytes  UUID
///   UInt16    regionId byte length, then UTF-8 bytes
///   UInt32    color 0x00RRGGBB
///   Float32   width
///   UInt32    pointCount, then pointCount × (Float32 x, Float32 y) in drawing coordinates
/// ```
enum StrokeCodec {
    static let version: UInt16 = 1
    private static let magic: [UInt8] = Array("KCS1".utf8)
    /// Guards against absurd counts in a corrupt file before allocating.
    private static let maxPointsPerStroke = 1_000_000

    // MARK: Public

    static func encodeCompressed(_ strokes: [Stroke]) throws -> Data {
        let raw = encode(strokes)
        return try (raw as NSData).compressed(using: .lzfse) as Data
    }

    static func decodeCompressed(_ data: Data) throws -> [Stroke] {
        guard let raw = try? (data as NSData).decompressed(using: .lzfse) as Data else {
            throw StrokeCodecError.decompressionFailed
        }
        return try decode(raw)
    }

    static func encode(_ strokes: [Stroke]) -> Data {
        var out = Data()
        out.reserveCapacity(10 + strokes.reduce(0) { $0 + 40 + $1.regionId.utf8.count + $1.points.count * 8 })
        out.append(contentsOf: magic)
        append(version, to: &out)
        append(UInt32(strokes.count), to: &out)
        for stroke in strokes {
            withUnsafeBytes(of: stroke.id.uuid) { out.append(contentsOf: $0) }
            let region = Array(stroke.regionId.utf8.prefix(Int(UInt16.max)))
            append(UInt16(region.count), to: &out)
            out.append(contentsOf: region)
            append(HexColor.parse(stroke.color) ?? 0, to: &out)
            append(stroke.width.bitPattern, to: &out)
            append(UInt32(stroke.points.count), to: &out)
            for point in stroke.points {
                append(point.x.bitPattern, to: &out)
                append(point.y.bitPattern, to: &out)
            }
        }
        return out
    }

    /// Strict: any inconsistency throws, and the caller treats the file as empty.
    static func decode(_ data: Data) throws -> [Stroke] {
        var reader = Reader(bytes: [UInt8](data))
        guard try reader.bytes(4) == magic else { throw StrokeCodecError.badMagic }
        let fileVersion: UInt16 = try reader.integer()
        guard fileVersion == version else { throw StrokeCodecError.unsupportedVersion(fileVersion) }
        let count: UInt32 = try reader.integer()
        var strokes: [Stroke] = []
        strokes.reserveCapacity(min(Int(count), 100_000))
        for _ in 0..<count {
            let uuidBytes = try reader.bytes(16)
            let uuid = UUID(uuid: (uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                                   uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                                   uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                                   uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]))
            let regionLength: UInt16 = try reader.integer()
            guard let regionId = String(bytes: try reader.bytes(Int(regionLength)), encoding: .utf8) else {
                throw StrokeCodecError.truncated
            }
            let rgb: UInt32 = try reader.integer()
            let width = Float(bitPattern: try reader.integer())
            let pointCount: UInt32 = try reader.integer()
            guard pointCount <= maxPointsPerStroke, reader.remaining >= Int(pointCount) * 8 else {
                throw StrokeCodecError.truncated
            }
            var points: [StrokePoint] = []
            points.reserveCapacity(Int(pointCount))
            for _ in 0..<pointCount {
                let x = Float(bitPattern: try reader.integer())
                let y = Float(bitPattern: try reader.integer())
                guard x.isFinite, y.isFinite else { throw StrokeCodecError.truncated }
                points.append(StrokePoint(x: x, y: y))
            }
            guard width.isFinite, width > 0 else { throw StrokeCodecError.truncated }
            strokes.append(Stroke(id: uuid, regionId: regionId,
                                  color: String(format: "#%06X", rgb & 0xFFFFFF),
                                  width: width, points: points))
        }
        return strokes
    }

    // MARK: Private

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private struct Reader {
        let bytes: [UInt8]
        var offset = 0

        var remaining: Int { bytes.count - offset }

        mutating func bytes(_ count: Int) throws -> [UInt8] {
            guard count >= 0, remaining >= count else { throw StrokeCodecError.truncated }
            defer { offset += count }
            return Array(bytes[offset..<(offset + count)])
        }

        mutating func integer<T: FixedWidthInteger>() throws -> T {
            let size = MemoryLayout<T>.size
            guard remaining >= size else { throw StrokeCodecError.truncated }
            var value: T = 0
            for index in 0..<size {
                value |= T(bytes[offset + index]) << (8 * index)
            }
            offset += size
            return value
        }
    }
}
