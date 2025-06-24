//
//  PHAssetGeotaggingItem.swift
//  
//
//  Created on 06/01/2025.
//

import Foundation
import Photos
import Geotagger

public final class PHAssetGeotaggingItem: @unchecked Sendable, GeotaggingItemProtocol {
    // MARK: - Public API
    
    public let asset: PHAsset
    
    public var id: String {
        return self.asset.localIdentifier
    }
    
    public var date: Date? {
        return self.asset.creationDate
    }
    
    public var timeOffset: TimeInterval? {
        return nil  // PHAsset doesn't support time offset
    }
    
    public var timezoneOverride: String? {
        return nil  // PHAsset doesn't support timezone override
    }
    
    public init(asset: PHAsset, batchProcessor: PHAssetGeotagBatchProcessor) {
        self.asset = asset
        self.batchProcessor = batchProcessor
    }
    
    // MARK: - GeotaggingItemProtocol
    
    public func skip(with error: Error) {}
    
    public func apply(_ geotag: Geotag) async throws {
        guard self.asset.canPerform(.properties) else {
            throw PHAssetGeotaggingError.cannotEditAsset
        }
        
        guard let batchProcessor = self.batchProcessor else {
            throw PHAssetGeotaggingError.batchProcessorNotAvailable
        }
        
        try await batchProcessor.recordGeotag(asset: self.asset, geotag: geotag)
    }
    
    // MARK: - Private properties
    
    private weak var batchProcessor: PHAssetGeotagBatchProcessor?
}

public enum PHAssetGeotaggingError: LocalizedError {
    case cannotEditAsset
    case batchProcessorNotAvailable
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .cannotEditAsset:
            return "Cannot edit this asset"
        case .batchProcessorNotAvailable:
            return "Batch processor is not available"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
