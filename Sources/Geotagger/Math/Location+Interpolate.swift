//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

func calculateInterpolatedLocation(between firstLocation: Location, and secondLocation: Location, ratio: Double) -> Location {
    func interpolate(_ firstValue: Double, and secondValue: Double, ratio: Double) -> Double {
        return firstValue + (secondValue -  firstValue) * ratio
    }
    let altitude: Altitude? = {
        guard let firstAltitude = firstLocation.altitude?.based(onReferencePoint: 0),
              let secondAltitude = secondLocation.altitude?.based(onReferencePoint: 0) else { return nil }
        let value = firstAltitude.value + (secondAltitude.value - firstAltitude.value) * ratio
        return Altitude(value: value, reference: 0)
    }()
    
    let bearing: Double = {
        let dl = secondLocation.longitude.radians - firstLocation.longitude.radians
        let x = cos(secondLocation.latitude.radians) * sin(dl)
        let y = cos(firstLocation.latitude.radians) - sin(firstLocation.latitude.radians) * cos(secondLocation.latitude.radians) * cos(dl)
        return atan2(x, y)
    }()
    
    // Haversine formula
    let angularDistance: Double = {
        let lat1 = firstLocation.latitude.radians
        let lat2 = secondLocation.latitude.radians
        let dLat = lat2 - lat1
        let dLon = secondLocation.longitude.radians - firstLocation.longitude.radians
        let a = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
        return 2 * atan2(sqrt(a), sqrt(1 - a))
    }()
    
    let interpolatedDistance = angularDistance * ratio
    
    let lat1 = firstLocation.latitude.radians
    let lon1 = firstLocation.longitude.radians
    
    let latF = asin(sin(lat1) * cos(interpolatedDistance) + cos(lat1) * sin(interpolatedDistance) * cos(bearing))
    let lonF = lon1 + atan2(sin(bearing) * sin(interpolatedDistance) * cos(lat1), cos(interpolatedDistance) - sin(lat1) * sin(latF))
    
    return Location(
        latitude: .radians(latF),
        longitude: .radians(lonF),
        altitude: altitude
    )
}
