//
//  File.swift
//  
//
//  Created by Igor Savelev on 02/12/2021.
//

import Foundation

public enum GeotaggingError: Error {
    case canNotReadDateInformation
    case notEnoughGeoAnchorCandidates
}
