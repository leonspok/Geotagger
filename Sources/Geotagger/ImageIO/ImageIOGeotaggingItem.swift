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
                imageIOWriter: ImageIOWriterProtocol) {
        self.photoURL = photoURL
        self.outputURL = outputURL
        self.imageIOReader = imageIOReader
        self.imageIOWriter = imageIOWriter
    }
    
    // MARK: - GeotaggingItemProtocol
    
    public var id: String {
        return self.photoURL.absoluteString
    }
    
    public var date: Date? {
        return try? self.imageIOReader.readDateFromPhoto(at: self.photoURL)
    }
    
    public func skip(with error: Error) {}
    
    public func apply(_ geotag: Geotag) async throws {
        try self.imageIOWriter.write(geotag, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
    }
    
    // MARK: - Private properties
    
    private let photoURL: URL
    private let outputURL: URL
    private let imageIOReader: ImageIOReaderProtocol
    private let imageIOWriter: ImageIOWriterProtocol
}
