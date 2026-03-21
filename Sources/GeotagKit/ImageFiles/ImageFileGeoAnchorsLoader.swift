//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public final class ImageFileGeoAnchorsLoader: GeoAnchorsLoaderProtocol {

    public init(photoURLs: [URL],
                imageReader: ImageFileReaderProtocol) {
        self.photoURLs = photoURLs
        self.imageReader = imageReader
    }

    // MARK: - GeoAnchorsLoaderProtocol

    public func loadAnchors() throws -> [GeoAnchor] {
        return self.photoURLs.compactMap { url in
            return try? self.imageReader.readGeoAnchorFromPhoto(at: url)
        }
    }

    // MARK: - Private properties

    private let photoURLs: [URL]
    private let imageReader: ImageFileReaderProtocol
}
