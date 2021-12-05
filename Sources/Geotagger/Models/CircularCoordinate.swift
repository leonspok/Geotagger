//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public enum CircularCoordinate {
    case degrees(Double)
    case radians(Double)
}

extension CircularCoordinate {
    var degrees: Double {
        switch self {
        case .degrees(let degrees):
            return degrees
        case .radians(let radians):
            return radians * 180 / .pi
        }
    }
    
    var radians: Double {
        switch self {
        case .degrees(let degrees):
            return degrees * .pi / 180
        case .radians(let radians):
            return radians
        }
    }
}
