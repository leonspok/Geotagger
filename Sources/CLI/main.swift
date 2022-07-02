//
//  File.swift
//  
//
//  Created by Igor Savelev on 01/12/2021.
//

import Foundation
import Geotagger
import ArgumentParser
import Darwin
import UniformTypeIdentifiers

enum CLIError: Error {
    case noGeoAnchorsFound
    case outputIsNotADirectory
}

struct Tag: ParsableCommand {
    @Option(name: .shortAndLong, help: "Path to directory or file containing GPX or image files that will be used as location anchors")
    var anchors: String
    
    @Option(name: .shortAndLong, help: "Path to input directory or file")
    var input: String
    
    @Option(name: .shortAndLong, help: "Path to output directory or file. If not provided, original files will be overwritten.")
    var output: String?
    
    @Option(name: .long, help: "Geotagger will search for the closest location anchor to the moment when photo was taken within this time range and reuse anchor's location as an exact location of the photo.")
    var exactMatchRange: TimeInterval = 60
    
    @Option(name: .long, help: "Geotagger will use all location anchors within this time range from the moment when photo was taken and calculate the location of the photo by interpolating these anchors location.")
    var interpolationMatchRange: TimeInterval = 240
    
    @Flag(name: .long, help: "If enabled, then photos that already have location tag will be tagged again.")
    var includeAlreadyTagged: Bool = false
    
    @Flag(name: .long, help: "Enable additional logging.")
    var verbose: Bool = false
    
    mutating func run() throws {
        let geotagger = Geotagger()
        geotagger.exactMatchTimeRange = self.exactMatchRange
        geotagger.interpolationMatchTimeRange = self.interpolationMatchRange
        
        let fileManager = FileManager.default
                
        let anchorsURL = URL(fileURLWithPath: self.anchors)
        var isAnchorsURLDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: self.anchors, isDirectory: &isAnchorsURLDirectory),
           isAnchorsURLDirectory.boolValue {
            let anchorsURL = URL(fileURLWithPath: self.anchors, isDirectory: true)
            try geotagger.loadAnchorsFromGPXFilesFromDirectory(anchorsURL, scanSubdirectories: true)
            try geotagger.loadAnchorsFromPhotosFromDirectoryAt(anchorsURL, scanSubdirectories: true)
        } else if anchorsURL.isGPXFileURL {
            try geotagger.loadAnchorsFromGPXFiles(at: [anchorsURL])
        } else if anchorsURL.isPhotoFileURL {
            try geotagger.loadAnchorsFromPhotos(at: [anchorsURL])
        }
        
        if geotagger.anchors.isEmpty {
            throw CLIError.noGeoAnchorsFound
        } else {
            print("Location anchors found: \(geotagger.anchors.count)")
        }
        
        var isInputURLDirectory: ObjCBool = false
        var isOutputURLDirectory: ObjCBool = false
        
        let counter = GeotaggingCounter()
        
        if fileManager.fileExists(atPath: self.input, isDirectory: &isInputURLDirectory),
           isInputURLDirectory.boolValue {
            let inputURL = URL(fileURLWithPath: self.input, isDirectory: true)
            if let output = output,
               fileManager.fileExists(atPath: output, isDirectory: &isOutputURLDirectory),
               isOutputURLDirectory.boolValue == false {
                throw CLIError.outputIsNotADirectory
            }
            let outputURL = self.output.flatMap { URL(fileURLWithPath: $0, isDirectory: true) }
            print("Started tagging...")
            try geotagger.tagPhotosInDirectoryAt(
                inputURL,
                scanSubdirectories: true,
                outputDirectoryURL: outputURL,
                includeAlreadyTagged: self.includeAlreadyTagged,
                counter: counter,
                verbose: self.verbose
            )
        } else {
            let inputURL = URL(fileURLWithPath: self.input)
            let outputURL = self.output.flatMap { URL(fileURLWithPath: $0) }
            print("Started tagging...")
            try geotagger.tagPhotos(
                at: [inputURL],
                includeAlreadyTagged: self.includeAlreadyTagged,
                counter: counter,
                verbose: self.verbose,
                saveTo: { url in
                    return outputURL ?? url
                }
            )
        }
        
        print("Done")
        print("Tagged: \(counter.tagged)")
        print("Skipped: \(counter.skipped)")
    }
}

Tag.main()
