//
//  CombinedImageFileWriter.swift
//  Geotagger
//
//  Created by Igor Savelev on 21/03/2026.
//

import Foundation

public struct CombinedImageFileWriter: ImageFileWriterProtocol {

    public init() {}

    // MARK: - ImageFileWriterProtocol

    public func write(
        geotag: Geotag?,
        timezoneOverride: String?,
        originalTimezone: String?,
        adjustedDate: Date?,
        toPhotoAt sourceURL: URL,
        saveNewVersionAt destinationURL: URL
    ) throws {
        let writer = writer(for: destinationURL)
        try writer.write(
            geotag: geotag,
            timezoneOverride: timezoneOverride,
            originalTimezone: originalTimezone,
            adjustedDate: adjustedDate,
            toPhotoAt: sourceURL,
            saveNewVersionAt: destinationURL
        )
    }

    // MARK: - Private properties

    private let imageIOWriter = ImageIOWriter()
    private let cr3Writer = CR3MetadataWriter()

    // MARK: - Private methods

    private func writer(for url: URL) -> ImageFileWriterProtocol {
        if url.pathExtension.lowercased() == "cr3" {
            return self.cr3Writer
        } else {
            return self.imageIOWriter
        }
    }
}
