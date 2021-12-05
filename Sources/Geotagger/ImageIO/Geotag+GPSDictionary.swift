//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

extension Geotag {
    
    // MARK: - Reading
    
    public init?(gpsDictionary: [CFString: Any]) {
        guard let longitude = Self.readLongitude(from: gpsDictionary),
              let latitude = Self.readLatitude(from: gpsDictionary) else {
            return nil
        }
        self.init(
            location: Location(
                latitude: latitude,
                longitude: longitude,
                altitude: Self.readAltitude(from: gpsDictionary)
            )
        )
    }
    
    private static func readLongitude(from gpsDictionary: [CFString: Any]) -> CircularCoordinate? {
        guard let value = (gpsDictionary[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue else {
            return nil
        }
        if let reference = gpsDictionary[kCGImagePropertyGPSLongitudeRef] as? String,
           reference.lowercased() == "w" {
            return .degrees(value * (-1))
        }
        return .degrees(value)
    }
    
    private static func readLatitude(from gpsDictionary: [CFString: Any]) -> CircularCoordinate? {
        guard let value = (gpsDictionary[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue else {
            return nil
        }
        return .degrees(value)
    }
    
    private static func readAltitude(from gpsDictionary: [CFString: Any]) -> Altitude? {
        guard let value = (gpsDictionary[kCGImagePropertyGPSAltitude] as? NSNumber)?.doubleValue else {
            return nil
        }
        return Altitude(
            value: value,
            reference: (gpsDictionary[kCGImagePropertyGPSAltitudeRef] as? NSNumber)?.doubleValue ?? 0
        )
    }
    
    // MARK: - Writing
    
    public var asGPSDictionary: [CFString: Any] {
        var dictionary: [CFString: Any] = [
            kCGImagePropertyGPSLatitude: abs(self.location.latitude.degrees) as NSNumber,
            kCGImagePropertyGPSLatitudeRef: self.location.latitude.degrees < 0 ? "S" : "N",
            kCGImagePropertyGPSLongitude: abs(self.location.longitude.degrees) as NSNumber,
            kCGImagePropertyGPSLongitudeRef: self.location.longitude.degrees < 0 ? "W" : "E"
        ]
        if let altitude = self.location.altitude {
            dictionary[kCGImagePropertyGPSAltitude] = altitude.value as NSNumber
            dictionary[kCGImagePropertyGPSAltitudeRef] = altitude.reference as NSNumber
        }
        return dictionary
    }
}
