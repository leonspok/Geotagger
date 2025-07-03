//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation
import os

final class GeotaggingCounter: @unchecked Sendable {
    var tagged: UInt {
        return self._tagged.withLock { $0 }
    }

    var skipped: UInt {
        return self._skipped.withLock { $0 }
    }

    private var _tagged: OSAllocatedUnfairLock<UInt> = .init(initialState: 0)
    private var _skipped: OSAllocatedUnfairLock<UInt> = .init(initialState: 0)

    func incrementTagged() {
        self._tagged.withLock {
            $0 += 1
        }
    }

    func incrementSkipped() {
        self._skipped.withLock {
            $0 += 1
        }
    }
}
