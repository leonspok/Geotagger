//
//  Int+TimezoneOffset.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation

extension Int {
    /// Formats timezone offset in seconds to a string representation
    /// - Returns: String in format "+HH:MM", "-HH:MM", or "Z" for UTC
    func formatAsTimezoneOffset() -> String {
        if self == 0 {
            return "Z"
        }

        let hours = abs(self) / 3600
        let minutes = (abs(self) % 3600) / 60
        let sign = self >= 0 ? "+" : "-"

        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }
}
