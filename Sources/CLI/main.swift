//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation
import Geotagger

let anchorsDirectoryURL = URL(fileURLWithPath: "/Users/igorsavelev/Desktop/iphone")
let targetPhotosDirectoryURL = URL(fileURLWithPath: "/Users/igorsavelev/Desktop/canon")
let outputDirectoryURL = URL(fileURLWithPath: "/Users/igorsavelev/Desktop/output")

let imageIOReader = ImageIOReader()
let imageIOWriter = ImageIOWriter()

let anchorPhotosURLs = try! FileManager.default.contentsOfDirectory(atPath: anchorsDirectoryURL.path).map({ anchorsDirectoryURL.appendingPathComponent($0) })
let anchorsLoader = ImageIOGeoAnchorsLoader(photoURLs: anchorPhotosURLs, imageIOReader: imageIOReader)

let targetPhotosURLs = try! FileManager.default.contentsOfDirectory(atPath: targetPhotosDirectoryURL.path).map({ targetPhotosDirectoryURL.appendingPathComponent($0) })
let geotaggingItems = targetPhotosURLs.map { url in
    return ImageIOGeotaggingItem(
        photoURL: url,
        savePhotoURL: outputDirectoryURL.appendingPathComponent(url.lastPathComponent),
        imageIOReader: imageIOReader,
        imageIOWriter: imageIOWriter
    )
}

let geotagger = Geotagger()
geotagger.exactMatchTolerance = 300
geotagger.interpolationMatchTolerance = 1200

geotagger.anchors = try anchorsLoader.loadAnchors()
geotagger.process(geotaggingItems)


