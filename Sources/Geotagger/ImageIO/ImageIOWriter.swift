//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation
import ImageIO

public protocol ImageIOWriterProtocol {
    func write(_ geotag: Geotag, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws
}

public struct ImageIOWriter: ImageIOWriterProtocol {
    
    public init() {}
    
    // MARK: - ImageIOWriterProtocol
    
    public func write(_ geotag: Geotag, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let sourceUTType = CGImageSourceGetType(imageSource) else {
            throw ImageIOError.canNotCreateImageSource
        }
        
        let mutableMetadata: CGMutableImageMetadata = {
            if let originalMetadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil),
               let mutableCopy = CGImageMetadataCreateMutableCopy(originalMetadata) {
                return mutableCopy
            } else {
                return CGImageMetadataCreateMutable()
            }
        }()

        for (key, value) in geotag.asGPSDictionary {
            CGImageMetadataSetValueMatchingImageProperty(mutableMetadata, kCGImagePropertyGPSDictionary, key, value as CFTypeRef)
        }
                
        guard let imageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, sourceUTType, 1, nil) else {
            throw ImageIOError.canNotCreateImageDestination
        }
        
        
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: mutableMetadata,
            kCGImageDestinationMergeMetadata: true
        ]
        CGImageDestinationCopyImageSource(imageDestination, imageSource, options as CFDictionary, nil)
    }
}
