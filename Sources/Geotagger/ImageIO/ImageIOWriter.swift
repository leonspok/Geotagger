//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public protocol ImageIOWriterProtocol: Sendable {
    func write(geotag: Geotag?, timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws
}

public struct ImageIOWriter: ImageIOWriterProtocol {
    
    public init() {}
    
    // MARK: - ImageIOWriterProtocol
    
    public func write(geotag: Geotag?, timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
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
        
        // Apply timezone override to EXIF metadata
        if let timezoneOverride = timezoneOverride, isValidTimezoneOffset(timezoneOverride) {
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTime, timezoneOverride as CFTypeRef)
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTimeOriginal, timezoneOverride as CFTypeRef)
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifOffsetTimeDigitized, timezoneOverride as CFTypeRef)
        }
        
        // Update EXIF date fields if adjusted date is provided
        if let adjustedDate = adjustedDate {
            let dateString = DateFormatter.exif.string(from: adjustedDate)
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
extension ImageIOWriter {
    public func write(_ geotag: Geotag, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: nil, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }
    
    public func write(_ geotag: Geotag, timezoneOverride: String?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }
    
    public func write(_ geotag: Geotag, timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }
    
    public func writeTimeAdjustments(timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: nil, timezoneOverride: timezoneOverride, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
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
}
