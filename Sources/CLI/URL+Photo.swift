//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation
import UniformTypeIdentifiers

extension URL {
    var isPhotoFileURL: Bool {
        let resources = try? self.resourceValues(forKeys: [.contentTypeKey])
        return resources?.contentType?.conforms(to: .image) == true
    }
}
