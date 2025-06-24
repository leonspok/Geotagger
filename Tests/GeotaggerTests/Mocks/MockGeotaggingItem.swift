//
//  MockGeotaggingItem.swift
//  
//
//  Created on 24/06/2025.
//

import Foundation
@testable import Geotagger

final class MockGeotaggingItem: GeotaggingItemProtocol, @unchecked Sendable {
    let id: String
    let date: Date?
    let timeOffset: TimeInterval?
    let timezoneOverride: String?
    private let lock = NSLock()
    private var _appliedGeotag: Geotag?
    private var _skipError: Error?
    
    var appliedGeotag: Geotag? {
        lock.withLock { _appliedGeotag }
    }
    
    var skipError: Error? {
        lock.withLock { _skipError }
    }
    
    init(id: String = UUID().uuidString, 
         date: Date? = Date(), 
         timeOffset: TimeInterval? = nil, 
         timezoneOverride: String? = nil) {
        self.id = id
        self.date = date
        self.timeOffset = timeOffset
        self.timezoneOverride = timezoneOverride
    }
    
    func apply(_ geotag: Geotag) async throws {
        lock.withLock {
            _appliedGeotag = geotag
        }
    }
    
    func skip(with error: Error) {
        lock.withLock {
            _skipError = error
        }
    }
}