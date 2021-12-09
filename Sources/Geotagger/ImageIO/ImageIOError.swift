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
}
