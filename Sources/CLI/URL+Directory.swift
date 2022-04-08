//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation

extension URL {
    var isDirectoryURL: Bool {
        let resources = try? self.resourceValues(forKeys: [.isDirectoryKey])
        return resources?.isDirectory == true
    }
}
