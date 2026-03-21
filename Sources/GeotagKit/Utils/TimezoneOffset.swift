//
//  String+TimezoneOffset.swift
//  Geotagger
//
//  Created by Igor Savelev on 21/03/2026.
//

import Foundation

public func isValidTimezoneOffset(_ timezone: String) -> Bool {
    // Valid formats: "+05:00", "-08:00", "Z"
    if timezone == "Z" {
        return true
    }

    let pattern = /^([+-])(\d{2}):(\d{2})$/
    guard let match = timezone.firstMatch(of: pattern) else {
        return false
    }

    // Extract hours and minutes
    guard let hours = Int(match.2),
          let minutes = Int(match.3) else {
        return false
    }

    // Valid timezone offsets are -12:00 to +14:00
    // Minutes should be 00, 15, 30, or 45 (common timezone minute offsets)
    return hours >= 0 && hours <= 14 && (minutes == 0 || minutes == 15 || minutes == 30 || minutes == 45)
}

public func parseTimezoneOffset(_ timezoneString: String) -> TimeZone? {
    // Handle "Z" for UTC
    if timezoneString == "Z" {
        return TimeZone(secondsFromGMT: 0)
    }

    // Handle format like "+05:00" or "-08:00"
    let pattern = /^([+-])(\d{2}):(\d{2})$/
    guard let match = timezoneString.firstMatch(of: pattern) else {
        return nil
    }

    let sign = String(match.1)
    let hours = Int(match.2) ?? 0
    let minutes = Int(match.3) ?? 0

    guard hours <= 23, minutes <= 59 else {
        return nil
    }

    let totalSeconds = (hours * 3600) + (minutes * 60)
    let offsetSeconds = sign == "+" ? totalSeconds : -totalSeconds

    return TimeZone(secondsFromGMT: offsetSeconds)
}

public func parseAsTimezoneOffset(_ timezoneString: String, at date: Date = Date()) -> Int? {
    let timeZone = parseTimezoneOffset(timezoneString) ??
        TimeZone(abbreviation: timezoneString) ??
        TimeZone(identifier: timezoneString)

    // Try to create TimeZone from abbreviation or identifier
    if let timeZone {
        return timeZone.secondsFromGMT(for: date)
    }

    return nil
}

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
