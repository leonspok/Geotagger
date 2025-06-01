//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public enum CircularCoordinate: Sendable {
    case degrees(Double)
    case radians(Double)
}

extension CircularCoordinate {
    public var degrees: Double {
        switch self {
        case .degrees(let degrees):
            return degrees
        case .radians(let radians):
            return radians * 180 / .pi
        }
    }
    
    public var radians: Double {
        switch self {
        case .degrees(let degrees):
            return degrees * .pi / 180
        case .radians(let radians):
            return radians
        }
    }
}

extension CircularCoordinate: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.degrees)
    }
}
