//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation

extension URL {
    var isGPXFileURL: Bool {
        return self.pathExtension.lowercased() == "gpx"
    }
}
