//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation

public struct Altitude: Hashable, Sendable {

    public var value: Double
    public var reference: Double

    public init(value: Double, reference: Double) {
        self.value = value
        self.reference = reference
    }
}

extension Altitude {
    public func based(onReferencePoint newReference: Double) -> Altitude {
        let absoluteValue = self.reference + self.value
        return Altitude(value: absoluteValue - newReference, reference: newReference)
    }

    public func zeroBased() -> Altitude {
        return self.based(onReferencePoint: 0)
    }
}
