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
        XCTAssertEqual("+05:00".parseAsTimezoneOffset(), 18000)  // +5 hours
        XCTAssertEqual("-08:00".parseAsTimezoneOffset(), -28800) // -8 hours
        XCTAssertEqual("+00:00".parseAsTimezoneOffset(), 0)      // UTC
        XCTAssertEqual("+05:30".parseAsTimezoneOffset(), 19800)  // +5:30 hours (India)
        XCTAssertEqual("-09:30".parseAsTimezoneOffset(), -34200) // -9:30 hours
        XCTAssertEqual("Z".parseAsTimezoneOffset(), 0)           // UTC
        
        // Test invalid GMT offset formats
        XCTAssertNil("5:00".parseAsTimezoneOffset())    // Missing sign
        XCTAssertNil("+5:00".parseAsTimezoneOffset())   // Wrong hour format
        XCTAssertNil("+05:0".parseAsTimezoneOffset())   // Wrong minute format
        XCTAssertNil("+25:00".parseAsTimezoneOffset())  // Invalid hour
        XCTAssertNil("+05:60".parseAsTimezoneOffset())  // Invalid minute
        XCTAssertNil("".parseAsTimezoneOffset())        // Empty string
        
        // Test common timezone abbreviations
        XCTAssertNotNil("UTC".parseAsTimezoneOffset())
        XCTAssertNotNil("GMT".parseAsTimezoneOffset())
        
        // US timezone abbreviations
        XCTAssertNotNil("EST".parseAsTimezoneOffset())  // Eastern Standard Time
        XCTAssertNotNil("EDT".parseAsTimezoneOffset())  // Eastern Daylight Time
        XCTAssertNotNil("PST".parseAsTimezoneOffset())  // Pacific Standard Time
        XCTAssertNotNil("PDT".parseAsTimezoneOffset())  // Pacific Daylight Time
        XCTAssertNotNil("CST".parseAsTimezoneOffset())  // Central Standard Time
        XCTAssertNotNil("CDT".parseAsTimezoneOffset())  // Central Daylight Time
        XCTAssertNotNil("MST".parseAsTimezoneOffset())  // Mountain Standard Time
        XCTAssertNotNil("MDT".parseAsTimezoneOffset())  // Mountain Daylight Time
        
        // European timezone abbreviations
        XCTAssertNotNil("CET".parseAsTimezoneOffset())  // Central European Time
        XCTAssertNotNil("CEST".parseAsTimezoneOffset()) // Central European Summer Time
        XCTAssertNotNil("WET".parseAsTimezoneOffset())  // Western European Time
        XCTAssertNotNil("WEST".parseAsTimezoneOffset()) // Western European Summer Time
        
        // Other common abbreviations
        XCTAssertNotNil("JST".parseAsTimezoneOffset())  // Japan Standard Time
        
        // Test timezone identifiers
        XCTAssertNotNil("America/New_York".parseAsTimezoneOffset())
        XCTAssertNotNil("America/Los_Angeles".parseAsTimezoneOffset())
        XCTAssertNotNil("America/Chicago".parseAsTimezoneOffset())
        XCTAssertNotNil("America/Denver".parseAsTimezoneOffset())
        XCTAssertNotNil("Europe/London".parseAsTimezoneOffset())
        XCTAssertNotNil("Europe/Paris".parseAsTimezoneOffset())
        XCTAssertNotNil("Europe/Berlin".parseAsTimezoneOffset())
        XCTAssertNotNil("Asia/Tokyo".parseAsTimezoneOffset())
        XCTAssertNotNil("Australia/Sydney".parseAsTimezoneOffset())
        
        // Test invalid timezone
        XCTAssertNil("INVALID_TIMEZONE".parseAsTimezoneOffset())
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



