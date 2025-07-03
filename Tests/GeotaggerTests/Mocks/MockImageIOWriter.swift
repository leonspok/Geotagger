//
//  MockImageIOWriter.swift
//  
//
//  Created on 27/06/2025.
//

import Foundation
@testable import Geotagger

final class MockImageIOWriter: @unchecked Sendable, ImageIOWriterProtocol {
    func write(geotag: Geotag?, timezoneOverride: String?, originalTimezone: String?, adjustedDate: Date?, toPhotoAt sourceURL: URL, saveNewVersionAt destinationURL: URL) throws {}
}
