//
//  File.swift
//  
//
//  Created by Igor Savelev on 21/12/2021.
//

import Foundation

public struct GeotagFinder: Sendable {

    public init(
        exactMatchTimeRange: TimeInterval = 0,
        interpolationMatchTimeRange: TimeInterval? = nil,
        locationReferences: LocationReferences = LocationReferences()
    ) {
        self.exactMatchTimeRange = exactMatchTimeRange
        self.interpolationMatchTimeRange = interpolationMatchTimeRange
        self.locationReferences = locationReferences
    }

    // MARK: - Public API

    public let exactMatchTimeRange: TimeInterval
    public let interpolationMatchTimeRange: TimeInterval?
    public let locationReferences: LocationReferences

    public func findGeotag(for item: GeotaggingItemProtocol, using anchors: [GeoAnchor]) throws -> Geotag {
        guard let date = try item.date else {
            throw GeotaggingError.canNotReadDateInformation
        }
        
        var error: GeotaggingError
                
        let exactCandidates = self.findClosestAnchors(to: date, in: anchors, timeRange: self.exactMatchTimeRange)
        if exactCandidates.isEmpty {
            error = GeotaggingError.notEnoughGeoAnchorCandidates
        } else {
            return self.calculateExactGeotag(for: date, from: exactCandidates)
        }
        
        if let interpolationMatchTolerance = self.interpolationMatchTimeRange {
            if let interpolateCandidates = self.findAnchorsForInterpolation(for: date, in: anchors, timeRange: interpolationMatchTolerance) {
                return self.calculateInterpolatedGeotag(for: date, with: interpolateCandidates.first, and: interpolateCandidates.second)
            } else {
                error = GeotaggingError.notEnoughGeoAnchorCandidates
            }
        }
        
        throw error
    }
    
    // MARK: - Private methods
    
    private func findClosestAnchors(to date: Date, in anchors: [GeoAnchor], timeRange: TimeInterval) -> [GeoAnchor] {
        let anchorsWithinRadius = self.findAllAnchors(around: date, in: anchors, radius: timeRange)
        guard let closestAnchor = anchorsWithinRadius.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else {
            return []
        }
        return anchorsWithinRadius.filter({ $0.date == closestAnchor.date })
    }
    
    private func findAnchorsForInterpolation(for date: Date, in anchors: [GeoAnchor], timeRange: TimeInterval) -> (first: GeoAnchor, second: GeoAnchor)? {
        let interpolateCandidates = self.findAllAnchors(around: date, in: anchors, radius: timeRange)
        if let lastBefore = interpolateCandidates.last(where: { $0.date < date }), let firstAfter = interpolateCandidates.first(where: { $0.date > date }) {
            return (first: lastBefore, second: firstAfter)
        } else {
            let sortedByTimeInterval = interpolateCandidates.sorted(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
            guard sortedByTimeInterval.count >= 2 else {
                return nil
            }
            let candidates = sortedByTimeInterval[0..<2].sorted(by: { $0.date < $1.date })
            return (first: candidates[0], second: candidates[1])
        }
    }
    
    private func findAllAnchors(around date: Date, in anchors: [GeoAnchor], radius: TimeInterval) -> [GeoAnchor] {
        return anchors.filter({ abs($0.date.timeIntervalSince(date)) <= radius })
    }
    
    private func calculateExactGeotag(for date: Date, from anchors: [GeoAnchor]) -> Geotag {
        assert(anchors.isEmpty == false, "Anchors list should not be empty")
        let normalizedAnchors = anchors.map({ GeoAnchor(date: $0.date, location: $0.location.based(on: self.locationReferences)) })
        return Geotag(
            location: calculateCentroid(of: normalizedAnchors.map({ (location: $0.location, weight: 1.0) }))
        )
    }
    
    private func calculateInterpolatedGeotag(for date: Date, with firstAnchor: GeoAnchor, and secondAnchor: GeoAnchor) -> Geotag {
        let firstLocation = firstAnchor.location.based(on: self.locationReferences)
        let secondLocation = secondAnchor.location.based(on: self.locationReferences)
        let ratio = date.timeIntervalSince(firstAnchor.date) / secondAnchor.date.timeIntervalSince(firstAnchor.date)
        return Geotag(
            location: calculateInterpolatedLocation(between: firstLocation, and: secondLocation, ratio: ratio)
        )
    }
}

// MARK: - Result-based API
extension GeotagFinder {
    public func findGeotagResult(for item: GeotaggingItemProtocol, using anchors: [GeoAnchor]) -> Result<Geotag, Error> {
        do {
            let geotag = try findGeotag(for: item, using: anchors)
            return .success(geotag)
        } catch {
            return .failure(error)
        }
    }
}

