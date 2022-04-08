//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation

final class GeotaggingCounter {
    private(set) var tagged: UInt = 0
    private(set) var skipped: UInt = 0
    
    func incrementTagged() {
        self.tagged += 1
    }
    
    func incrementSkipped() {
        self.skipped += 1
    }
}
