//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public struct ImageIOGeotaggingItem: WritableGeotaggingItemProtocol {

    public init(photoURL: URL,
                outputURL: URL,
                imageIOReader: ImageIOReaderProtocol,
                imageIOWriter: ImageIOWriterProtocol,
                timeOffset: TimeInterval? = nil,
                timezoneOverride: Int? = nil,
                timeAdjustmentSaveMode: TimeAdjustmentSaveMode = .none) {
        self.photoURL = photoURL
        self.outputURL = outputURL
        self.imageIOReader = imageIOReader
        self.imageIOWriter = imageIOWriter
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
        guard timeAdjustmentSaveMode == .all,
              timeOffset != nil || timezoneOverride != nil,
              let adjustedDate = try? self.date else {
            return
        }

        let timezoneString = self.timezoneOverride?.formatAsTimezoneOffset()
        let originalTimezone = try? self.readDateAndTimezone().1

        try self.imageIOWriter.write(
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

            try self.imageIOWriter.write(geotag: geotag, timezoneOverride: timezoneString, originalTimezone: originalTimezone, adjustedDate: adjustedDate, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
        } else {
            try self.imageIOWriter.write(geotag: geotag, timezoneOverride: nil, originalTimezone: nil, adjustedDate: nil, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
        }
    }

    // MARK: - Private properties

    private let photoURL: URL
    private let outputURL: URL
    private let imageIOReader: ImageIOReaderProtocol
    private let imageIOWriter: ImageIOWriterProtocol
    private let timeOffset: TimeInterval?
    private let timezoneOverride: Int? // Seconds from GMT
    private let timeAdjustmentSaveMode: TimeAdjustmentSaveMode

    // MARK: - Private methods

    private func readDateAndTimezone() throws -> (Date?, String?) {
        return try self.imageIOReader.readDateAndTimezoneFromPhoto(at: self.photoURL)
    }

}
