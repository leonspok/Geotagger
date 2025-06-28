//
//  MockGeotaggingItem.swift
//  
//
//  Created on 24/06/2025.
//

import Foundation
@testable import Geotagger

final class MockGeotaggingItem: WritableGeotaggingItemProtocol, @unchecked Sendable {
    let id: String
    private let _date: Date?
    private let lock = NSLock()
    private var _appliedGeotag: Geotag?
    private var _skipError: Error?
    
    var date: Date? {
        get throws {
            return _date
        }
    }
    
    var appliedGeotag: Geotag? {
        lock.withLock { _appliedGeotag }
    }
    
    var skipError: Error? {
        lock.withLock { _skipError }
    }
    
    init(id: String = UUID().uuidString, 
         date: Date? = Date()) {
        self.id = id
        self._date = date
    }
    
    func apply(_ geotag: Geotag) async throws {
        lock.withLock {
            _appliedGeotag = geotag
        }
    }
    
    func skip(with error: Error) async throws {
        lock.withLock {
            _skipError = error
        }
    }
}