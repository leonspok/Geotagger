//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public final class ImageIOGeoAnchorsLoader: GeoAnchorsLoaderProtocol {

    public init(photoURLs: [URL],
                imageIOReader: ImageIOReaderProtocol) {
        self.photoURLs = photoURLs
        self.imageIOReader = imageIOReader
    }

    // MARK: - GeoAnchorsLoaderProtocol

    public func loadAnchors() throws -> [GeoAnchor] {
        return self.photoURLs.compactMap { url in
            return try? self.imageIOReader.readGeoAnchorFromPhoto(at: url)
        }
    }

    // MARK: - Private properties

    private let photoURLs: [URL]
    private let imageIOReader: ImageIOReaderProtocol
}
