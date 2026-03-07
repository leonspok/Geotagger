import XCTest
import CoreLocation
@testable import Geotagger
@testable import PhotoKitGeotagger

final class PhotoKitMetadataTests: XCTestCase {

    func testPHAssetLoaderPreservesZeroAltitudeWhenVerticalAccuracyIsValid() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -33.713525, longitude: 151.175808),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        )

        let mapped = PHAssetLocationMapper.geotaggerLocation(from: location)

        XCTAssertEqual(mapped.latitude.degrees, -33.713525, accuracy: 0.000001)
        XCTAssertEqual(mapped.longitude.degrees, 151.175808, accuracy: 0.000001)
        XCTAssertEqual(mapped.altitude?.value ?? .nan, 0, accuracy: 0.000001)
    }

    func testPHAssetLoaderDropsAltitudeWhenVerticalAccuracyIsInvalid() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -33.713525, longitude: 151.175808),
            altitude: 123,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        )

        let mapped = PHAssetLocationMapper.geotaggerLocation(from: location)

        XCTAssertNil(mapped.altitude)
    }

    func testPHAssetWriterMarksMissingAltitudeAsInvalid() {
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(37.7749),
                longitude: .degrees(-122.4194),
                altitude: nil
            )
        )

        let location = PHAssetLocationBuilder.phAssetLocation(
            from: geotag,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        )

        XCTAssertEqual(location.coordinate.latitude, 37.7749, accuracy: 0.000001)
        XCTAssertEqual(location.coordinate.longitude, -122.4194, accuracy: 0.000001)
        XCTAssertEqual(location.altitude, 0, accuracy: 0.000001)
        XCTAssertLessThan(location.verticalAccuracy, 0)
    }

    func testPHAssetWriterPreservesExplicitZeroAltitude() {
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(37.7749),
                longitude: .degrees(-122.4194),
                altitude: Altitude(value: 0, reference: 0)
            )
        )

        let location = PHAssetLocationBuilder.phAssetLocation(
            from: geotag,
            timestamp: Date(timeIntervalSince1970: 1_000_000)
        )

        XCTAssertEqual(location.altitude, 0, accuracy: 0.000001)
        XCTAssertGreaterThanOrEqual(location.verticalAccuracy, 0)
    }
}
