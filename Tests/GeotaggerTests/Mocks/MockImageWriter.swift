//
//  MockImageIOWriter.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation
@testable import GeotagKit

final class MockImageWriter: @unchecked Sendable, ImageFileWriterProtocol {
    func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {}
}
