//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public struct ImageIOGeotaggingItem: GeotaggingItemProtocol {
    
    public init(photoURL: URL,
                savePhotoURL: URL,
                imageIOReader: ImageIOReaderProtocol,
                imageIOWriter: ImageIOWriterProtocol) {
        self.photoURL = photoURL
        self.savePhotoURL = savePhotoURL
        self.imageIOReader = imageIOReader
        self.imageIOWriter = imageIOWriter
    }
    
    // MARK: - GeotaggingItemProtocol
    
    public var date: Date? {
        return try? self.imageIOReader.readDateFromPhoto(at: self.photoURL)
    }
    
    public func skip(with error: Error) {
        print("\(self.photoURL) skipped: \(error)")
    }
    
    public func apply(_ geotag: Geotag) throws {
        try self.imageIOWriter.write(geotag, toPhotoAt: self.photoURL, saveNewVersionAt: self.savePhotoURL)
    }
    
    // MARK: - Private properties
    
    private let photoURL: URL
    private let savePhotoURL: URL
    private let imageIOReader: ImageIOReaderProtocol
    private let imageIOWriter: ImageIOWriterProtocol
}
