import Foundation

enum CR3MetadataError: Error {
    case canNotFindCR3MetadataBox
}

/// Writes GPS and date/timezone metadata to CR3 files via in-place binary patching.
///
/// ImageIO has no CR3 encoder, so `CGImageDestinationCreateWithURL` fails for CR3 output.
/// This writer works around that limitation by directly patching the ISOBMFF box structure:
/// - **CMT4** (GPS IFD): rebuilt from scratch with the provided geotag
/// - **CMT2** (EXIF SubIFD): date and timezone ASCII values overwritten in-place
/// - **XMP**: new `rdf:Description` block injected with GPS/date/timezone attributes
///
/// No box sizes are changed, so CTBO/stco offset recalculation is not needed.
public struct CR3MetadataWriter: Sendable, ImageFileWriterProtocol {

    public init() {}

    /// Writes geotag, date, and timezone metadata to a CR3 file.
    ///
    /// Copies the source file to the destination (unless they are the same path),
    /// patches the relevant ISOBMFF metadata boxes, and writes the result atomically.
    ///
    /// - Parameters:
    ///   - geotag: GPS coordinates to write into the CMT4 box and XMP. Pass `nil` to skip GPS.
    ///   - adjustedDate: Date to write into the CMT2 EXIF date fields. Pass `nil` to preserve the original.
    ///   - timezoneToWrite: Already-resolved timezone offset string (e.g. `"+02:00"` or `"Z"`).
    ///     Used for both formatting `adjustedDate` and patching OffsetTime fields. Pass `nil` to skip.
    ///   - sourceURL: Path to the source CR3 file.
    ///   - destinationURL: Path where the patched CR3 file will be written.
    /// - Throws: ``ImageIOError/canNotFindCR3MetadataBox`` if the expected ISOBMFF structure is missing.
    public func write(
        geotag: Geotag?,
        timezoneOverride: String?,
        originalTimezone: String?,
        adjustedDate: Date?,
        toPhotoAt sourceURL: URL,
        saveNewVersionAt destinationURL: URL
    ) throws {
        if sourceURL.path != destinationURL.path {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        var data = try Data(contentsOf: destinationURL)

        guard let moovRange = findBoxRange(named: "moov", in: data, from: 0, to: data.count) else {
            throw CR3MetadataError.canNotFindCR3MetadataBox
        }
        guard let canonRange = findCanonUUIDRange(in: data, searchFrom: moovRange.lowerBound + 8, to: moovRange.upperBound) else {
            throw CR3MetadataError.canNotFindCR3MetadataBox
        }

        let timezoneToWrite = timezoneOverride ?? originalTimezone
        let dateString: String? = adjustedDate.map { date in
            if let tz = timezoneToWrite, isValidTimezoneOffset(tz), let tzObj = parseTimezoneOffset(tz) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                formatter.timeZone = tzObj
                return formatter.string(from: date)
            }
            return DateFormatter.exif.string(from: date)
        }

        if let geotag = geotag {
            guard let cmt4Range = findBoxRange(named: "CMT4", in: data, from: canonRange.lowerBound, to: canonRange.upperBound) else {
                throw CR3MetadataError.canNotFindCR3MetadataBox
            }
            let payloadStart = cmt4Range.lowerBound + 8
            let payloadSize = cmt4Range.count - 8
            let gpsPayload = buildGPSIFDPayload(geotag: geotag, payloadSize: payloadSize)
            data.replaceSubrange(payloadStart..<payloadStart + payloadSize, with: gpsPayload)
        }

        if dateString != nil || timezoneToWrite != nil {
            guard let cmt2Range = findBoxRange(named: "CMT2", in: data, from: canonRange.lowerBound, to: canonRange.upperBound) else {
                throw CR3MetadataError.canNotFindCR3MetadataBox
            }
            let payloadStart = cmt2Range.lowerBound + 8
            let payloadSize = cmt2Range.count - 8
            patchCMT2(in: &data, payloadOffset: payloadStart, payloadSize: payloadSize, dateString: dateString, timezone: timezoneToWrite)
        }

        if geotag != nil || dateString != nil || timezoneToWrite != nil {
            if let xmpRange = findXMPRange(in: data) {
                patchXMP(in: &data, range: xmpRange, geotag: geotag, dateString: dateString, timezone: timezoneToWrite)
            }
        }

        try data.write(to: destinationURL, options: .atomic)
    }
}

// MARK: - ISOBMFF Box Scanning

extension CR3MetadataWriter {

    private static let canonUUID: [UInt8] = [
        0x85, 0xC0, 0xB6, 0x87, 0x82, 0x0F, 0x11, 0xE0,
        0x81, 0x11, 0xF4, 0xCE, 0x46, 0x2B, 0x6A, 0x48
    ]

    private static let xmpUUID: [UInt8] = [
        0xBE, 0x7A, 0xCF, 0xCB, 0x97, 0xA9, 0x42, 0xE8,
        0x9C, 0x71, 0x99, 0x94, 0x91, 0xE3, 0xAF, 0xAC
    ]

    private func findBoxRange(named name: String, in data: Data, from start: Int, to end: Int) -> Range<Int>? {
        let nameBytes = Array(name.utf8)
        guard nameBytes.count == 4 else { return nil }
        var offset = start

        while offset + 8 <= end {
            let size = Int(readBE32(data, at: offset))
            guard size >= 8, offset + size <= end else { break }

            if data[offset + 4] == nameBytes[0] && data[offset + 5] == nameBytes[1] &&
               data[offset + 6] == nameBytes[2] && data[offset + 7] == nameBytes[3] {
                return offset..<(offset + size)
            }
            offset += size
        }
        return nil
    }

    private func findCanonUUIDRange(in data: Data, searchFrom start: Int, to end: Int) -> Range<Int>? {
        var offset = start

        while offset + 24 <= end {
            let size = Int(readBE32(data, at: offset))
            guard size >= 24, offset + size <= end else { break }

            if data[offset + 4] == 0x75 && data[offset + 5] == 0x75 &&
               data[offset + 6] == 0x69 && data[offset + 7] == 0x64 {
                var isCanon = true
                for i in 0..<16 {
                    if data[offset + 8 + i] != Self.canonUUID[i] { isCanon = false; break }
                }
                if isCanon {
                    return (offset + 24)..<(offset + size)
                }
            }
            offset += size
        }
        return nil
    }

    private func findXMPRange(in data: Data) -> Range<Int>? {
        var offset = 0

        while offset + 24 <= data.count {
            let size = Int(readBE32(data, at: offset))
            guard size >= 24, offset + size <= data.count else { break }

            if data[offset + 4] == 0x75 && data[offset + 5] == 0x75 &&
               data[offset + 6] == 0x69 && data[offset + 7] == 0x64 {
                var isXMP = true
                for i in 0..<16 {
                    if data[offset + 8 + i] != Self.xmpUUID[i] { isXMP = false; break }
                }
                if isXMP {
                    return (offset + 24)..<(offset + size)
                }
            }
            offset += size
        }
        return nil
    }
}

// MARK: - GPS IFD Building (CMT4)

extension CR3MetadataWriter {

    private func buildGPSIFDPayload(geotag: Geotag, payloadSize: Int) -> Data {
        var payload = Data(count: payloadSize)

        let lat = geotag.location.latitude.degrees
        let lon = geotag.location.longitude.degrees
        let hasAltitude = geotag.location.altitude != nil
        let entryCount: UInt16 = hasAltitude ? 12 : 10

        let dataAreaStart = 10 + Int(entryCount) * 12 + 4
        var entryOffset = 10
        var dataOffset = dataAreaStart

        // TIFF header
        payload[0] = 0x49; payload[1] = 0x49 // "II" (little-endian)
        writeLE16(&payload, at: 2, value: 42)
        writeLE32(&payload, at: 4, value: 8)
        writeLE16(&payload, at: 8, value: entryCount)

        func writeEntry(tag: UInt16, type: UInt16, count: UInt32, value: UInt32) {
            writeLE16(&payload, at: entryOffset, value: tag)
            writeLE16(&payload, at: entryOffset + 2, value: type)
            writeLE32(&payload, at: entryOffset + 4, value: count)
            writeLE32(&payload, at: entryOffset + 8, value: value)
            entryOffset += 12
        }

        func storeRationals(_ rationals: [(UInt32, UInt32)]) -> UInt32 {
            let offset = dataOffset
            for (num, den) in rationals {
                writeLE32(&payload, at: dataOffset, value: num)
                dataOffset += 4
                writeLE32(&payload, at: dataOffset, value: den)
                dataOffset += 4
            }
            return UInt32(offset)
        }

        func storeASCII(_ string: String) -> UInt32 {
            let offset = dataOffset
            for (i, byte) in string.utf8.enumerated() {
                payload[dataOffset + i] = byte
            }
            payload[dataOffset + string.utf8.count] = 0
            dataOffset += string.utf8.count + 1
            return UInt32(offset)
        }

        func degreesToRationals(_ degrees: Double) -> [(UInt32, UInt32)] {
            let absVal = abs(degrees)
            let deg = UInt32(absVal)
            let minFrac = (absVal - Double(deg)) * 60.0
            let minNum = UInt32((minFrac * 10_000_000).rounded())
            return [(deg, 1), (minNum, 10_000_000), (0, 1)]
        }

        // Entries must be in ascending tag order

        // 0x0000 GPSVersionID — BYTE, count=4, inline: 2.3.0.0
        writeEntry(tag: 0x0000, type: 1, count: 4, value: 0x00000302)

        // 0x0001 GPSLatitudeRef — ASCII, count=2, inline
        writeEntry(tag: 0x0001, type: 2, count: 2, value: lat >= 0 ? 0x004E : 0x0053)

        // 0x0002 GPSLatitude — RATIONAL, count=3
        let latOff = storeRationals(degreesToRationals(lat))
        writeEntry(tag: 0x0002, type: 5, count: 3, value: latOff)

        // 0x0003 GPSLongitudeRef — ASCII, count=2, inline
        writeEntry(tag: 0x0003, type: 2, count: 2, value: lon >= 0 ? 0x0045 : 0x0057)

        // 0x0004 GPSLongitude — RATIONAL, count=3
        let lonOff = storeRationals(degreesToRationals(lon))
        writeEntry(tag: 0x0004, type: 5, count: 3, value: lonOff)

        if let altitude = geotag.location.altitude {
            // 0x0005 GPSAltitudeRef — BYTE, count=1, inline (0=above, 1=below sea level)
            writeEntry(tag: 0x0005, type: 1, count: 1, value: UInt32(Int(altitude.reference)))

            // 0x0006 GPSAltitude — RATIONAL, count=1
            let altNum = UInt32((abs(altitude.value) * 100).rounded())
            let altOff = storeRationals([(altNum, 100)])
            writeEntry(tag: 0x0006, type: 5, count: 1, value: altOff)
        }

        // 0x0007 GPSTimeStamp — RATIONAL, count=3 (placeholder)
        let tsOff = storeRationals([(0, 1), (0, 1), (0, 1)])
        writeEntry(tag: 0x0007, type: 5, count: 3, value: tsOff)

        // 0x0008 GPSSatellites — ASCII, count=1, inline
        writeEntry(tag: 0x0008, type: 2, count: 1, value: 0)

        // 0x0009 GPSStatus — ASCII, count=2, inline "A"
        writeEntry(tag: 0x0009, type: 2, count: 2, value: 0x0041)

        // 0x0012 GPSMapDatum — ASCII, count=7
        let mapOff = storeASCII("WGS-84")
        writeEntry(tag: 0x0012, type: 2, count: 7, value: mapOff)

        // 0x001D GPSDateStamp — ASCII, count=11
        let dateOff = storeASCII("0000:00:00")
        writeEntry(tag: 0x001D, type: 2, count: 11, value: dateOff)

        // Next-IFD pointer is already 0 (zero-filled)

        return payload
    }
}

// MARK: - CMT2 Patching (Date / Timezone)

extension CR3MetadataWriter {

    private func patchCMT2(in data: inout Data, payloadOffset: Int, payloadSize: Int, dateString: String?, timezone: String?) {
        guard payloadSize >= 10,
              data[payloadOffset] == 0x49, data[payloadOffset + 1] == 0x49 else { return }

        let ifdOffset = Int(readLE32(data, at: payloadOffset + 4))
        guard ifdOffset + 2 <= payloadSize else { return }

        let entryCount = Int(readLE16(data, at: payloadOffset + ifdOffset))

        for i in 0..<entryCount {
            let entryBase = payloadOffset + ifdOffset + 2 + i * 12
            guard entryBase + 12 <= payloadOffset + payloadSize else { break }

            let tag = readLE16(data, at: entryBase)
            let type = readLE16(data, at: entryBase + 2)
            let count = Int(readLE32(data, at: entryBase + 4))
            let valueOffset = Int(readLE32(data, at: entryBase + 8))

            guard type == 2 else { continue } // ASCII only

            switch tag {
            case 0x9003, 0x9004: // DateTimeOriginal, DateTimeDigitized
                guard let dateString = dateString, count == 20 else { continue }
                overwriteASCII(in: &data, at: payloadOffset + valueOffset, string: dateString, maxBytes: count)

            case 0x9010, 0x9011, 0x9012: // OffsetTime, OffsetTimeOriginal, OffsetTimeDigitized
                guard let timezone = timezone, isValidTimezoneOffset(timezone), count == 7 else { continue }
                overwriteASCII(in: &data, at: payloadOffset + valueOffset, string: timezone, maxBytes: count)

            default:
                continue
            }
        }
    }

    private func overwriteASCII(in data: inout Data, at offset: Int, string: String, maxBytes: Int) {
        let bytes = Array(string.utf8)
        for i in 0..<min(bytes.count, maxBytes - 1) {
            data[offset + i] = bytes[i]
        }
        for i in bytes.count..<maxBytes {
            data[offset + i] = 0
        }
    }
}

// MARK: - XMP Patching

extension CR3MetadataWriter {

    private func patchXMP(in data: inout Data, range: Range<Int>, geotag: Geotag?, dateString: String?, timezone: String?) {
        let payloadSize = range.count
        guard let xmpString = String(data: data[range], encoding: .utf8) else { return }

        let endMarker = "<?xpacket end='w'?>"
        guard xmpString.range(of: endMarker, options: .backwards) != nil else { return }
        guard xmpString.range(of: "</x:xmpmeta>") != nil else { return }
        guard xmpString.range(of: "</rdf:RDF>") != nil else { return }

        // Extract content up to </x:xmpmeta>
        guard let xmpmetaEndRange = xmpString.range(of: "</x:xmpmeta>") else { return }
        var content = String(xmpString[..<xmpmetaEndRange.upperBound])

        // Build new rdf:Description block
        var block = "<rdf:Description rdf:about=\"\" xmlns:exif=\"http://ns.adobe.com/exif/1.0/\">"

        if let geotag = geotag {
            let lat = geotag.location.latitude.degrees
            let lon = geotag.location.longitude.degrees
            let latStr = xmpGPSCoordinateString(for: lat, positiveDirection: "N", negativeDirection: "S")
            let lonStr = xmpGPSCoordinateString(for: lon, positiveDirection: "E", negativeDirection: "W")
            block += "<exif:GPSLatitude>\(latStr)</exif:GPSLatitude>"
            block += "<exif:GPSLongitude>\(lonStr)</exif:GPSLongitude>"
            block += "<exif:GPSLatitudeRef>\(lat >= 0 ? "N" : "S")</exif:GPSLatitudeRef>"
            block += "<exif:GPSLongitudeRef>\(lon >= 0 ? "E" : "W")</exif:GPSLongitudeRef>"

            if let altitude = geotag.location.altitude {
                let altNumerator = Int((abs(altitude.value) * 100).rounded())
                block += "<exif:GPSAltitude>\(altNumerator)/100</exif:GPSAltitude>"
                block += "<exif:GPSAltitudeRef>\(Int(altitude.reference))</exif:GPSAltitudeRef>"
            }
        }

        if let dateString = dateString {
            block += "<exif:DateTimeOriginal>\(dateString)</exif:DateTimeOriginal>"
            block += "<exif:DateTimeDigitized>\(dateString)</exif:DateTimeDigitized>"
        }

        if let timezone = timezone, isValidTimezoneOffset(timezone) {
            block += "<exif:OffsetTime>\(timezone)</exif:OffsetTime>"
            block += "<exif:OffsetTimeOriginal>\(timezone)</exif:OffsetTimeOriginal>"
            block += "<exif:OffsetTimeDigitized>\(timezone)</exif:OffsetTimeDigitized>"
        }

        block += "</rdf:Description>"

        // Insert before </rdf:RDF>
        if let insertPoint = content.range(of: "</rdf:RDF>") {
            content.insert(contentsOf: block, at: insertPoint.lowerBound)
        }

        // Recalculate padding to maintain original payload size
        let paddingNeeded = payloadSize - content.utf8.count - endMarker.utf8.count
        guard paddingNeeded >= 0 else { return }

        let finalXMP = content + String(repeating: " ", count: paddingNeeded) + endMarker
        guard let finalBytes = finalXMP.data(using: .utf8), finalBytes.count == payloadSize else { return }
        data.replaceSubrange(range, with: finalBytes)
    }

    private func xmpGPSCoordinateString(for value: Double, positiveDirection: String, negativeDirection: String) -> String {
        let absoluteValue = abs(value)
        let degrees = Int(absoluteValue.rounded(.down))
        let minutes = (absoluteValue - Double(degrees)) * 60
        let direction = value < 0 ? negativeDirection : positiveDirection
        return String(format: "%d,%.7f%@",
                      locale: Locale(identifier: "en_US_POSIX"),
                      degrees,
                      minutes,
                      direction)
    }
}

// MARK: - Binary Helpers

extension CR3MetadataWriter {

    private func readBE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
        UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }

    private func readLE16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func readLE32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) | UInt32(data[offset + 1]) << 8 |
        UInt32(data[offset + 2]) << 16 | UInt32(data[offset + 3]) << 24
    }

    private func writeLE16(_ data: inout Data, at offset: Int, value: UInt16) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8(value >> 8)
    }

    private func writeLE32(_ data: inout Data, at offset: Int, value: UInt32) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8(value >> 24)
    }
}
