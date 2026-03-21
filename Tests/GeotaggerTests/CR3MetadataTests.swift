import CoreGraphics
import ImageIO
import XCTest

@testable import Geotagger

final class CR3MetadataTests: XCTestCase {

    // MARK: - Test Helpers

    private func resourceURL(_ name: String, subdirectory: String = "CR3") -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources/\(subdirectory)") else {
            fatalError("Missing test resource: Resources/\(subdirectory)/\(name)")
        }
        return url
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func copyResourceToTemporaryDirectory(_ name: String, subdirectory: String = "CR3") throws -> URL {
        let source = resourceURL(name, subdirectory: subdirectory)
        let tempDir = try makeTemporaryDirectory()
        let destination = tempDir.appendingPathComponent(name)
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    // MARK: - Reading Tests

    func testReadDateFromCR3WithoutGPS() throws {
        let url = resourceURL("no_gps.cr3")
        let reader = ImageIOReader()
        let date = try reader.readDateFromPhoto(at: url)
        XCTAssertNotNil(date, "Should be able to read date from CR3 without GPS")
    }

    func testReadDateAndTimezoneFromCR3() throws {
        let url = resourceURL("no_gps.cr3")
        let reader = ImageIOReader()
        let (date, _) = try reader.readDateAndTimezoneFromPhoto(at: url)
        XCTAssertNotNil(date, "Date should be readable from CR3")
        // Timezone may be nil — Canon doesn't always write OffsetTime
    }

    func testReadGPSFromGeotaggedCR3() throws {
        let url = resourceURL("with_gps.cr3")
        let reader = ImageIOReader()
        let geotag = try reader.readGeotagFromPhoto(at: url)
        XCTAssertNotNil(geotag, "Should read GPS from geotagged CR3")

        if let geotag = geotag {
            XCTAssertEqual(geotag.location.latitude.degrees, 60.17, accuracy: 0.01,
                           "Latitude should be approximately 60.17°N")
            XCTAssertEqual(geotag.location.longitude.degrees, 24.95, accuracy: 0.01,
                           "Longitude should be approximately 24.95°E")
        }
    }

    func testReadGPSFromNonGeotaggedCR3ReturnsNil() throws {
        let url = resourceURL("no_gps.cr3")
        let reader = ImageIOReader()
        let geotag = try reader.readGeotagFromPhoto(at: url)
        XCTAssertNil(geotag, "Should return nil for CR3 without GPS")
    }

    func testReadGeoAnchorFromGeotaggedCR3() throws {
        let url = resourceURL("with_gps.cr3")
        let reader = ImageIOReader()
        let anchor = try reader.readGeoAnchorFromPhoto(at: url)
        XCTAssertNotNil(anchor, "Should read GeoAnchor (date + GPS) from geotagged CR3")

        if let anchor = anchor {
            XCTAssertEqual(anchor.location.latitude.degrees, 60.17, accuracy: 0.01)
            XCTAssertEqual(anchor.location.longitude.degrees, 24.95, accuracy: 0.01)
        }
    }

    func testReadGeoAnchorFromNonGeotaggedCR3ReturnsNil() throws {
        let url = resourceURL("no_gps.cr3")
        let reader = ImageIOReader()
        let anchor = try reader.readGeoAnchorFromPhoto(at: url)
        XCTAssertNil(anchor, "Should return nil when GPS is missing")
    }

    // MARK: - Writing GPS Tests (expected to fail until Phase 2)

    func testWriteGPSToCR3AndReadBack() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 60.17, accuracy: 0.001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 24.95, accuracy: 0.001)
    }

    func testWriteGPSWithAltitudeToCR3AndReadBack() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: Altitude(value: 3.1, reference: 0)
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 60.17, accuracy: 0.001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 24.95, accuracy: 0.001)
        XCTAssertNotNil(savedGeotag.location.altitude)
        if let altitude = savedGeotag.location.altitude {
            XCTAssertEqual(altitude.value, 3.1, accuracy: 0.1)
        }
    }

    func testWriteSouthernWesternCoordinatesToCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(-33.713525),
                longitude: .degrees(-122.4194),
                altitude: nil
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, -33.713525, accuracy: 0.0001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, -122.4194, accuracy: 0.0001)
    }

    func testXMPGPSConsistencyAfterCR3Write() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(-33.713525),
                longitude: .degrees(151.175808),
                altitude: nil
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        try verifyXMPGPSConsistency(at: destination)
    }

    private func verifyXMPGPSConsistency(at url: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil) else {
            XCTFail("Expected metadata in written CR3")
            return
        }

        let xmpLatitude = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLatitude" as CFString) as String?
        let xmpLatitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLatitudeRef" as CFString) as String?
        let xmpLongitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLongitudeRef" as CFString) as String?

        XCTAssertEqual(xmpLatitudeRef, "S")
        XCTAssertEqual(xmpLongitudeRef, "E")
        XCTAssertEqual(xmpLatitude?.last, "S")
    }

    func testWriteDoesNotThrowForCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )

        XCTAssertNoThrow(try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination),
                         "Writing GPS to CR3 should not throw")
    }

    func testWrittenCR3OutputFileIsValid() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        let fileExists = FileManager.default.fileExists(atPath: destination.path)
        XCTAssertTrue(fileExists, "Output CR3 file should exist")

        if fileExists {
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            XCTAssertGreaterThan(fileSize, 1024, "Output CR3 should be >1KB")
        }
    }

    func testWriteGPSPreservesOriginalDateInCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tagged.cr3")

        let reader = ImageIOReader()
        let originalDate = try reader.readDateFromPhoto(at: source)
        XCTAssertNotNil(originalDate, "Source CR3 should have a date")

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )

        try writer.write(geotag, toPhotoAt: source, saveNewVersionAt: destination)

        let writtenDate = try reader.readDateFromPhoto(at: destination)
        XCTAssertNotNil(writtenDate, "Written CR3 should still have a date")

        if let originalDate = originalDate, let writtenDate = writtenDate {
            XCTAssertEqual(originalDate.timeIntervalSince1970, writtenDate.timeIntervalSince1970, accuracy: 1.0,
                           "GPS write should not alter the original date")
        }
    }

    func testOverwriteGPSOnCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let tempDir = source.deletingLastPathComponent()
        let firstWrite = tempDir.appendingPathComponent("first.cr3")
        let secondWrite = tempDir.appendingPathComponent("second.cr3")

        let writer = ImageIOWriter()
        let reader = ImageIOReader()

        let firstGeotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )
        try writer.write(firstGeotag, toPhotoAt: source, saveNewVersionAt: firstWrite)

        let secondGeotag = Geotag(
            location: Location(
                latitude: .degrees(48.8566),
                longitude: .degrees(2.3522),
                altitude: nil
            )
        )
        try writer.write(secondGeotag, toPhotoAt: firstWrite, saveNewVersionAt: secondWrite)

        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: secondWrite))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 48.8566, accuracy: 0.001,
                       "Second write should replace first write's latitude")
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 2.3522, accuracy: 0.001,
                       "Second write should replace first write's longitude")
    }

    func testOverwriteExistingGPSInCR3() throws {
        let source = try copyResourceToTemporaryDirectory("with_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("retagged.cr3")

        let writer = ImageIOWriter()
        let newGeotag = Geotag(
            location: Location(
                latitude: .degrees(48.8566),
                longitude: .degrees(2.3522),
                altitude: nil
            )
        )

        try writer.write(newGeotag, toPhotoAt: source, saveNewVersionAt: destination)

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 48.8566, accuracy: 0.001,
                       "New GPS should replace existing GPS latitude")
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 2.3522, accuracy: 0.001,
                       "New GPS should replace existing GPS longitude")
    }

    // MARK: - Timestamp Adjustment Tests (expected to fail until Phase 2)

    func testWriteAdjustedDateToCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("adjusted.cr3")

        let reader = ImageIOReader()
        let originalDate = try XCTUnwrap(reader.readDateFromPhoto(at: source))
        let adjustedDate = originalDate.addingTimeInterval(3600) // +1 hour

        let writer = ImageIOWriter()
        try writer.writeTimeAdjustments(
            timezoneOverride: "+02:00",
            adjustedDate: adjustedDate,
            toPhotoAt: source,
            saveNewVersionAt: destination
        )

        let writtenDate = try XCTUnwrap(reader.readDateFromPhoto(at: destination))
        XCTAssertEqual(writtenDate.timeIntervalSince1970, adjustedDate.timeIntervalSince1970, accuracy: 1.0,
                       "Written date should reflect the +1h adjustment")
    }

    func testWriteTimezoneOverrideToCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("tz.cr3")

        let reader = ImageIOReader()
        let originalDate = try XCTUnwrap(reader.readDateFromPhoto(at: source))

        let writer = ImageIOWriter()
        try writer.write(
            geotag: nil,
            timezoneOverride: "+02:00",
            originalTimezone: nil,
            adjustedDate: originalDate,
            toPhotoAt: source,
            saveNewVersionAt: destination
        )

        let (_, writtenTimezone) = try reader.readDateAndTimezoneFromPhoto(at: destination)
        XCTAssertEqual(writtenTimezone, "+02:00", "Timezone override should be persisted in EXIF OffsetTime")
    }

    func testWriteCombinedGeotagAndTimestampToCR3() throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("combined.cr3")

        let reader = ImageIOReader()
        let originalDate = try XCTUnwrap(reader.readDateFromPhoto(at: source))
        let adjustedDate = originalDate.addingTimeInterval(3600)

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: Altitude(value: 3.1, reference: 0)
            )
        )

        try writer.write(
            geotag: geotag,
            timezoneOverride: "+02:00",
            originalTimezone: nil,
            adjustedDate: adjustedDate,
            toPhotoAt: source,
            saveNewVersionAt: destination
        )

        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 60.17, accuracy: 0.001)

        let (writtenDate, writtenTimezone) = try reader.readDateAndTimezoneFromPhoto(at: destination)
        XCTAssertNotNil(writtenDate)
        XCTAssertEqual(writtenTimezone, "+02:00")
    }

    // MARK: - End-to-End Pipeline Tests (expected to fail until Phase 2)

    func testImageIOGeotaggingItemApplyWithCR3() async throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("pipeline.cr3")

        let reader = ImageIOReader()
        let writer = ImageIOWriter()
        let item = ImageIOGeotaggingItem(
            photoURL: source,
            outputURL: destination,
            imageIOReader: reader,
            imageIOWriter: writer
        )

        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: Altitude(value: 3.1, reference: 0)
            )
        )

        try await item.apply(geotag)

        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 60.17, accuracy: 0.001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 24.95, accuracy: 0.001)
    }

    func testImageIOGeotaggingItemApplyWithTimeAdjustmentsOnCR3() async throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("pipeline_time.cr3")

        let reader = ImageIOReader()
        let writer = ImageIOWriter()
        let item = ImageIOGeotaggingItem(
            photoURL: source,
            outputURL: destination,
            imageIOReader: reader,
            imageIOWriter: writer,
            timeOffset: 3600, // +1 hour
            timezoneOverride: 7200, // +02:00
            timeAdjustmentSaveMode: .tagged
        )

        let geotag = Geotag(
            location: Location(
                latitude: .degrees(60.17),
                longitude: .degrees(24.95),
                altitude: nil
            )
        )

        try await item.apply(geotag)

        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destination))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 60.17, accuracy: 0.001)

        let (_, writtenTimezone) = try reader.readDateAndTimezoneFromPhoto(at: destination)
        XCTAssertEqual(writtenTimezone, "+02:00")
    }

    func testImageIOGeotaggingItemSkipWithTimeAdjustmentsOnCR3() async throws {
        let source = try copyResourceToTemporaryDirectory("no_gps.cr3")
        let destination = source.deletingLastPathComponent().appendingPathComponent("pipeline_skip.cr3")

        let reader = ImageIOReader()
        let writer = ImageIOWriter()
        let item = ImageIOGeotaggingItem(
            photoURL: source,
            outputURL: destination,
            imageIOReader: reader,
            imageIOWriter: writer,
            timeOffset: 3600,
            timezoneOverride: 7200,
            timeAdjustmentSaveMode: .all
        )

        // skip() with .all mode should still write time adjustments
        try await item.skip(with: ImageIOError.canNotCreateImageDestination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path),
                      "skip() with .all mode should produce output file")

        let (_, writtenTimezone) = try reader.readDateAndTimezoneFromPhoto(at: destination)
        XCTAssertEqual(writtenTimezone, "+02:00")
    }

    func testCR3AsGeoAnchorSource() throws {
        let url = resourceURL("with_gps.cr3")
        let reader = ImageIOReader()
        let loader = ImageIOGeoAnchorsLoader(photoURLs: [url], imageIOReader: reader)
        let anchors = try loader.loadAnchors()

        XCTAssertEqual(anchors.count, 1, "Should load exactly one anchor from geotagged CR3")

        if let anchor = anchors.first {
            XCTAssertEqual(anchor.location.latitude.degrees, 60.17, accuracy: 0.01)
            XCTAssertEqual(anchor.location.longitude.degrees, 24.95, accuracy: 0.01)
        }
    }

}
