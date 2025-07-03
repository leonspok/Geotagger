//
//  TimezoneGeotagFinderTests.swift
//  
//
//  Created on 28/06/2025.
//

import XCTest
@testable import Geotagger

final class TimezoneGeotagFinderTests: XCTestCase {

    // MARK: - Test Helpers

    private let baseDate = Date(timeIntervalSince1970: 1000000)
    private let baseLocation = Location(latitude: .degrees(52.5200), longitude: .degrees(13.4050))

    private func createAnchor(secondsOffset: TimeInterval, lat: Double = 52.5200, lon: Double = 13.4050, alt: Double? = nil) -> GeoAnchor {
        let location = Location(
            latitude: .degrees(lat),
            longitude: .degrees(lon),
            altitude: alt.map { Altitude(value: $0, reference: 0) }
        )
        return GeoAnchor(date: self.baseDate.addingTimeInterval(secondsOffset), location: location)
    }

    private func createTimezoneAwareItem(dateInTimezone: Date) -> MockGeotaggingItem {
        return MockGeotaggingItem(date: dateInTimezone)
    }

    private func createDateInTimezone(hour: Int, minute: Int, second: Int, timezoneOffsetSeconds: Int) -> Date {
        // Create a date using DateComponents with proper timezone context, using baseDate's year/month/day
        // This simulates how ImageIOReader now parses dates with timezone information
        let baseComponents = Calendar.current.dateComponents([.year, .month, .day], from: self.baseDate)

        var components = DateComponents()
        components.year = baseComponents.year
        components.month = baseComponents.month
        components.day = baseComponents.day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: timezoneOffsetSeconds)

        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Timezone Matching Tests

    func testExactMatchSameAbsoluteTime() throws {
        // This test verifies that our timezone fixes don't break basic functionality
        let finder = GeotagFinder(exactMatchTimeRange: 60)

        let anchor = self.createAnchor(secondsOffset: 0)
        let item = self.createTimezoneAwareItem(dateInTimezone: self.baseDate)

        let geotag = try finder.findGeotag(for: item, using: [anchor])

        XCTAssertEqual(geotag.location.latitude.degrees, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.4050, accuracy: 0.0001)
    }

    func testInterpolationAcrossTimezones() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 0, interpolationMatchTimeRange: 7200) // 2 hours

        // Create two anchors 2 hours apart in UTC  
        let anchor1 = self.createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0)     // 13:46:40 UTC (baseDate)
        let anchor2 = self.createAnchor(secondsOffset: 7200, lat: 53.0, lon: 14.0) // 15:46:40 UTC (baseDate + 2h)

        // Create item representing "19:46+05:00" which equals "14:46:40 UTC" (halfway between anchors)
        // baseDate is 13:46:40 UTC, so anchor1 is at 13:46:40, anchor2 is at 15:46:40
        // We want item halfway between, so at 14:46:40 UTC
        // That means 19:46+05:00 (14:46 + 5:00 = 19:46)
        let itemDate = self.createDateInTimezone(hour: 19, minute: 46, second: 40, timezoneOffsetSeconds: 5 * 3600)
        let item = self.createTimezoneAwareItem(dateInTimezone: itemDate)

        let geotag = try finder.findGeotag(for: item, using: [anchor1, anchor2])

        // Should interpolate to the middle point (52.5, 13.5)
        XCTAssertEqual(geotag.location.latitude.degrees, 52.5, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.5, accuracy: 0.01)
    }

    func testMultipleTimezonesWithExactMatch() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)

        // Create multiple anchors at different times
        let anchor1 = self.createAnchor(secondsOffset: -1800, lat: 51.0, lon: 12.0) // 30 min before
        let anchor2 = self.createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0)     // exact time
        let anchor3 = self.createAnchor(secondsOffset: 1800, lat: 53.0, lon: 14.0)  // 30 min after

        // Create item at exact base time
        let item = self.createTimezoneAwareItem(dateInTimezone: self.baseDate)

        let geotag = try finder.findGeotag(for: item, using: [anchor1, anchor2, anchor3])

        // Should match anchor2 exactly
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    func testNegativeTimezoneOffset() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)

        // Test with negative timezone offset (e.g., -8:00 timezone like PST)
        let anchor = self.createAnchor(secondsOffset: 0)

        // Create item representing "12:00-08:00" which equals "20:00 UTC"
        // This should be 6 hours 13 minutes 20 seconds after baseDate (13:46:40 UTC)
        // So 20:00:00 UTC = 12:00-08:00
        let itemDate = self.createDateInTimezone(hour: 12, minute: 0, second: 0, timezoneOffsetSeconds: -8 * 3600)
        let item = self.createTimezoneAwareItem(dateInTimezone: itemDate)

        // They should be 8 hours apart, so exact match should fail
        XCTAssertThrowsError(try finder.findGeotag(for: item, using: [anchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    func testTimezoneEdgeCases() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 86400) // 24 hours

        // Test with extreme timezone offsets
        let anchor1 = self.createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0)
        let anchor2 = self.createAnchor(secondsOffset: 86400, lat: 52.1, lon: 13.1) // 24 hours later

        // Create item 12 hours after first anchor
        let itemDate = self.baseDate.addingTimeInterval(12 * 3600)
        let item = self.createTimezoneAwareItem(dateInTimezone: itemDate)

        let geotag = try finder.findGeotag(for: item, using: [anchor1, anchor2])

        // Should interpolate to the middle point
        XCTAssertEqual(geotag.location.latitude.degrees, 52.05, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.05, accuracy: 0.01)
    }

    // MARK: - Real-world Timezone Scenarios

    func testPhotoInTokyoAnchorInLondon() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 14400) // 4 hours interpolation window

        // Simulate a photo taken in Tokyo (UTC+9) and GPX track from London (UTC+0)
        // Photo taken at "15:00 Tokyo time" = "06:00 UTC"
        // GPX anchor at "14:00 London time" = "14:00 UTC"  
        // They are 8 hours apart

        // Create item representing "15:00+09:00" which equals "06:00 UTC"  
        // This should be 7 hours 46 minutes 40 seconds before baseDate (13:46:40 UTC)
        // So 06:00:00 UTC = 15:00+09:00
        let tokyoLocalTime = self.createDateInTimezone(hour: 15, minute: 0, second: 0, timezoneOffsetSeconds: 9 * 3600)

        let londonAnchor = self.createAnchor(secondsOffset: 0, lat: 51.5074, lon: -0.1278) // London coords
        let tokyoItem = self.createTimezoneAwareItem(dateInTimezone: tokyoLocalTime)

        // This should fail exact match but potentially work with interpolation if within range
        XCTAssertThrowsError(try finder.findGeotag(for: tokyoItem, using: [londonAnchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    func testDaylightSavingTimeTransition() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 7200) // 2 hours window

        // Simulate the complexity around daylight saving time transitions
        // Create anchors before and after a theoretical 2-hour gap
        let anchor1 = self.createAnchor(secondsOffset: -3600, lat: 52.0, lon: 13.0) // 1 hour before
        let anchor2 = self.createAnchor(secondsOffset: 3600, lat: 52.1, lon: 13.1)  // 1 hour after (skipping the DST gap)

        // Item exactly at base time (in the "gap")
        let item = self.createTimezoneAwareItem(dateInTimezone: self.baseDate)

        let geotag = try finder.findGeotag(for: item, using: [anchor1, anchor2])

        // Should interpolate successfully
        XCTAssertEqual(geotag.location.latitude.degrees, 52.05, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.05, accuracy: 0.01)
    }
}
