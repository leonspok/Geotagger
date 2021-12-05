//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public protocol ImageIOReaderProtocol {
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
        if let dateString = exifDictionary[kCGImagePropertyExifDateTimeOriginal] as? String {
            return DateFormatter.exif.date(from: dateString)
        } else if let dateString = exifDictionary[kCGImagePropertyExifDateTimeDigitized] as? String {
            return DateFormatter.exif.date(from: dateString)
        } else {
            return nil
        }
    }
    
    private func readGeotagFromMetadata(_ metadata: [CFString: Any]) -> Geotag? {
        guard let gpsDictionary = metadata[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return nil
        }
        return Geotag(gpsDictionary: gpsDictionary)
    }
}
