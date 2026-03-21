import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import GeotagKit

final class ImageIOGPSMetadataTests: XCTestCase {

    func testGeotagReaderAppliesSouthernLatitudeReference() throws {
        let geotag = try XCTUnwrap(Geotag(gpsDictionary: [
            kCGImagePropertyGPSLatitude: 33.713525,
            kCGImagePropertyGPSLatitudeRef: "S",
            kCGImagePropertyGPSLongitude: 151.175808,
            kCGImagePropertyGPSLongitudeRef: "E"
        ]))

        XCTAssertEqual(geotag.location.latitude.degrees, -33.713525, accuracy: 0.000001)
        XCTAssertEqual(geotag.location.longitude.degrees, 151.175808, accuracy: 0.000001)
    }

    func testGeotagReaderAppliesWesternLongitudeReference() throws {
        let geotag = try XCTUnwrap(Geotag(gpsDictionary: [
            kCGImagePropertyGPSLatitude: 37.7749,
            kCGImagePropertyGPSLatitudeRef: "N",
            kCGImagePropertyGPSLongitude: 122.4194,
            kCGImagePropertyGPSLongitudeRef: "W"
        ]))

        XCTAssertEqual(geotag.location.latitude.degrees, 37.7749, accuracy: 0.000001)
        XCTAssertEqual(geotag.location.longitude.degrees, -122.4194, accuracy: 0.000001)
    }

    func testImageIOWriterKeepsSouthernLatitudeConsistentAcrossEXIFAndXMP() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let sourceURL = directoryURL.appendingPathComponent("source.jpg")
        let destinationURL = directoryURL.appendingPathComponent("tagged.jpg")
        try self.createTestJPEG(at: sourceURL)

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(-33.713525),
                longitude: .degrees(151.175808),
                altitude: Altitude(value: 189, reference: 0)
            )
        )

        try writer.write(
            geotag: geotag,
            timezoneOverride: nil,
            originalTimezone: nil,
            adjustedDate: nil,
            toPhotoAt: sourceURL,
            saveNewVersionAt: destinationURL
        )

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destinationURL))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, -33.713525, accuracy: 0.0001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, 151.175808, accuracy: 0.0001)

        guard let imageSource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil) else {
            XCTFail("Expected metadata in written image")
            return
        }

        let xmpLatitude = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLatitude" as CFString) as String?
        let xmpLatitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLatitudeRef" as CFString) as String?
        let xmpLongitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLongitudeRef" as CFString) as String?

        XCTAssertEqual(xmpLatitudeRef, "S")
        XCTAssertEqual(xmpLongitudeRef, "E")
        XCTAssertEqual(xmpLatitude?.last, "S")
    }

    func testImageIOWriterKeepsWesternLongitudeConsistentAcrossEXIFAndXMP() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let sourceURL = directoryURL.appendingPathComponent("source.jpg")
        let destinationURL = directoryURL.appendingPathComponent("tagged.jpg")
        try self.createTestJPEG(at: sourceURL)

        let writer = ImageIOWriter()
        let geotag = Geotag(
            location: Location(
                latitude: .degrees(37.7749),
                longitude: .degrees(-122.4194),
                altitude: nil
            )
        )

        try writer.write(
            geotag: geotag,
            timezoneOverride: nil,
            originalTimezone: nil,
            adjustedDate: nil,
            toPhotoAt: sourceURL,
            saveNewVersionAt: destinationURL
        )

        let reader = ImageIOReader()
        let savedGeotag = try XCTUnwrap(reader.readGeotagFromPhoto(at: destinationURL))
        XCTAssertEqual(savedGeotag.location.latitude.degrees, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(savedGeotag.location.longitude.degrees, -122.4194, accuracy: 0.0001)

        guard let imageSource = CGImageSourceCreateWithURL(destinationURL as CFURL, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil) else {
            XCTFail("Expected metadata in written image")
            return
        }

        let xmpLongitude = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLongitude" as CFString) as String?
        let xmpLongitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLongitudeRef" as CFString) as String?
        let xmpLatitudeRef = CGImageMetadataCopyStringValueWithPath(metadata, nil, "exif:GPSLatitudeRef" as CFString) as String?

        XCTAssertEqual(xmpLatitudeRef, "N")
        XCTAssertEqual(xmpLongitudeRef, "W")
        XCTAssertEqual(xmpLongitude?.last, "W")
    }

    private func createTestJPEG(at url: URL) throws {
        let bytes: [UInt8] = [255, 0, 0, 255]
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData),
              let image = CGImage(
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw TestError.failedToCreateImage
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestError.failedToFinalizeImage
        }
    }

    private enum TestError: Error {
        case failedToCreateImage
        case failedToFinalizeImage
    }
}
