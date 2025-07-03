//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public protocol ImageIOWriterProtocol: Sendable {
    func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws
}

public struct ImageIOWriter: ImageIOWriterProtocol {

    public init() {}

    // MARK: - ImageIOWriterProtocol

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
                formatter.timeZone = parseTimezoneOverride(timezone)
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

// MARK: - Convenience Methods
extension ImageIOWriterProtocol {
    public func write(_ geotag: Geotag, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: nil, originalTimezone: nil, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func write(_ geotag: Geotag, timezoneOverride: String?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func write(_ geotag: Geotag, timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func writeTimeAdjustments(timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: nil, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }
}

// MARK: - Private Methods
extension ImageIOWriter {
    private func isValidTimezoneOffset(_ timezone: String) -> Bool {
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

    private func parseTimezoneOverride(_ timezoneString: String) -> TimeZone? {
        // Handle "Z" for UTC
        if timezoneString == "Z" {
            return TimeZone(secondsFromGMT: 0)
        }

        // Handle format like "+05:00" or "-08:00"
        let pattern = /^([+-])(\d{2}):(\d{2})$/
        guard let match = timezoneString.firstMatch(of: pattern) else {
            return nil
        }

        let sign = String(match.1)
        let hours = Int(match.2) ?? 0
        let minutes = Int(match.3) ?? 0

        let totalSeconds = (hours * 3600) + (minutes * 60)
        let offsetSeconds = sign == "+" ? totalSeconds : -totalSeconds

        return TimeZone(secondsFromGMT: offsetSeconds)
    }
}
