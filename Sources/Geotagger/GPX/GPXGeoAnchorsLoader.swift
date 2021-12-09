//
//  File.swift
//  
//
//  Created by Igor Savelev on 09/12/2021.
//

import Foundation
import CoreGPX

public final class GPXGeoAnchorsLoader: GeoAnchorsLoaderProtocol {

    public init(gpxFileURL: URL) {
        self.gpxFileURL = gpxFileURL
    }
    
    // MARK: - GeoAnchorsLoaderProtocol
    
    public func loadAnchors() throws -> [GeoAnchor] {
        guard let gpxParser = GPXParser(withURL: self.gpxFileURL) else {
            throw GPXError.invalidFile
        }
        guard let gpx = gpxParser.parsedData() else {
            throw GPXError.parsingError
        }
        return gpx.waypoints.compactMap { waypoint in
            return GeoAnchor(gpxWaypoint: waypoint)
        }
    }
    
    // MARK: - Private properties
    
    private let gpxFileURL: URL
}
