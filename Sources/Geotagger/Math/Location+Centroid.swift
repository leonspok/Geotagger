//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

func calculateCentroid(of weightedLocations: [(location: Location, weight: Double)]) -> Location {
    let altitudesWithWeights: [(altitude: Double, weight: Double)] = weightedLocations.compactMap { (location, weight) in
        guard let altitude = location.altitude else { return nil }
        return (altitude.based(onReferencePoint: 0).value, weight)
    }
    let centroidAltitude: Double? = {
        guard altitudesWithWeights.isEmpty == false else { return nil }
        let altitudesWeightsSum = altitudesWithWeights.map(\.weight).reduce(0, +)
        return altitudesWithWeights.reduce(0) { (result, altitudeWithWeight) in
            return result + altitudeWithWeight.altitude * altitudeWithWeight.weight / altitudesWeightsSum
        }
    }()

    let weightsSum = weightedLocations.map(\.weight).reduce(0, +)
    let cartesianCentroid: (x: Double, y: Double, z: Double) = weightedLocations.reduce((x: 0, y: 0, z: 0)) { result, weightedLocation in
        let latitudeRads = weightedLocation.location.latitude.radians
        let longitudeRads = weightedLocation.location.longitude.radians
        let weight = weightedLocation.weight / weightsSum

        return (
            x: result.x + cos(latitudeRads) * cos(longitudeRads) * weight,
            y: result.y + cos(latitudeRads) * sin(longitudeRads) * weight,
            z: result.z + sin(latitudeRads) * weight
        )
    }

    let longitudeRads = atan2(cartesianCentroid.y, cartesianCentroid.x)
    let latitudeRads = atan2(cartesianCentroid.z, sqrt(pow(cartesianCentroid.x, 2) + pow(cartesianCentroid.y, 2)))

    return Location(
        latitude: .radians(latitudeRads),
        longitude: .radians(longitudeRads),
        altitude: centroidAltitude.flatMap({ Altitude(value: $0, reference: 0) })
    )
}
