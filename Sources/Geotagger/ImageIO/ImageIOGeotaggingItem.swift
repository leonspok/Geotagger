//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public struct ImageIOGeotaggingItem: GeotaggingItemProtocol {
    
    public init(photoURL: URL,
                outputURL: URL,
                imageIOReader: ImageIOReaderProtocol,
                imageIOWriter: ImageIOWriterProtocol,
                timeOffset: TimeInterval? = nil,
                timezoneOverride: String? = nil) {
        self.photoURL = photoURL
        self.outputURL = outputURL
        self.imageIOReader = imageIOReader
        self.imageIOWriter = imageIOWriter
        self.timeOffset = timeOffset
        self.timezoneOverride = timezoneOverride
    }
    
    // MARK: - GeotaggingItemProtocol
    
    public var id: String {
        return self.photoURL.absoluteString
    }
    
    public var date: Date? {
        guard let originalDate = try? self.imageIOReader.readDateFromPhoto(at: self.photoURL) else {
            return nil
        }
        
        if let offset = self.timeOffset {
            return originalDate.addingTimeInterval(offset)
        } else {
            return originalDate
        }
    }
    
    public func skip(with error: Error) {}
    
    public func apply(_ geotag: Geotag) async throws {
        let adjustedDate: Date? = {
            if let offset = self.timeOffset,
               let originalDate = try? self.imageIOReader.readDateFromPhoto(at: self.photoURL) {
                return originalDate.addingTimeInterval(offset)
            }
            return nil
        }()
        
        try self.imageIOWriter.write(geotag, timezoneOverride: self.timezoneOverride, adjustedDate: adjustedDate, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
    }
    
    // MARK: - Public properties
    
    public let timeOffset: TimeInterval?
    public let timezoneOverride: String?
    
    // MARK: - Private properties
    
    private let photoURL: URL
    private let outputURL: URL
    private let imageIOReader: ImageIOReaderProtocol
    private let imageIOWriter: ImageIOWriterProtocol
}
