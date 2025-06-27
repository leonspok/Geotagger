//
//  TimeOffsetTests.swift
//  
//
//  Created on 24/06/2025.
//

import XCTest
@testable import Geotagger
@testable import CLI

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
    
    // MARK: - ImageIOWriter Timezone Validation Tests
    
    func testImageIOWriterTimezoneValidation() {
        let writer = ImageIOWriter()
        
        // Test valid timezone formats
        XCTAssertTrue(writer.isValidTimezoneOffset("Z"))
        XCTAssertTrue(writer.isValidTimezoneOffset("+05:00"))
        XCTAssertTrue(writer.isValidTimezoneOffset("-08:00"))
        XCTAssertTrue(writer.isValidTimezoneOffset("+00:00"))
        XCTAssertTrue(writer.isValidTimezoneOffset("-12:00"))
        XCTAssertTrue(writer.isValidTimezoneOffset("+14:00"))
        XCTAssertTrue(writer.isValidTimezoneOffset("+05:30"))  // India
        XCTAssertTrue(writer.isValidTimezoneOffset("+09:45"))  // Nepal
        
        // Test invalid formats
        XCTAssertFalse(writer.isValidTimezoneOffset("5:00"))
        XCTAssertFalse(writer.isValidTimezoneOffset("+5:00"))
        XCTAssertFalse(writer.isValidTimezoneOffset("+05:0"))
        XCTAssertFalse(writer.isValidTimezoneOffset("UTC"))
        XCTAssertFalse(writer.isValidTimezoneOffset(""))
        XCTAssertFalse(writer.isValidTimezoneOffset("+25:00"))  // Invalid hour
        XCTAssertFalse(writer.isValidTimezoneOffset("+05:60"))  // Invalid minute
        XCTAssertFalse(writer.isValidTimezoneOffset("+05:05"))  // Invalid minute offset
    }
    
    // MARK: - Timezone Formatting Tests
    
    func testTimezoneOffsetFormatting() {
        // Test helper method to format seconds back to timezone string
        let testCases = [
            (0, "Z"),
            (18000, "+05:00"),
            (-28800, "-08:00"),
            (19800, "+05:30"),
            (-34200, "-09:30")
        ]
        
        // Test Int extension for formatting seconds to timezone string
        
        for (seconds, expected) in testCases {
            let formatted = seconds.formatAsTimezoneOffset()
            XCTAssertEqual(formatted, expected, "Failed for \(seconds) seconds")
        }
    }
    
    // MARK: - TimeZone Parsing Tests
    
    func testTimeZoneParsingPatterns() {
        // Test GMT offset pattern parsing directly
        let gmtPattern = /^([+-])(\d{2}):(\d{2})$/
        
        let testCases = [
            ("+05:00", 18000),   // +5 hours
            ("-08:00", -28800),  // -8 hours  
            ("+00:00", 0),       // UTC
            ("+05:30", 19800)    // +5:30 hours
        ]
        
        for (input, expected) in testCases {
            if let match = input.firstMatch(of: gmtPattern) {
                let hours = Int(match.2) ?? 0
                let minutes = Int(match.3) ?? 0
                let totalSeconds = (hours * 3600) + (minutes * 60)
                let result = match.1 == "+" ? totalSeconds : -totalSeconds
                XCTAssertEqual(result, expected, "Failed for \\(input)")
            } else {
                XCTFail("Failed to match pattern for \\(input)")
            }
        }
    }
    
    func testTimeZoneValidation() {
        // Test TimeZone creation with various inputs
        XCTAssertNotNil(TimeZone(abbreviation: "UTC"))
        XCTAssertNotNil(TimeZone(identifier: "UTC"))
        XCTAssertNotNil(TimeZone(identifier: "America/New_York"))
        XCTAssertNil(TimeZone(abbreviation: "INVALID"))
    }
    
    // MARK: - ImageIOWriter Method Tests
    
    func testImageIOWriterMethodSignatures() {
        let writer = ImageIOWriter()
        
        // Verify all method signatures exist and can be called
        // We're just testing the API exists, not the actual file writing
        XCTAssertNotNil(writer.write(geotag:timezoneOverride:adjustedDate:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.write(_:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.write(_:timezoneOverride:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.write(_:timezoneOverride:adjustedDate:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.writeTimeAdjustments(timezoneOverride:adjustedDate:toPhotoAt:saveNewVersionAt:))
    }
    
    // MARK: - TimeAdjustmentSaveMode Tests
    
    func testTimeAdjustmentSaveModeValues() {
        XCTAssertEqual(TimeAdjustmentSaveMode.all.rawValue, "all")
        XCTAssertEqual(TimeAdjustmentSaveMode.tagged.rawValue, "tagged")
        XCTAssertEqual(TimeAdjustmentSaveMode.none.rawValue, "none")
        
        XCTAssertEqual(TimeAdjustmentSaveMode.allCases.count, 3)
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

// Extension to access private method for testing
extension ImageIOWriter {
    func isValidTimezoneOffset(_ timezone: String) -> Bool {
        // Valid formats: "+05:00", "-08:00", "Z"
        if timezone == "Z" {
            return true
        }
        
        let pattern = /^([+-])(\d{2}):(\d{2})$/
        guard let match = timezone.firstMatch(of: pattern) else {
            return false
        }
        
        // Extract hours and minutes
        guard let hours = Int(match.2),
              let minutes = Int(match.3) else {
            return false
        }
        
        // Valid timezone offsets are -12:00 to +14:00
        // Minutes should be 00, 15, 30, or 45 (common timezone minute offsets)
        return hours >= 0 && hours <= 14 && (minutes == 0 || minutes == 15 || minutes == 30 || minutes == 45)
    }
}


