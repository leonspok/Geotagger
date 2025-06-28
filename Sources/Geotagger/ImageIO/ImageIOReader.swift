//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public protocol ImageIOReaderProtocol: Sendable {
    func readDateFromPhoto(at url: URL) throws -> Date?
    func readGeotagFromPhoto(at url: URL) throws -> Geotag?
    func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor?
}

public struct ImageIOReader: ImageIOReaderProtocol {
    
    public init() {}
    
    // MARK: - ImageIOReaderProtocol
    
    public func readDateFromPhoto(at url: URL) throws -> Date? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageIOError.canNotCreateImageSource
        }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return self.readDateFromMetadata(metadata)
    }
    
    public func readGeotagFromPhoto(at url: URL) throws -> Geotag? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageIOError.canNotCreateImageSource
        }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        return self.readGeotagFromMetadata(metadata)
    }
    
    public func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageIOError.canNotCreateImageSource
        }
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }
        guard let date = self.readDateFromMetadata(metadata),
              let geotag = self.readGeotagFromMetadata(metadata) else {
            return nil
        }
        return GeoAnchor(date: date, location: geotag.location)
    }

    // MARK: - Private methods
    
    private func readDateFromMetadata(_ metadata: [CFString: Any]) -> Date? {
        guard let exifDictionary = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any] else {
            return nil
        }
        
        var dateString: String?
        var timezoneOffset: String?
        
        if let originalDateString = exifDictionary[kCGImagePropertyExifDateTimeOriginal] as? String {
            dateString = originalDateString
            timezoneOffset = exifDictionary[kCGImagePropertyExifOffsetTimeOriginal] as? String
        } else if let digitizedDateString = exifDictionary[kCGImagePropertyExifDateTimeDigitized] as? String {
            dateString = digitizedDateString
            timezoneOffset = exifDictionary[kCGImagePropertyExifOffsetTimeDigitized] as? String
        }
        
        guard let dateStr = dateString else {
            return nil
        }
        
        // Parse the date string using DateFormatter to get a base Date
        guard let baseDate = DateFormatter.exif.date(from: dateStr) else {
            return nil
        }
        
        // If timezone offset is available, recreate the date with proper timezone
        if let offsetString = timezoneOffset,
           let timezone = parseTimezoneOffset(offsetString) {
            // Extract components from the base date and apply the correct timezone
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: baseDate)
            components.timeZone = timezone
            return Calendar.current.date(from: components)
        }
        
        return baseDate
    }
    
    private func parseTimezoneOffset(_ offsetString: String) -> TimeZone? {
        let trimmed = offsetString.trimmingCharacters(in: .whitespaces)
        
        // Handle "Z" for UTC
        if trimmed == "Z" {
            return TimeZone(secondsFromGMT: 0)
        }
        
        // Handle format like "+05:00" or "-08:00"
        let regex = /^([+-])(\d{2}):(\d{2})$/
        guard let match = trimmed.firstMatch(of: regex) else {
            return nil
        }
        
        let sign = String(match.1)
        let hours = Int(match.2) ?? 0
        let minutes = Int(match.3) ?? 0
        
        let totalSeconds = (hours * 3600) + (minutes * 60)
        let offsetSeconds = sign == "+" ? totalSeconds : -totalSeconds
        
        return TimeZone(secondsFromGMT: offsetSeconds)
    }
    
    private func readGeotagFromMetadata(_ metadata: [CFString: Any]) -> Geotag? {
        guard let gpsDictionary = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return nil
        }
        return Geotag(gpsDictionary: gpsDictionary)
    }
}
