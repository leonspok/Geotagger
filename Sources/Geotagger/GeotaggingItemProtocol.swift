//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation

public protocol GeotaggingItemProtocol {
    var id: String { get }
    var date: Date? { get }
    
    func skip(with error: Error)
    func apply(_ geotag: Geotag) throws
}
