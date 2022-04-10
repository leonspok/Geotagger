//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation

public struct Location: Hashable {
    
    public var latitude: CircularCoordinate
    public var longitude: CircularCoordinate
    public var altitude: Altitude?
    
    var debugInfo: String {
        return [
            "lat=\(self.latitude.degrees)",
            "lon=\(self.longitude.degrees)",
            (self.altitude != nil ? "alt=\(self.altitude!.value)" : nil)
        ].compactMap({ $0 }).joined(separator: ",")
    }
    
    public init(latitude: CircularCoordinate,
                longitude: CircularCoordinate,
                altitude: Altitude? = nil) {
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
    }
}

extension Location {
    public func based(on references: LocationReferences) -> Location {
        return Location(
            latitude: self.latitude,
            longitude: self.longitude,
            altitude: self.altitude?.based(onReferencePoint: references.altitude)
        )
    }
}

