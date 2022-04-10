//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation

public struct GeoAnchor: Hashable {
    public let date: Date
    public let location: Location
    
    public init(date: Date,
                location: Location) {
        self.date = date
        self.location = location
    }
}
