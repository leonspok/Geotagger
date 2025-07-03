//
//  PHAssetGeotagBatchProcessor.swift
//  
//
//  Created on 06/01/2025.
//

import Foundation
import Photos
import Geotagger

public struct PHAssetGeotagResult {
    public let asset: PHAsset
    public let result: Result<Geotag, Error>

    public init(asset: PHAsset, result: Result<Geotag, Error>) {
        self.asset = asset
        self.result = result
    }
}

public actor PHAssetGeotagBatchProcessor {
    // MARK: - Private types

    private struct PendingRequest {
        let asset: PHAsset
        let geotag: Geotag?
        let adjustedDate: Date?
        let continuation: CheckedContinuation<Void, Error>
    }

    // MARK: - Private properties

    private let photoLibrary: PHPhotoLibrary
    private let batchDelay: TimeInterval

    private var pendingRequests: [PendingRequest] = []
    private var processingTask: Task<Void, Never>?

    // MARK: - Public API

    public init(photoLibrary: PHPhotoLibrary, batchDelay: TimeInterval = 3.0) {
        self.photoLibrary = photoLibrary
        self.batchDelay = batchDelay
    }

    public func recordGeotag(asset: PHAsset, geotag: Geotag, adjustedDate: Date? = nil) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let request = PendingRequest(
                asset: asset,
                geotag: geotag,
                adjustedDate: adjustedDate,
                continuation: continuation
            )
            self.pendingRequests.append(request)
            self.scheduleProcessing()
        }
    }

    public func recordTimeAdjustment(asset: PHAsset, adjustedDate: Date) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let request = PendingRequest(
                asset: asset,
                geotag: nil,
                adjustedDate: adjustedDate,
                continuation: continuation
            )
            self.pendingRequests.append(request)
            self.scheduleProcessing()
        }
    }

    // MARK: - Private methods

    private func scheduleProcessing() {
        // Cancel existing processing task if any
        self.processingTask?.cancel()

        // Create new processing task with delay
        self.processingTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(self.batchDelay * 1_000_000_000))

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Process the batch
                await self.processBatch()
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    private func processBatch() async {
        // Collect all pending requests and continuations
        let requestsToProcess = self.pendingRequests

        // Clear pending arrays
        self.pendingRequests.removeAll()
        self.processingTask = nil

        // Process pending requests
        guard !requestsToProcess.isEmpty else {
            return
        }

        do {
            try await self.photoLibrary.performChanges { [requestsToProcess] in
                for request in requestsToProcess {
                    let changeRequest = PHAssetChangeRequest(for: request.asset)

                    // Apply geotag if provided
                    if let geotag = request.geotag {
                        changeRequest.location = CLLocation(
                            coordinate: CLLocationCoordinate2D(
                                latitude: geotag.location.latitude.degrees,
                                longitude: geotag.location.longitude.degrees
                            ),
                            altitude: geotag.location.altitude?.value ?? 0,
                            horizontalAccuracy: kCLLocationAccuracyBest,
                            verticalAccuracy: kCLLocationAccuracyBest,
                            timestamp: request.adjustedDate ?? request.asset.creationDate ?? Date()
                        )
                    }

                    // Apply adjusted date if provided
                    if let adjustedDate = request.adjustedDate {
                        changeRequest.creationDate = adjustedDate
                    }
                }
            }

            // If batch succeeds, resume all continuations
            for request in requestsToProcess {
                request.continuation.resume()
            }
        } catch let error {
            // If batch fails, resume all continuations by throwing errors
            for request in requestsToProcess {
                request.continuation.resume(throwing: error)
            }
        }
    }
}
