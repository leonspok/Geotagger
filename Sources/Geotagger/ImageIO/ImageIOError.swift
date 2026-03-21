//
//  File.swift
//  
//
//  Created by Igor Savelev on 04/12/2021.
//

import Foundation

public enum ImageIOError: Error {
    case canNotCreateImageSource
    case canNotCopyImageSource
    case canNotCreateImageDestination
    case canNotFinalizeImageDestination
    /// The expected ISOBMFF metadata box (moov, Canon UUID, CMT2, or CMT4) was not found in a CR3 file.
    case canNotFindCR3MetadataBox

}
