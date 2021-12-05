//
//  File.swift
//  
//
//  Created by Igor Savelev on 02/12/2021.
//

import Foundation

public protocol GeoAnchorsLoaderProtocol {
    func loadAnchors() throws -> [GeoAnchor]
}
