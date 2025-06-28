//
//  TimezoneAwareMockImageIOReader.swift
//  
//
//  Created on 28/06/2025.
//

import Foundation
@testable import Geotagger

final class TimezoneAwareMockImageIOReader: @unchecked Sendable, ImageIOReaderProtocol {
    
    private let datesByURL: [URL: Date]
    private let geotagsByURL: [URL: Geotag]
    
    init(datesByURL: [URL: Date] = [:], geotagsByURL: [URL: Geotag] = [:]) {
        self.datesByURL = datesByURL
        self.geotagsByURL = geotagsByURL
    }
    
    func readDateFromPhoto(at url: URL) throws -> Date? {
        return self.datesByURL[url]
    }
    
    func readGeotagFromPhoto(at url: URL) throws -> Geotag? {
        return self.geotagsByURL[url]
    }
    
    func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor? {
        guard let date = self.datesByURL[url],
              let geotag = self.geotagsByURL[url] else {
            return nil
        }
        return GeoAnchor(date: date, location: geotag.location)
    }
}