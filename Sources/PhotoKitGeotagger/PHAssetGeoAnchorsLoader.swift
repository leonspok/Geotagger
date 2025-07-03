//
//  PHAssetGeoAnchorsLoader.swift
//  
//
//  Created on 06/01/2025.
//

import Foundation
import Photos
import Geotagger

public class PHAssetGeoAnchorsLoader: GeoAnchorsLoaderProtocol {
    // MARK: - Private properties

    private let assets: [PHAsset]

    // MARK: - Public API

    public init(assets: [PHAsset]) {
        self.assets = assets
    }

    // MARK: - GeoAnchorsLoaderProtocol

    public func loadAnchors() throws -> [GeoAnchor] {
        return self.assets.compactMap { asset -> GeoAnchor? in
            guard let location = asset.location,
                  let creationDate = asset.creationDate else {
                return nil
            }

            let coordinate = location.coordinate
            let altitude = location.altitude != 0 ? Altitude(value: location.altitude, reference: 0) : nil

            let geoLocation = Location(
                latitude: CircularCoordinate.degrees(coordinate.latitude),
                longitude: CircularCoordinate.degrees(coordinate.longitude),
                altitude: altitude
            )

            return GeoAnchor(
                date: creationDate,
                location: geoLocation
            )
        }
    }
}
