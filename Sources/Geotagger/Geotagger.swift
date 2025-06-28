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
    
    public func tag(_ items: [GeotaggingItemProtocol]) async throws {
        let geotagFinder = GeotagFinder(
            exactMatchTimeRange: self.exactMatchTimeRange,
            interpolationMatchTimeRange: self.interpolationMatchTimeRange,
            locationReferences: self.locationReferences
        )
        
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { [anchors = self.anchors] in
                    let result = geotagFinder.findGeotagResult(for: item, using: anchors)
                    
                    switch result {
                    case .success(let geotag):
                        try? await item.apply(geotag)
                    case .failure(let error):
                        try? await item.skip(with: error)
                    }
                }
            }
        }
    }
}
