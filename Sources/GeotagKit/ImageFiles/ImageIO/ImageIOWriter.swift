//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public struct ImageIOWriter: ImageFileWriterProtocol {

    public init() {}

    // MARK: - FileWriterProtocol

    public func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        let didAccessSource = sourceURL.startAccessingSecurityScopedResource()
        let didAccessDestination = destinationURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            if didAccessDestination {
                destinationURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceUTType = CGImageSourceGetType(imageSource) else {
            throw ImageIOError.canNotCreateImageSource
        }

        let mutableMetadata: CGMutableImageMetadata = {
            if let originalMetadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil),
               let mutableCopy = CGImageMetadataCreateMutableCopy(originalMetadata) {
                return mutableCopy
            } else {
                return CGImageMetadataCreateMutable()
            }
        }()

        // Write GPS data if geotag is provided
        if let geotag = geotag {
            for (key, value) in geotag.asGPSDictionary {
                CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyGPSDictionary, key, value as CFTypeRef)
            }
            self.synchronizeXMPGPSMetadata(for: geotag, in: mutableMetadata)
        }

        // Apply timezone to EXIF metadata - priority: timezoneOverride > originalTimezone
        let timezoneToWrite = timezoneOverride ?? originalTimezone
        if let timezone = timezoneToWrite, isValidTimezoneOffset(timezone) {
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTime, timezone as CFTypeRef)
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTimeOriginal, timezone as CFTypeRef)
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTimeDigitized, timezone as CFTypeRef)
        }

        // Update EXIF date fields if adjusted date is provided
        if let adjustedDate = adjustedDate {
            let dateString: String

            // Format date with timezone - priority: timezoneOverride > originalTimezone > system timezone
            if let timezone = timezoneToWrite, isValidTimezoneOffset(timezone) {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                formatter.timeZone = parseTimezoneOffset(timezone)
                dateString = formatter.string(from: adjustedDate)
            } else {
                // Fall back to system timezone formatting when no timezone info available
                dateString = DateFormatter.exif.string(from: adjustedDate)
            }

            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal, dateString as CFTypeRef)
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeDigitized, dateString as CFTypeRef)
        }

        let directoryURL = destinationURL.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: directoryURL.path) == false {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        guard let imageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, sourceUTType, 1, nil) else {
            throw ImageIOError.canNotCreateImageDestination
        }

        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: mutableMetadata,
            kCGImageDestinationMergeMetadata: true
        ]
        CGImageDestinationCopyImageSource(imageDestination, imageSource, options as CFDictionary, nil)
    }

}

// MARK: - Private Methods
extension ImageIOWriter {
    private func synchronizeXMPGPSMetadata(for geotag: Geotag, in metadata: CGMutableImageMetadata) {
        let latitude = geotag.location.latitude.degrees
        let longitude = geotag.location.longitude.degrees

        // ImageIO also emits XMP-exif GPS tags. For southern latitudes it serializes
        // the coordinate string with an "N" suffix, which conflicts with the ref tag
        // and confuses downstream apps. Overwrite the XMP GPS fields explicitly.
        CGImageMetadataSetValueWithPath(metadata, nil, "exif:GPSLatitude" as CFString, self.xmpGPSCoordinateString(for: latitude, positiveDirection: "N", negativeDirection: "S") as CFTypeRef)
        CGImageMetadataSetValueWithPath(metadata, nil, "exif:GPSLatitudeRef" as CFString, (latitude < 0 ? "S" : "N") as CFTypeRef)
        CGImageMetadataSetValueWithPath(metadata, nil, "exif:GPSLongitude" as CFString, self.xmpGPSCoordinateString(for: longitude, positiveDirection: "E", negativeDirection: "W") as CFTypeRef)
        CGImageMetadataSetValueWithPath(metadata, nil, "exif:GPSLongitudeRef" as CFString, (longitude < 0 ? "W" : "E") as CFTypeRef)
    }

    private func xmpGPSCoordinateString(for value: Double, positiveDirection: String, negativeDirection: String) -> String {
        let absoluteValue = abs(value)
        let degrees = Int(absoluteValue.rounded(.down))
        let minutes = (absoluteValue - Double(degrees)) * 60
        let direction = value < 0 ? negativeDirection : positiveDirection
        return String(format: "%d,%.7f%@",
                      locale: Locale(identifier: "en_US_POSIX"),
                      degrees,
                      minutes,
                      direction)
    }
}
