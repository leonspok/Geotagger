//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public protocol ImageFileReaderProtocol: Sendable {
    func readDateFromPhoto(at url: URL) throws -> Date?
    func readDateAndTimezoneFromPhoto(at url: URL) throws -> (Date?, String?)
    func readGeotagFromPhoto(at url: URL) throws -> Geotag?
    func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor?
}

public protocol ImageFileWriterProtocol: Sendable {
    func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws
}

public struct ImageFileGeotaggingItem: WritableGeotaggingItemProtocol {

    public init(photoURL: URL,
                outputURL: URL,
                imageReader: ImageFileReaderProtocol,
                imageWriter: ImageFileWriterProtocol,
                timeOffset: TimeInterval? = nil,
                timezoneOverride: Int? = nil,
                timeAdjustmentSaveMode: TimeAdjustmentSaveMode = .none) {
        self.photoURL = photoURL
        self.outputURL = outputURL
        self.imageReader = imageReader
        self.imageWriter = imageWriter
        self.timeOffset = timeOffset
        self.timezoneOverride = timezoneOverride
        self.timeAdjustmentSaveMode = timeAdjustmentSaveMode
    }

    // MARK: - GeotaggingItemProtocol

    public var id: String {
        return self.photoURL.absoluteString
    }

    public var date: Date? {
        get throws {
            let (originalDate, _) = try self.readDateAndTimezone()

            if let originalDate = originalDate, let offset = self.timeOffset {
                return originalDate.addingTimeInterval(offset)
            } else {
                return originalDate
            }
        }
    }

    public func skip(with error: Error) async throws {
        guard self.timeAdjustmentSaveMode == .all,
              self.timeOffset != nil || self.timezoneOverride != nil,
              let adjustedDate = try? self.date else {
            return
        }

        let timezoneString = self.timezoneOverride?.formatAsTimezoneOffset()
        let originalTimezone = try? self.readDateAndTimezone().1

        try self.imageWriter.write(
            geotag: nil,
            timezoneOverride: timezoneString,
            originalTimezone: originalTimezone,
            adjustedDate: adjustedDate,
            toPhotoAt: self.photoURL,
            saveNewVersionAt: self.outputURL
        )
    }

    public func apply(_ geotag: Geotag) async throws {
        let shouldWriteTimeAdjustments = timeAdjustmentSaveMode == .all || timeAdjustmentSaveMode == .tagged

        if shouldWriteTimeAdjustments, let adjustedDate = try? self.date {
            let timezoneString = self.timezoneOverride?.formatAsTimezoneOffset()
            let originalTimezone = try? self.readDateAndTimezone().1

            try self.imageWriter.write(
                geotag: geotag,
                timezoneOverride: timezoneString,
                originalTimezone: originalTimezone,
                adjustedDate: adjustedDate,
                toPhotoAt: self.photoURL,
                saveNewVersionAt: self.outputURL
            )
        } else {
            try self.imageWriter.write(
                geotag: geotag,
                timezoneOverride: nil,
                originalTimezone: nil,
                adjustedDate: nil,
                toPhotoAt: self.photoURL,
                saveNewVersionAt: self.outputURL
            )
        }
    }

    // MARK: - Private properties

    private let photoURL: URL
    private let outputURL: URL
    private let imageReader: ImageFileReaderProtocol
    private let imageWriter: ImageFileWriterProtocol
    private let timeOffset: TimeInterval?
    private let timezoneOverride: Int? // Seconds from GMT
    private let timeAdjustmentSaveMode: TimeAdjustmentSaveMode

    // MARK: - Private methods

    private func readDateAndTimezone() throws -> (Date?, String?) {
        return try self.imageReader.readDateAndTimezoneFromPhoto(at: self.photoURL)
    }

}

// MARK: - Convenience Methods

extension ImageFileWriterProtocol {
    public func write(_ geotag: Geotag, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: nil, originalTimezone: nil, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func write(_ geotag: Geotag, timezoneOverride: String?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: nil, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func write(_ geotag: Geotag, timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: geotag, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }

    public func writeTimeAdjustments(timezoneOverride: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        try write(geotag: nil, timezoneOverride: timezoneOverride, originalTimezone: nil, adjustedDate: adjustedDate, toPhotoAt: sourceURL, saveNewVersionAt: destinationURL)
    }
}
