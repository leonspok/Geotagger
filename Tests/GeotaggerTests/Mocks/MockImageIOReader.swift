//
//  MockImageIOReader.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation
@testable import Geotagger

final class MockImageIOReader: @unchecked Sendable, ImageIOReaderProtocol {
    func readDateFromPhoto(at url: URL) throws -> Date? {
        return Date()
    }

    func readDateAndTimezoneFromPhoto(at url: URL) throws -> (Date?, String?) {
        return (Date(), nil)
    }

    func readGeotagFromPhoto(at url: URL) throws -> Geotag? {
        return nil
    }

    func readGeoAnchorFromPhoto(at url: URL) throws -> GeoAnchor? {
        return nil
    }
}
