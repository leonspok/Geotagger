//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation
import Geotagger

extension Geotagger {
    func loadAnchorsFromGPXFiles(at urls: [URL], timeOffset: TimeInterval? = nil) throws {
        try urls.forEach { url in
            let loader = GPXGeoAnchorsLoader(gpxFileURL: url)
            if let timeOffset = timeOffset {
                try self.loadAnchors(with: TimeOffsetGeoAnchorsLoader(wrapping: loader, timeOffset: timeOffset))
            } else {
                try self.loadAnchors(with: loader)
            }
        }
    }

    func loadAnchorsFromGPXFilesFromDirectory(_ directoryURL: URL,
                                              scanSubdirectories: Bool = false,
                                              timeOffset: TimeInterval? = nil) throws {
        let directoryScanner = DirectoryScanner()
        let gpxURLs = try directoryScanner.scanContents(of: directoryURL, recursive: scanSubdirectories, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles])
            .filter(\.isGPXFileURL)
        try self.loadAnchorsFromGPXFiles(at: gpxURLs, timeOffset: timeOffset)
    }

    func loadAnchorsFromPhotos(at urls: [URL], timeOffset: TimeInterval? = nil) throws {
        let imageReader = ImageIOReader()
        let imagesAnchorsLoader = ImageIOGeoAnchorsLoader(photoURLs: urls, imageIOReader: imageReader)
        if let timeOffset = timeOffset {
            try self.loadAnchors(with: TimeOffsetGeoAnchorsLoader(wrapping: imagesAnchorsLoader, timeOffset: timeOffset))
        } else {
            try self.loadAnchors(with: imagesAnchorsLoader)
        }
    }

    func loadAnchorsFromPhotosFromDirectoryAt(_ directoryURL: URL,
                                              scanSubdirectories: Bool = false,
                                              timeOffset: TimeInterval? = nil) throws {
        let directoryScanner = DirectoryScanner()
        let photoURLs = try directoryScanner.scanContents(of: directoryURL, recursive: scanSubdirectories, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles])
            .filter(\.isPhotoFileURL)
        try self.loadAnchorsFromPhotos(at: photoURLs, timeOffset: timeOffset)
    }
}

extension Geotagger {
    typealias SaveToClosure = (URL) -> URL

    func tagPhotos(at urls: [URL],
                   includeAlreadyTagged: Bool = false,
                   counter: GeotaggingCounter? = nil,
                   verbose: Bool = false,
                   photoTimeOffset: TimeInterval? = nil,
                   timezoneOverride: Int? = nil,
                   timeAdjustmentSaveMode: TimeAdjustmentSaveMode = .none,
                   saveTo: @escaping SaveToClosure = { $0 }) async throws {
        let imageReader = ImageIOReader()
        let imageWriter = ImageIOWriter()
        let geotaggingItems = try urls.compactMap { url -> WritableGeotaggingItemProtocol? in
            if verbose {
                print("Loading \(url.lastPathComponent)...")
            }
            if includeAlreadyTagged == false,
               (try imageReader.readGeotagFromPhoto(at: url)) != nil {
                return nil
            }
            let imageItem = ImageIOGeotaggingItem(
                photoURL: url,
                outputURL: saveTo(url),
                imageIOReader: imageReader,
                imageIOWriter: imageWriter,
                timeOffset: photoTimeOffset,
                timezoneOverride: timezoneOverride,
                timeAdjustmentSaveMode: timeAdjustmentSaveMode
            )
            return LoggingGeotaggingItem(imageItem, counter: counter, verbose: verbose)
        }
        print("Found \(geotaggingItems.count) items to tag")
        try await self.tag(geotaggingItems)
    }

    func tagPhotosInDirectoryAt(_ directoryURL: URL,
                                scanSubdirectories: Bool = false,
                                outputDirectoryURL: URL? = nil,
                                includeAlreadyTagged: Bool = false,
                                counter: GeotaggingCounter? = nil,
                                verbose: Bool = false,
                                photoTimeOffset: TimeInterval? = nil,
                                timezoneOverride: Int? = nil,
                                timeAdjustmentSaveMode: TimeAdjustmentSaveMode = .none) async throws {
        let directoryScanner = DirectoryScanner()
        let photoURLs = try directoryScanner.scanContents(of: directoryURL, recursive: scanSubdirectories, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles])
            .filter(\.isPhotoFileURL)
        try await self.tagPhotos(
            at: photoURLs,
            includeAlreadyTagged: includeAlreadyTagged,
            counter: counter,
            verbose: verbose,
            photoTimeOffset: photoTimeOffset,
            timezoneOverride: timezoneOverride,
            timeAdjustmentSaveMode: timeAdjustmentSaveMode,
            saveTo: { photoURL in
                guard let outputDirectoryURL = outputDirectoryURL else {
                    return photoURL
                }
                let relativePathComponents: [String] = {
                    var url = photoURL.absoluteURL
                    var components: [String] = []
                    while url != directoryURL.absoluteURL,
                          url.lastPathComponent.isEmpty == false,
                          url.lastPathComponent != "/" {
                        components.append(url.lastPathComponent)
                        url.deleteLastPathComponent()
                    }
                    return components
                }()
                return relativePathComponents
                    .reversed()
                    .reduce(outputDirectoryURL) { partialResult, pathComponent in
                        return partialResult.appendingPathComponent(pathComponent)
                    }
            }
        )
    }
}
