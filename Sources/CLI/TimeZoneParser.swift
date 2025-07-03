//
//  TimeZoneParser.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation
import Geotagger
import ArgumentParser

extension TimeAdjustmentSaveMode: ExpressibleByArgument {
    public init?(argument: String) {
        self.init(rawValue: argument)
    }

    public static var allValueStrings: [String] {
        return allCases.map(\.rawValue)
    }
}

extension String {
    /// Parses a timezone string and returns the offset in seconds from GMT
    /// Supports multiple formats:
    /// - GMT offset: "+05:00", "-08:00", "Z"
    /// - Abbreviation: "EST", "PST", "CET"
    /// - Identifier: "America/New_York", "Europe/London"
    func parseAsTimezoneOffset(at date: Date = Date()) -> Int? {
        // Handle Z (UTC)
        if self == "Z" {
            return 0
        }

        // Try to parse as GMT offset format (+05:00, -08:00)
        let gmtPattern = /^([+-])(\d{2}):(\d{2})$/
        if let match = self.firstMatch(of: gmtPattern) {
            guard let hours = Int(match.2),
                  let minutes = Int(match.3),
                  hours >= 0 && hours <= 14,
                  minutes >= 0 && minutes < 60 else {
                return nil
            }

            let totalSeconds = (hours * 3600) + (minutes * 60)
            return match.1 == "+" ? totalSeconds : -totalSeconds
        }

        // Try to create TimeZone from abbreviation or identifier
        if let timeZone = TimeZone(abbreviation: self) ?? TimeZone(identifier: self) {
            return timeZone.secondsFromGMT(for: date)
        }

        return nil
    }
}
