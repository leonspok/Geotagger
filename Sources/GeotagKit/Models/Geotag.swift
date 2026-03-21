//
//  File.swift
//  
//
//  Created by Igor Savelev on 02/12/2021.
//

import Foundation

public struct Geotag: Hashable, Sendable {
    public let location: Location

    public init(location: Location) {
        self.location = location
    }
}
