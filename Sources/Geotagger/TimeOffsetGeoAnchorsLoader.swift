//
//  TimeOffsetGeoAnchorsLoader.swift
//  
//
//  Created on 24/06/2025.
//

import Foundation

public final class TimeOffsetGeoAnchorsLoader: GeoAnchorsLoaderProtocol {
    
    public init(wrapping loader: GeoAnchorsLoaderProtocol, timeOffset: TimeInterval) {
        self.wrappedLoader = loader
        self.timeOffset = timeOffset
    }
    
    // MARK: - GeoAnchorsLoaderProtocol
    
    public func loadAnchors() throws -> [GeoAnchor] {
        let originalAnchors = try wrappedLoader.loadAnchors()
        return originalAnchors.map { anchor in
            GeoAnchor(
                date: anchor.date.addingTimeInterval(self.timeOffset),
                location: anchor.location
            )
        }
    }
    
    // MARK: - Private properties
    
    private let wrappedLoader: GeoAnchorsLoaderProtocol
    private let timeOffset: TimeInterval
}
