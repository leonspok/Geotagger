//
//  SimpleTimezoneTests.swift
//  
//
//  Created on 28/06/2025.
//

import XCTest
@testable import Geotagger

final class SimpleTimezoneTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private let baseDate = Date(timeIntervalSince1970: 1000000) // 1970-01-12 13:46:40 UTC
    
    private func createAnchor(secondsOffset: TimeInterval, lat: Double = 52.5200, lon: Double = 13.4050) -> GeoAnchor {
        let location = Location(latitude: .degrees(lat), longitude: .degrees(lon), altitude: nil)
        return GeoAnchor(date: self.baseDate.addingTimeInterval(secondsOffset), location: location)
    }
    
    private func createMockItem(date: Date) -> MockGeotaggingItem {
        return MockGeotaggingItem(date: date)
    }
    
    // MARK: - Core Timezone Functionality Tests
    
    func testTimezoneParsingDoesNotBreakExistingFunctionality() throws {
        // Verify that our timezone implementation doesn't break basic geotagging
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        
        let anchor = self.createAnchor(secondsOffset: 0)
        let item = self.createMockItem(date: self.baseDate)
        
        let geotag = try finder.findGeotag(for: item, using: [anchor])
        
        XCTAssertEqual(geotag.location.latitude.degrees, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.4050, accuracy: 0.0001)
    }
    
    
    func testGeotagFinderWithTimezoneAwareDates() throws {
        // Test that GeotagFinder works correctly when given timezone-aware dates
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        
        // Create anchor at a specific UTC time
        var anchorComponents = DateComponents()
        anchorComponents.year = 2025
        anchorComponents.month = 6
        anchorComponents.day = 28
        anchorComponents.hour = 12
        anchorComponents.minute = 0
        anchorComponents.second = 0
        anchorComponents.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let anchorDate = Calendar.current.date(from: anchorComponents)!
        
        let anchor = GeoAnchor(
            date: anchorDate,
            location: Location(latitude: .degrees(52.5200), longitude: .degrees(13.4050))
        )
        
        // Create item representing the same absolute moment but in different timezone
        var itemComponents = DateComponents()
        itemComponents.year = 2025
        itemComponents.month = 6
        itemComponents.day = 28
        itemComponents.hour = 17
        itemComponents.minute = 0
        itemComponents.second = 0
        itemComponents.timeZone = TimeZone(secondsFromGMT: 5 * 3600) // +05:00 (17:00+05:00 = 12:00 UTC)
        let itemDate = Calendar.current.date(from: itemComponents)!
        
        let item = self.createMockItem(date: itemDate)
        
        // Should match exactly since they represent the same absolute moment
        let geotag = try finder.findGeotag(for: item, using: [anchor])
        
        XCTAssertEqual(geotag.location.latitude.degrees, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.4050, accuracy: 0.0001)
    }
    
    func testInterpolationWithTimezoneAwareDates() throws {
        // Test interpolation works correctly with timezone-aware dates
        let finder = GeotagFinder(exactMatchTimeRange: 0, interpolationMatchTimeRange: 7200) // 2 hours
        
        // Create two anchors 2 hours apart in UTC
        var anchor1Components = DateComponents()
        anchor1Components.year = 2025
        anchor1Components.month = 6
        anchor1Components.day = 28
        anchor1Components.hour = 12
        anchor1Components.minute = 0
        anchor1Components.second = 0
        anchor1Components.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let anchor1Date = Calendar.current.date(from: anchor1Components)!
        
        var anchor2Components = DateComponents()
        anchor2Components.year = 2025
        anchor2Components.month = 6
        anchor2Components.day = 28
        anchor2Components.hour = 14
        anchor2Components.minute = 0
        anchor2Components.second = 0
        anchor2Components.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        let anchor2Date = Calendar.current.date(from: anchor2Components)!
        
        let anchor1 = GeoAnchor(
            date: anchor1Date,
            location: Location(latitude: .degrees(52.0), longitude: .degrees(13.0))
        )
        let anchor2 = GeoAnchor(
            date: anchor2Date,
            location: Location(latitude: .degrees(53.0), longitude: .degrees(14.0))
        )
        
        // Create item representing 13:00 UTC (1 hour after anchor1) but in +05:00 timezone
        var itemComponents = DateComponents()
        itemComponents.year = 2025
        itemComponents.month = 6
        itemComponents.day = 28
        itemComponents.hour = 18
        itemComponents.minute = 0
        itemComponents.second = 0
        itemComponents.timeZone = TimeZone(secondsFromGMT: 5 * 3600) // +05:00 (18:00+05:00 = 13:00 UTC)
        let itemDate = Calendar.current.date(from: itemComponents)!
        
        let item = self.createMockItem(date: itemDate)
        
        // Should interpolate to the middle point
        let geotag = try finder.findGeotag(for: item, using: [anchor1, anchor2])
        
        XCTAssertEqual(geotag.location.latitude.degrees, 52.5, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.5, accuracy: 0.01)
    }
    
}