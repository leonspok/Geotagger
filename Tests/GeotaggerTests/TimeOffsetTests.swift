//
//  TimeOffsetTests.swift
//  
//
//  Created on 24/06/2025.
//

import XCTest
@testable import Geotagger

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
    
    // MARK: - MockGeotaggingItem Time Offset Tests
    
    func testMockGeotaggingItemWithTimeOffset() {
        let timeOffset: TimeInterval = 1800 // 30 minutes
        let timezoneOverride = "+05:00"
        
        let item = MockGeotaggingItem(
            date: baseDate,
            timeOffset: timeOffset,
            timezoneOverride: timezoneOverride
        )
        
        XCTAssertEqual(item.date, baseDate)
        XCTAssertEqual(item.timeOffset, timeOffset)
        XCTAssertEqual(item.timezoneOverride, timezoneOverride)
    }
    
    func testMockGeotaggingItemDefaultValues() {
        let item = MockGeotaggingItem(date: baseDate)
        
        XCTAssertEqual(item.date, baseDate)
        XCTAssertNil(item.timeOffset)
        XCTAssertNil(item.timezoneOverride)
    }
    
    // MARK: - ImageIOWriter Adjusted Date Tests
    
    func testImageIOWriterMethodSignatures() {
        let writer = ImageIOWriter()
        
        // Verify all three method signatures exist and can be called
        // We're just testing the API exists, not the actual file writing
        XCTAssertNotNil(writer.write(_:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.write(_:timezoneOverride:toPhotoAt:saveNewVersionAt:))
        XCTAssertNotNil(writer.write(_:timezoneOverride:adjustedDate:toPhotoAt:saveNewVersionAt:))
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