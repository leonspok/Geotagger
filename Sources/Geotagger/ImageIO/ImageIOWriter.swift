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
        var metadata: [CFString: Any] = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] ?? [:]
        metadata[kCGImagePropertyGPSDictionary] = geotag.asGPSDictionary
        
        guard let imageDestination = CGImageDestinationCreateWithURL(destinationURL as CFURL, sourceUTType, 1, nil) else {
            throw ImageIOError.canNotCreateImageDestination
        }
        
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, metadata as CFDictionary)
        guard CGImageDestinationFinalize(imageDestination) else {
            throw ImageIOError.canNotFinalizeImageDestination
        }
    }
}
