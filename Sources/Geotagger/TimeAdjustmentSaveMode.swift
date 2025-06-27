//
//  TimeAdjustmentSaveMode.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation

public enum TimeAdjustmentSaveMode: String, CaseIterable, Sendable {
    case all = "all"        // Save time adjustments for all items
    case tagged = "tagged"  // Save only for items that get geotagged
    case none = "none"      // Never save time adjustments (default)
}