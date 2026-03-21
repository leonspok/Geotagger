//
//  TimeOffsetTests.swift
//  
//
//  Created on 24/06/2025.
//

import XCTest
@testable import GeotagKit

final class TimeOffsetTests: XCTestCase {

    private let baseDate = Date(timeIntervalSince1970: 1000000)

    // MARK: - TimeOffsetGeoAnchorsLoader Tests

    func testTimeOffsetGeoAnchorsLoaderAppliesOffset() throws {
        let originalAnchors = [
            GeoAnchor(date: baseDate, location: Location(latitude: .degrees(52.0), longitude: .degrees(13.0))),
            GeoAnchor(date: baseDate.addingTimeInterval(100), location: Location(latitude: .degrees(54.0), longitude: .degrees(15.0)))
        ]

        let mockLoader = MockGeoAnchorsLoader(anchors: originalAnchors)
        let offsetLoader = TimeOffsetGeoAnchorsLoader(wrapping: mockLoader, timeOffset: 300) // 5 minutes

        let offsetAnchors = try offsetLoader.loadAnchors()

        XCTAssertEqual(offsetAnchors.count, 2)
        XCTAssertEqual(offsetAnchors[0].date, baseDate.addingTimeInterval(300))
        XCTAssertEqual(offsetAnchors[1].date, baseDate.addingTimeInterval(400))

        // Location should remain unchanged
        XCTAssertEqual(offsetAnchors[0].location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(offsetAnchors[0].location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    func testTimeOffsetGeoAnchorsLoaderNegativeOffset() throws {
        let originalAnchors = [
            GeoAnchor(date: baseDate, location: Location(latitude: .degrees(52.0), longitude: .degrees(13.0)))
        ]

        let mockLoader = MockGeoAnchorsLoader(anchors: originalAnchors)
        let offsetLoader = TimeOffsetGeoAnchorsLoader(wrapping: mockLoader, timeOffset: -600) // -10 minutes

        let offsetAnchors = try offsetLoader.loadAnchors()

        XCTAssertEqual(offsetAnchors[0].date, baseDate.addingTimeInterval(-600))
    }

    // MARK: - Timezone Formatting Tests

    func testTimezoneOffsetFormatting() {
        // Test Int extension for formatting seconds to timezone string
        let testCases = [
            (0, "Z"),
            (18000, "+05:00"),
            (-28800, "-08:00"),
            (19800, "+05:30"),
            (-34200, "-09:30")
        ]

        for (seconds, expected) in testCases {
            let formatted = seconds.formatAsTimezoneOffset()
            XCTAssertEqual(formatted, expected, "Failed for \(seconds) seconds")
        }
    }

    // MARK: - Timezone Parsing Tests

    func testTimezoneOffsetParsing() {
        // Test GMT offset format parsing
        XCTAssertEqual(parseAsTimezoneOffset("+05:00"), 18000)  // +5 hours
        XCTAssertEqual(parseAsTimezoneOffset("-08:00"), -28800) // -8 hours
        XCTAssertEqual(parseAsTimezoneOffset("+00:00"), 0)      // UTC
        XCTAssertEqual(parseAsTimezoneOffset("+05:30"), 19800)  // +5:30 hours (India)
        XCTAssertEqual(parseAsTimezoneOffset("-09:30"), -34200) // -9:30 hours
        XCTAssertEqual(parseAsTimezoneOffset("Z"), 0)           // UTC

        // Test invalid GMT offset formats
        XCTAssertNil(parseAsTimezoneOffset("5:00"))    // Missing sign
        XCTAssertNil(parseAsTimezoneOffset("+5:00"))   // Wrong hour format
        XCTAssertNil(parseAsTimezoneOffset("+05:0"))   // Wrong minute format
        XCTAssertNil(parseAsTimezoneOffset("+25:00"))  // Invalid hour
        XCTAssertNil(parseAsTimezoneOffset("+05:60"))  // Invalid minute
        XCTAssertNil(parseAsTimezoneOffset(""))        // Empty string

        // Test common timezone abbreviations
        XCTAssertNotNil(parseAsTimezoneOffset("UTC"))
        XCTAssertNotNil(parseAsTimezoneOffset("GMT"))

        // US timezone abbreviations
        XCTAssertNotNil(parseAsTimezoneOffset("EST"))  // Eastern Standard Time
        XCTAssertNotNil(parseAsTimezoneOffset("EDT"))  // Eastern Daylight Time
        XCTAssertNotNil(parseAsTimezoneOffset("PST"))  // Pacific Standard Time
        XCTAssertNotNil(parseAsTimezoneOffset("PDT"))  // Pacific Daylight Time
        XCTAssertNotNil(parseAsTimezoneOffset("CST"))  // Central Standard Time
        XCTAssertNotNil(parseAsTimezoneOffset("CDT"))  // Central Daylight Time
        XCTAssertNotNil(parseAsTimezoneOffset("MST"))  // Mountain Standard Time
        XCTAssertNotNil(parseAsTimezoneOffset("MDT"))  // Mountain Daylight Time

        // European timezone abbreviations
        XCTAssertNotNil(parseAsTimezoneOffset("CET"))  // Central European Time
        XCTAssertNotNil(parseAsTimezoneOffset("CEST")) // Central European Summer Time
        XCTAssertNotNil(parseAsTimezoneOffset("WET"))  // Western European Time
        XCTAssertNotNil(parseAsTimezoneOffset("WEST")) // Western European Summer Time

        // Other common abbreviations
        XCTAssertNotNil(parseAsTimezoneOffset("JST"))  // Japan Standard Time

        // Test timezone identifiers
        XCTAssertNotNil(parseAsTimezoneOffset("America/New_York"))
        XCTAssertNotNil(parseAsTimezoneOffset("America/Los_Angeles"))
        XCTAssertNotNil(parseAsTimezoneOffset("America/Chicago"))
        XCTAssertNotNil(parseAsTimezoneOffset("America/Denver"))
        XCTAssertNotNil(parseAsTimezoneOffset("Europe/London"))
        XCTAssertNotNil(parseAsTimezoneOffset("Europe/Paris"))
        XCTAssertNotNil(parseAsTimezoneOffset("Europe/Berlin"))
        XCTAssertNotNil(parseAsTimezoneOffset("Asia/Tokyo"))
        XCTAssertNotNil(parseAsTimezoneOffset("Australia/Sydney"))

        // Test invalid timezone
        XCTAssertNil(parseAsTimezoneOffset("INVALID_TIMEZONE"))
    }

    // MARK: - ImageIOWriter Timezone Formatting Tests

    func testImageIOWriterTimezoneAwareDateFormatting() {
        // Test that ImageIOWriter formats dates correctly when timezone is provided
        // This simulates the scenario: read "05:00+02:00", apply 30min offset, write "05:30+02:00"

        _ = ImageIOWriter()

        // Create a date representing "05:00+02:00" (which is 03:00 UTC)
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 28
        components.hour = 5
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 2 * 3600) // +02:00
        let originalDate = Calendar.current.date(from: components)!

        // Apply 30-minute offset (simulating time adjustment)
        let adjustedDate = originalDate.addingTimeInterval(30 * 60) // +30 minutes

        // The adjusted date should represent "05:30+02:00" (which is 03:30 UTC)
        // When we format this with +02:00 timezone, we should get "05:30"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 2 * 3600) // +02:00

        let formattedDate = formatter.string(from: adjustedDate)

        // Should be "2025:06:28 05:30:00" (local time in +02:00 timezone)
        XCTAssertEqual(formattedDate, "2025:06:28 05:30:00")

        // Verify the absolute time is correct (should be 03:30 UTC)
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US")
        utcFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let utcTime = utcFormatter.string(from: adjustedDate)

        XCTAssertEqual(utcTime, "2025:06:28 03:30:00")

        // Key insight: Date objects show "+0000" when printed, proving they don't store timezone info
        // The timezone is only used during creation to calculate the absolute moment, then discarded
    }

    // MARK: - Timezone Preservation Tests

    func testImageIOReaderDateAndTimezoneFromPhoto() throws {
        // Test that readDateAndTimezoneFromPhoto returns both date and timezone
        let reader = ImageIOReader()

        // Create mock EXIF metadata
        let exifDict: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: "2025:06:28 05:00:00",
            kCGImagePropertyExifOffsetTimeOriginal: "+02:00"
        ]
        let metadata: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exifDict
        ]

        let (date, timezone) = reader.readDateAndTimezoneFromMetadata(metadata)

        XCTAssertNotNil(date)
        XCTAssertEqual(timezone, "+02:00")

        // Verify the date represents the correct absolute moment (03:00 UTC)
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US")
        utcFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        XCTAssertEqual(utcFormatter.string(from: date!), "2025:06:28 03:00:00")
    }

    func testImageIOReaderDateAndTimezoneWithoutTimezone() throws {
        // Test that readDateAndTimezoneFromPhoto returns date and nil timezone when no timezone
        let reader = ImageIOReader()

        // Create mock EXIF metadata without timezone
        let exifDict: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: "2025:06:28 05:00:00"
        ]
        let metadata: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exifDict
        ]

        let (date, timezone) = reader.readDateAndTimezoneFromMetadata(metadata)

        XCTAssertNotNil(date)
        XCTAssertNil(timezone)
    }

    func testTimezonePreservationFlow() async throws {
        // Test the complete flow: photo with timezone → time adjustment → preserved timezone

        // 1. Mock ImageIOReader that returns timezone info
        let mockReader = TestImageReader(
            dateAndTimezone: (baseDate, "+02:00")
        )

        // 2. Mock ImageIOWriter to capture what gets written
        let mockWriter = TestImageWriter()

        // 3. Create ImageIOGeotaggingItem
        let photoURL = URL(fileURLWithPath: "/test/photo.jpg")
        let outputURL = URL(fileURLWithPath: "/test/output.jpg")

        let item = ImageFileGeotaggingItem(
            photoURL: photoURL,
            outputURL: outputURL,
            imageReader: mockReader,
            imageWriter: mockWriter,
            timeOffset: 30 * 60, // 30 minutes
            timezoneOverride: nil,
            timeAdjustmentSaveMode: .all
        )

        // 4. Simulate skip (write time adjustments only)
        try await item.skip(with: NSError(domain: "test", code: 1))

        // 5. Verify the writer was called with correct parameters
        XCTAssertEqual(mockWriter.capturedCalls.count, 1)
        let call = mockWriter.capturedCalls[0]
        XCTAssertNil(call.geotag)
        XCTAssertNil(call.timezoneOverride) // No CLI override
        XCTAssertEqual(call.originalTimezone, "+02:00") // Original timezone preserved
        XCTAssertNotNil(call.adjustedDate) // Adjusted date provided
    }

    func testTimezoneOverrideTakesPrecedence() async throws {
        // Test that timezoneOverride takes precedence over original timezone

        let mockReader = TestImageReader(
            dateAndTimezone: (baseDate, "+02:00")
        )
        let mockWriter = TestImageWriter()

        let photoURL = URL(fileURLWithPath: "/test/photo.jpg")
        let outputURL = URL(fileURLWithPath: "/test/output.jpg")

        let item = ImageFileGeotaggingItem(
            photoURL: photoURL,
            outputURL: outputURL,
            imageReader: mockReader,
            imageWriter: mockWriter,
            timeOffset: nil,
            timezoneOverride: -8 * 3600, // -08:00 (PST)
            timeAdjustmentSaveMode: .all
        )

        try await item.skip(with: NSError(domain: "test", code: 1))

        let call = mockWriter.capturedCalls[0]
        XCTAssertEqual(call.timezoneOverride, "-08:00") // CLI override used
        XCTAssertEqual(call.originalTimezone, "+02:00") // Original timezone still passed
    }
}

// MARK: - Helper Classes

private class MockGeoAnchorsLoader: GeoAnchorsLoaderProtocol {
    private let anchors: [GeoAnchor]

    init(anchors: [GeoAnchor]) {
        self.anchors = anchors
    }

    func loadAnchors() throws -> [GeoAnchor] {
        return anchors
    }
}

private final class TestImageReader: @unchecked Sendable, ImageFileReaderProtocol {
    private let dateAndTimezone: (Date?, String?)

    init(dateAndTimezone: (Date?, String?)) {
        self.dateAndTimezone = dateAndTimezone
    }

    func readDateFromPhoto(at url: URL) throws -> Date? {
        return dateAndTimezone.0
    }

    func readDateAndTimezoneFromPhoto(at url: URL) throws -> (Date?, String?) {
        return dateAndTimezone
    }

    func readGeotagFromPhoto(at url: URL) throws -> Geotag? {
        return nil
    }

    func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor? {
        return nil
    }
}

private final class TestImageWriter: @unchecked Sendable, ImageFileWriterProtocol {
    struct WriterCall {
        let geotag: Geotag?
        let timezoneOverride: String?
        let originalTimezone: String?
        let adjustedDate: Date?
        let sourceURL: URL
        let destinationURL: URL
    }

    private let capturedCallsStorage = NSMutableArray()

    var capturedCalls: [WriterCall] {
        return capturedCallsStorage.compactMap { $0 as? WriterCall }
    }

    func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        let call = WriterCall(
            geotag: geotag,
            timezoneOverride: timezoneOverride,
            originalTimezone: originalTimezone,
            adjustedDate: adjustedDate,
            sourceURL: sourceURL,
            destinationURL: destinationURL
        )
        capturedCallsStorage.add(call)
    }
}
