//
//  File.swift
//  
//
//  Created by Igor Savelev on 08/04/2022.
//

import Foundation

struct DirectoryScanner {
    func scanContents(of directoryURL: URL, recursive: Bool = false, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) throws -> [URL] {
        var resourceKeys: [URLResourceKey] = keys ?? []
        if resourceKeys.contains(.isDirectoryKey) == false {
            resourceKeys.append(.isDirectoryKey)
        }
        var urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: resourceKeys, options: mask)
        if recursive {
            let directoryURLs = urls.filter(\.isDirectoryURL)
            urls.append(contentsOf: try directoryURLs.flatMap({ directoryURL in
                try self.scanContents(of: directoryURL, recursive: true, includingPropertiesForKeys: resourceKeys, options: mask)
            }))
        }
        return urls
    }
}
