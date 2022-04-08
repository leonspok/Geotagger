import Foundation

public final class Geotagger {
    
    public init() {}
    
    // MARK: - Public API
    
    public var exactMatchTimeRange: TimeInterval = 0
    public var interpolationMatchTimeRange: TimeInterval?
    public var locationReferences: LocationReferences = LocationReferences()
    
    public private(set) var anchors: [GeoAnchor] = []

    public func loadAnchors(with anchorsLoader: GeoAnchorsLoaderProtocol) throws {
        self.anchors.append(contentsOf: try anchorsLoader.loadAnchors())
    }
    
    public func unloadAnchors() {
        self.anchors.removeAll()
    }
    
    public func tag(_ items: [GeotaggingItemProtocol]) throws {
        let geotagFinder = GeotagFinder()
        geotagFinder.exactMatchTimeRange = self.exactMatchTimeRange
        geotagFinder.interpolationMatchTimeRange = self.interpolationMatchTimeRange
        geotagFinder.locationReferences = self.locationReferences
        items.forEach { item in
            do {
                let tag = try geotagFinder.findGeotag(for: item, using: self.anchors)
                try item.apply(tag)
            } catch let error {
                item.skip(with: error)
            }
        }
    }
}
