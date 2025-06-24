//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation

public protocol GeotaggingItemProtocol: Sendable {
    var id: String { get }
    var date: Date? { get }
    var timeOffset: TimeInterval? { get }
    var timezoneOverride: String? { get }
    
    func skip(with error: Error)
    func apply(_ geotag: Geotag) async throws
}
