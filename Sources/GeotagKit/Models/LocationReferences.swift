//
//  File.swift
//  
//
//  Created by Igor Savelev on 02/12/2021.
//

import Foundation

public struct LocationReferences: Sendable {
    public let altitude: Double

    public init(altitude: Double = 0) {
        self.altitude = altitude
    }
}
