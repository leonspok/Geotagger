//
//  TimeZoneParser.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation
import GeotagKit
import ArgumentParser

extension TimeAdjustmentSaveMode: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }

    public static var allValueStrings: [String] {
        return allCases.map(\.rawValue)
    }
}
