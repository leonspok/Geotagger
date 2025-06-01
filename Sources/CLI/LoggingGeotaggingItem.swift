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
    
    func apply(_ geotag: Geotag) async throws {
        try await self.item.apply(geotag)
        self.logApplication()
    }
    
    func skip(with error: Error) {
        self.item.skip(with: error)
        self.logSkip(with: error)
    }

    // MARK: - Private methods

    private func logApplication() {
        Task { @MainActor in
            self.counter?.incrementTagged()
            if self.verbose {
                print("\(self.id): found geotag")
            }
        }
    }

    private func logSkip(with error: Error) {
        Task { @MainActor in
            if self.verbose {
                print("\(self.id): skipped with \(error)")
            }
            self.counter?.incrementSkipped()
        }
    }
}
