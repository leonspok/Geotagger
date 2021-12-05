import Foundation

public final class Geotagger {
    public private(set) var text = "Hello, World!"

    public init() {}
    
    // MARK: - Public API
    
    public var exactMatchTolerance: TimeInterval = 0
    public var interpolationMatchTolerance: TimeInterval?
    public var locationReferences: LocationReferences = LocationReferences()
    
    public var anchors: [GeoAnchor] = [] {
        didSet {
            self.anchors = self.anchors.sorted(by: { $0.date < $1.date })
        }
    }
    
    public func process(_ items: [GeotaggingItemProtocol]) {
        items.forEach { item in
            do {
                let geotag = try self.process(item)
                try item.apply(geotag)
            } catch let error {
                item.skip(with: error)
            }
        }
    }
    
    // MARK: - Private methods
    
    private func process(_ item: GeotaggingItemProtocol) throws -> Geotag {
        guard let date = item.date else {
            throw GeotaggingError.canNotReadDateInformation
        }
        
        var error: GeotaggingError
        
        print("Checking item with date: \(date)")
        
        let exactCandidates = self.findClosestAnchors(to: date, tolerance: self.exactMatchTolerance)
        if exactCandidates.isEmpty {
            error = GeotaggingError.notEnoughGeoAnchorCandidates
        } else {
            return self.calculateExactGeotag(for: date, from: exactCandidates)
        }
        
        if let interpolationMatchTolerance = self.interpolationMatchTolerance {
            if let interpolateCandidates = self.findAnchorsForInterpolation(for: date, tolerance: interpolationMatchTolerance) {
                return self.calculateInterpolatedGeotag(for: date, with: interpolateCandidates.first, and: interpolateCandidates.second)
            } else {
                error = GeotaggingError.notEnoughGeoAnchorCandidates
            }
        }
        
        throw error
    }
    
    private func findClosestAnchors(to date: Date, tolerance: TimeInterval) -> [GeoAnchor] {
        let anchorsWithinRadius = self.findAllAnchors(around: date, radius: tolerance)
        guard let closestAnchor = anchorsWithinRadius.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) else {
            return []
        }
        return anchorsWithinRadius.filter({ $0.date == closestAnchor.date })
    }
    
    private func findAnchorsForInterpolation(for date: Date, tolerance: TimeInterval) -> (first: GeoAnchor, second: GeoAnchor)? {
        let interpolateCandidates = self.findAllAnchors(around: date, radius: tolerance)
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
    
    private func findAllAnchors(around date: Date, radius: TimeInterval) -> [GeoAnchor] {
        return self.anchors.filter({ abs($0.date.timeIntervalSince(date)) <= radius })
    }
    
    private func calculateExactGeotag(for date: Date, from anchors: [GeoAnchor]) -> Geotag {
        assert(anchors.isEmpty == false, "Anchors list should not be empty")
        let normalizedAnchors = anchors.map({ GeoAnchor(date: $0.date, location: $0.location.based(on: self.locationReferences)) })
        print("Calculating exact geotag from:")
        anchors.forEach { anchor in
            print("\t\(anchor.date) - \(anchor.location.debugInfo)")
        }
        let tag = Geotag(
            location: calculateCentroid(of: normalizedAnchors.map({ (location: $0.location, weight: 1.0) }))
        )
        print("Calculated: \(tag.location.debugInfo)")
        return tag
    }
    
    private func calculateInterpolatedGeotag(for date: Date, with firstAnchor: GeoAnchor, and secondAnchor: GeoAnchor) -> Geotag {
        let firstLocation = firstAnchor.location.based(on: self.locationReferences)
        let secondLocation = secondAnchor.location.based(on: self.locationReferences)
        print("Calculating interpolated geotag from:")
        [firstAnchor, secondAnchor].forEach { anchor in
            print("\t\(anchor.date) - \(anchor.location.debugInfo)")
        }
        let ratio = date.timeIntervalSince(firstAnchor.date) / secondAnchor.date.timeIntervalSince(firstAnchor.date)
        let tag = Geotag(
            location: calculateInterpolatedLocation(between: firstLocation, and: secondLocation, ratio: ratio)
        )
        print("Calculated: \(tag.location.debugInfo)")
        return tag
    }
}
