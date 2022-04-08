//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation
import Geotagger

struct LoggingGeotaggingItem: GeotaggingItemProtocol {
    
    private let item: GeotaggingItemProtocol
    private let counter: GeotaggingCounter?
    private let verbose: Bool
    
    init(_ item: GeotaggingItemProtocol,
         counter: GeotaggingCounter? = nil,
         verbose: Bool = false) {
        self.item = item
        self.counter = counter
        self.verbose = verbose
    }
    
    // MARK: - GeotaggingItemProtocol
    
    var id: String {
        return self.item.id
    }
    
    var date: Date? {
        return self.item.date
    }
    
    func apply(_ geotag: Geotag) throws {
        try self.item.apply(geotag)
        self.counter?.incrementTagged()
        if self.verbose {
            print("\(self.id): found geotag")
        }
    }
    
    func skip(with error: Error) {
        if self.verbose {
            print("\(self.id): skipped with \(error)")
        }
        self.item.skip(with: error)
        self.counter?.incrementSkipped()
    }
}
