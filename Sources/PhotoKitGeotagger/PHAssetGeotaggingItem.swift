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
        guard let originalDate = self.asset.creationDate else {
            return nil
        }
        
        if let offset = self.timeOffset {
            return originalDate.addingTimeInterval(offset)
        } else {
            return originalDate
        }
    }
    
    public init(asset: PHAsset,
                batchProcessor: PHAssetGeotagBatchProcessor,
                timeOffset: TimeInterval? = nil,
                timeAdjustmentSaveMode: TimeAdjustmentSaveMode = .none) {
        self.asset = asset
        self.batchProcessor = batchProcessor
        self.timeOffset = timeOffset
        self.timeAdjustmentSaveMode = timeAdjustmentSaveMode
    }
    
    // MARK: - GeotaggingItemProtocol
    
    public func skip(with error: Error) throws {
        guard timeAdjustmentSaveMode == .all,
              self.timeOffset != nil,
              let adjustedDate = self.date else {
            return
        }
        
        guard let batchProcessor = self.batchProcessor else {
            throw PHAssetGeotaggingError.batchProcessorNotAvailable
        }
        
        Task {
            try await batchProcessor.recordTimeAdjustment(asset: self.asset, adjustedDate: adjustedDate)
        }
    }
    
    public func apply(_ geotag: Geotag) async throws {
        guard self.asset.canPerform(.properties) else {
            throw PHAssetGeotaggingError.cannotEditAsset
        }
        
        guard let batchProcessor = self.batchProcessor else {
            throw PHAssetGeotaggingError.batchProcessorNotAvailable
        }
        
        let shouldApplyTimeAdjustment = timeAdjustmentSaveMode == .all || timeAdjustmentSaveMode == .tagged
        let adjustedDate = shouldApplyTimeAdjustment ? self.date : nil
        
        try await batchProcessor.recordGeotag(asset: self.asset, geotag: geotag, adjustedDate: adjustedDate)
    }
    
    // MARK: - Private properties
    
    private weak var batchProcessor: PHAssetGeotagBatchProcessor?
    private let timeOffset: TimeInterval?
    private let timeAdjustmentSaveMode: TimeAdjustmentSaveMode
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
