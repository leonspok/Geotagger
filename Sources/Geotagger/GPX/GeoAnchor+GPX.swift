//
//  File.swift
//  
//
//  Created by Igor Savelev on 09/12/2021.
//

import Foundation
import CoreGPX

extension GeoAnchor {

    // MARK: - Reading

    public init?(gpxWaypoint: GPXWaypoint) {
        guard let time = gpxWaypoint.time,
              let latitude = gpxWaypoint.latitude,
              let longitude = gpxWaypoint.longitude else {
            return nil
        }
        self.init(
            date: time,
            location: Location(
                latitude: .degrees(latitude),
                longitude: .degrees(longitude),
                altitude: {
                    guard let altitudeValue = gpxWaypoint.elevation else {
                        return nil
                    }
                    return Altitude(
                        value: altitudeValue,
                        reference: gpxWaypoint.geoidHeight ?? 0
                    )
                }()
            )
        )
    }
}
