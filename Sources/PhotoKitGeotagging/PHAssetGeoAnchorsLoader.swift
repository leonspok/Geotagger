//
//  PHAssetGeoAnchorsLoader.swift
//  
//
//  Created on 06/01/2025.
//

import Foundation
import Photos
import GeotagKit

enum PHAssetLocationMapper {
    static func geotaggerLocation(from location: CLLocation) -> Location {
        let coordinate = location.coordinate

        return Location(
            latitude: .degrees(coordinate.latitude),
            longitude: .degrees(coordinate.longitude),
            altitude: self.altitude(from: location)
        )
    }

    static func altitude(from location: CLLocation) -> Altitude? {
        guard location.verticalAccuracy >= 0 else {
            return nil
        }
        return Altitude(value: location.altitude, reference: 0)
    }
}

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

            return GeoAnchor(
                date: creationDate,
                location: PHAssetLocationMapper.geotaggerLocation(from: location)
            )
        }
    }
}
