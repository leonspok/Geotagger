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
        guard let originalDate = try? self.imageIOReader.readDateFromPhoto(at: self.photoURL) else {
            return nil
        }
        
        if let offset = self.timeOffset {
            return originalDate.addingTimeInterval(offset)
        } else {
            return originalDate
        }
    }
    
    public func skip(with error: Error) {
        guard timeAdjustmentSaveMode == .all,
              (timeOffset != nil || timezoneOverride != nil) else {
            return
        }
        
        Task {
            do {
                let adjustedDate: Date? = {
                    if let offset = self.timeOffset,
                       let originalDate = try? self.imageIOReader.readDateFromPhoto(at: self.photoURL) {
                        return originalDate.addingTimeInterval(offset)
                    }
                    return nil
                }()
                
                let timezoneString = self.timezoneOverride.map { self.formatTimezoneOffset($0) }
                
                try await self.imageIOWriter.writeTimeAdjustments(
                    timezoneOverride: timezoneString,
                    adjustedDate: adjustedDate,
                    toPhotoAt: self.photoURL,
                    saveNewVersionAt: self.outputURL
                )
            } catch {
                // Silently fail when unable to write time adjustments
            }
        }
    }
    
    public func apply(_ geotag: Geotag) async throws {
        let shouldWriteTimeAdjustments = timeAdjustmentSaveMode == .all || timeAdjustmentSaveMode == .tagged
        
        if shouldWriteTimeAdjustments {
            let adjustedDate: Date? = {
                if let offset = self.timeOffset,
                   let originalDate = try? self.imageIOReader.readDateFromPhoto(at: self.photoURL) {
                    return originalDate.addingTimeInterval(offset)
                }
                return nil
            }()
            
            let timezoneString = self.timezoneOverride.map { self.formatTimezoneOffset($0) }
            
            try self.imageIOWriter.write(geotag, timezoneOverride: timezoneString, adjustedDate: adjustedDate, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
        } else {
            try self.imageIOWriter.write(geotag, toPhotoAt: self.photoURL, saveNewVersionAt: self.outputURL)
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
    
    private func formatTimezoneOffset(_ seconds: Int) -> String {
        if seconds == 0 {
            return "Z"
        }
        
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }
}
