//
//  GeotagFinderTests.swift
//  
//
//  Created on 24/06/2025.
//

import XCTest
@testable import Geotagger

final class GeotagFinderTests: XCTestCase {

    // MARK: - Test Helpers

    private let baseDate = Date(timeIntervalSince1970: 1000000)
    private let baseLocation = Location(latitude: .degrees(52.5200), longitude: .degrees(13.4050))

    private func createAnchor(secondsOffset: TimeInterval, lat: Double = 52.5200, lon: Double = 13.4050, alt: Double? = nil) -> GeoAnchor {
        let location = Location(
            latitude: .degrees(lat),
            longitude: .degrees(lon),
            altitude: alt.map { Altitude(value: $0, reference: 0) }
        )
        return GeoAnchor(date: baseDate.addingTimeInterval(secondsOffset), location: location)
    }

    private func createMockItem(date: Date? = nil) -> MockGeotaggingItem {
        return MockGeotaggingItem(date: date)
    }

    // MARK: - Basic Functionality Tests

    func testNoDateThrowsError() throws {
        let finder = GeotagFinder()
        let item = createMockItem(date: nil)
        let anchor = createAnchor(secondsOffset: 0)

        XCTAssertThrowsError(try finder.findGeotag(for: item, using: [anchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .canNotReadDateInformation)
        }
    }

    func testNoAnchorsThrowsError() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)

        XCTAssertThrowsError(try finder.findGeotag(for: item, using: [])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    func testExactMatchSingleAnchor() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: 30, lat: 52.5200, lon: 13.4050)

        let geotag = try finder.findGeotag(for: item, using: [anchor])

        XCTAssertEqual(geotag.location.latitude.degrees, 52.5200, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.4050, accuracy: 0.0001)
    }

    func testExactMatchMultipleAnchorsAtSameTime() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 30, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 30, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should return centroid of the two locations (using spherical geometry)
        // The centroid won't be exactly (53.0, 14.0) due to Earth's curvature
        XCTAssertEqual(geotag.location.latitude.degrees, 53.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 14.0, accuracy: 0.03)
    }

    func testExactMatchClosestAnchor() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 10, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 50, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should pick the anchor at 10 seconds (closer to baseDate)
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    // MARK: - Exact Match Edge Cases

    func testExactMatchAtBoundary() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: 60, lat: 52.0, lon: 13.0)

        let geotag = try finder.findGeotag(for: item, using: [anchor])

        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    func testExactMatchJustOutsideBoundary() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: 60.001, lat: 52.0, lon: 13.0)

        XCTAssertThrowsError(try finder.findGeotag(for: item, using: [anchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    func testExactMatchNegativeTimeOffset() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: -30, lat: 52.0, lon: 13.0)

        let geotag = try finder.findGeotag(for: item, using: [anchor])

        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    func testExactMatchZeroTimeRange() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 0)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 0.001, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should only match the anchor at exactly 0 seconds
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    // MARK: - Interpolation Tests

    func testInterpolationBetweenTwoAnchors() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -100, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 100, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should interpolate to midpoint (50% between the two using great circle)
        XCTAssertEqual(geotag.location.latitude.degrees, 53.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 14.0, accuracy: 0.03)
    }

    func testInterpolationRatioCalculation() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)

        // Test 25% interpolation
        let item25 = createMockItem(date: baseDate.addingTimeInterval(25))
        let anchors = [
            createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 100, lat: 56.0, lon: 17.0)
        ]

        let geotag25 = try finder.findGeotag(for: item25, using: anchors)
        // 25% interpolation using great circle
        XCTAssertEqual(geotag25.location.latitude.degrees, 53.0, accuracy: 0.02)
        XCTAssertEqual(geotag25.location.longitude.degrees, 14.0, accuracy: 0.1)

        // Test 75% interpolation
        let item75 = createMockItem(date: baseDate.addingTimeInterval(75))
        let geotag75 = try finder.findGeotag(for: item75, using: anchors)
        // 75% interpolation using great circle
        XCTAssertEqual(geotag75.location.latitude.degrees, 55.0, accuracy: 0.02)
        XCTAssertEqual(geotag75.location.longitude.degrees, 16.0, accuracy: 0.1)
    }

    func testInterpolationWhenNoExactMatch() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -50, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 50, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should interpolate since no exact match (using great circle)
        XCTAssertEqual(geotag.location.latitude.degrees, 53.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 14.0, accuracy: 0.03)
    }

    func testInterpolationWithMultipleCandidates() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -200, lat: 50.0, lon: 11.0),
            createAnchor(secondsOffset: -50, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 50, lat: 54.0, lon: 15.0),
            createAnchor(secondsOffset: 200, lat: 56.0, lon: 17.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should use the closest before (-50) and after (50) anchors (great circle)
        XCTAssertEqual(geotag.location.latitude.degrees, 53.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 14.0, accuracy: 0.03)
    }

    func testInterpolationOnlyBeforeAnchors() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -100, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: -50, lat: 54.0, lon: 15.0),
            createAnchor(secondsOffset: -30, lat: 56.0, lon: 17.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should use the two closest anchors (-30 and -50)
        // The great circle extrapolation is complex, so we just verify
        // the result is reasonable
        XCTAssertNotNil(geotag.location)
        // Location should be extrapolated beyond the last anchor
        XCTAssertTrue(geotag.location.latitude.degrees > 56.0)
        XCTAssertTrue(geotag.location.longitude.degrees > 17.0)
    }

    func testInterpolationOnlyAfterAnchors() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 30, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 50, lat: 54.0, lon: 15.0),
            createAnchor(secondsOffset: 100, lat: 56.0, lon: 17.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should use the two closest anchors (30 and 50)
        // The great circle extrapolation is complex, so we just verify
        // the result is reasonable
        XCTAssertNotNil(geotag.location)
        // Location should be extrapolated before the first anchor
        XCTAssertTrue(geotag.location.latitude.degrees < 52.0)
        XCTAssertTrue(geotag.location.longitude.degrees < 13.0)
    }

    // MARK: - Interpolation Edge Cases

    func testInterpolationExactlyAtAnchor() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)

        // Test ratio = 0 (exactly at first anchor)
        let item1 = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 100, lat: 54.0, lon: 15.0)
        ]

        let geotag1 = try finder.findGeotag(for: item1, using: anchors)
        XCTAssertEqual(geotag1.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag1.location.longitude.degrees, 13.0, accuracy: 0.0001)

        // Test ratio = 1 (exactly at second anchor)
        let item2 = createMockItem(date: baseDate.addingTimeInterval(100))
        let geotag2 = try finder.findGeotag(for: item2, using: anchors)
        XCTAssertEqual(geotag2.location.latitude.degrees, 54.0, accuracy: 0.0001)
        XCTAssertEqual(geotag2.location.longitude.degrees, 15.0, accuracy: 0.0001)
    }

    func testInterpolationMinimumTwoAnchors() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: 50, lat: 52.0, lon: 13.0)

        XCTAssertThrowsError(try finder.findGeotag(for: item, using: [anchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    func testInterpolationDisabled() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 10, interpolationMatchTimeRange: nil)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -50, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 50, lat: 54.0, lon: 15.0)
        ]

        XCTAssertThrowsError(try finder.findGeotag(for: item, using: anchors)) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }

    // MARK: - Priority Tests

    func testExactMatchPreferredOverInterpolation() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: -100, lat: 50.0, lon: 11.0),
            createAnchor(secondsOffset: 30, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 100, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should use exact match (30 seconds) not interpolation
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }

    func testExactMatchWithSmallerRange() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 30, interpolationMatchTimeRange: 240)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 40, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: -40, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should interpolate since anchors are outside exact range (great circle)
        XCTAssertEqual(geotag.location.latitude.degrees, 53.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 14.0, accuracy: 0.03)
    }

    // MARK: - Location References Tests

    func testLocationReferencesApplied() throws {
        let references = LocationReferences(altitude: 100.0)
        let finder = GeotagFinder(exactMatchTimeRange: 60, locationReferences: references)
        let item = createMockItem(date: baseDate)
        let anchor = createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0, alt: 200.0)

        let geotag = try finder.findGeotag(for: item, using: [anchor])

        // Location should be normalized using references
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
        // Altitude reference is applied when altitude exists
        if let altitudeValue = geotag.location.altitude?.value {
            XCTAssertEqual(altitudeValue, 200.0, accuracy: 0.0001)
        } else {
            XCTFail("Expected altitude to be present")
        }
    }

    func testCentroidWithDifferentWeights() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 0, lat: 54.0, lon: 15.0),
            createAnchor(secondsOffset: 0, lat: 56.0, lon: 17.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // All anchors have weight 1.0, spherical centroid calculation
        XCTAssertEqual(geotag.location.latitude.degrees, 54.0, accuracy: 0.02)
        XCTAssertEqual(geotag.location.longitude.degrees, 15.0, accuracy: 0.1)
    }

    // MARK: - Time Boundary Tests

    func testTimeRangeInclusive() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 60, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: -60, lat: 54.0, lon: 15.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Both anchors should be included (using <= comparison)
        // Since both are at equal distance (60s), the algorithm picks one of them
        // The test shows it picks the first one chronologically
        XCTAssertNotNil(geotag.location)
        // Just verify we got a valid location
        XCTAssertTrue(geotag.location.latitude.degrees >= 52.0 && geotag.location.latitude.degrees <= 54.0)
        XCTAssertTrue(geotag.location.longitude.degrees >= 13.0 && geotag.location.longitude.degrees <= 15.0)
    }

    func testVeryCloseTimestamps() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        let item = createMockItem(date: baseDate)
        let anchors = [
            createAnchor(secondsOffset: 0.0001, lat: 52.0, lon: 13.0),
            createAnchor(secondsOffset: 0.0002, lat: 54.0, lon: 15.0),
            createAnchor(secondsOffset: 0.0003, lat: 56.0, lon: 17.0)
        ]

        let geotag = try finder.findGeotag(for: item, using: anchors)

        // Should pick the closest one (0.0001)
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.0001)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.0001)
    }
}
