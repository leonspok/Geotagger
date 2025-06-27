//
//  Geotagger.swift
//  
//
//  Created on 06/01/2025.
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

@main
struct GeoTaggerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "geotagger",
        abstract: "A tool for geotagging photos using GPX tracks and other geotagged photos as location references.",
        version: Version.full
    )
    
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
    var includeAlreadyTagged = false
    
    @Flag(name: .long, help: "Enable additional logging.")
    var verbose = false
    
    @Option(name: .long, help: "Time offset in minutes to apply to anchor timestamps (positive or negative).")
    var anchorsTimeOffset: Int?
    
    @Option(name: .long, help: "Time offset in minutes to apply to photo timestamps (positive or negative).")
    var photosTimeOffset: Int?
    
    @Option(name: .long, help: "Timezone override for photos. Accepts: GMT offset ('+05:00', '-08:00', 'Z'), abbreviation ('EST', 'PST'), or identifier ('America/New_York'). Only affects EXIF timezone fields, not the actual time used for matching.")
    var photosTimezoneOverride: String?
    
    @Option(name: .long, help: "When to save time adjustments: 'all' (always), 'tagged' (only for geotagged photos), 'none' (never, default).")
    var saveTimeAdjustments: TimeAdjustmentSaveMode = .none
    
    func run() async throws {
        let geotagger = Geotagger()
        geotagger.exactMatchTimeRange = self.exactMatchRange
        geotagger.interpolationMatchTimeRange = self.interpolationMatchRange
        
        let fileManager = FileManager.default
        
        // Convert minutes to seconds for time offsets
        let anchorsTimeOffsetSeconds = self.anchorsTimeOffset.map { TimeInterval($0 * 60) }
        let photosTimeOffsetSeconds = self.photosTimeOffset.map { TimeInterval($0 * 60) }
        
        // Parse timezone override
        let photosTimezoneOffsetSeconds: Int?
        if let timezoneString = self.photosTimezoneOverride {
            if let parsedOffset = timezoneString.parseAsTimezoneOffset() {
                photosTimezoneOffsetSeconds = parsedOffset
            } else {
                print("Warning: Failed to parse timezone '\(timezoneString)'. Using original photo timezone.")
                photosTimezoneOffsetSeconds = nil
            }
        } else {
            photosTimezoneOffsetSeconds = nil
        }
                
        let anchorsURL = URL(fileURLWithPath: self.anchors)
        var isAnchorsURLDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: self.anchors, isDirectory: &isAnchorsURLDirectory),
           isAnchorsURLDirectory.boolValue {
            let anchorsURL = URL(fileURLWithPath: self.anchors, isDirectory: true)
            try geotagger.loadAnchorsFromGPXFilesFromDirectory(anchorsURL, scanSubdirectories: true, timeOffset: anchorsTimeOffsetSeconds)
            try geotagger.loadAnchorsFromPhotosFromDirectoryAt(anchorsURL, scanSubdirectories: true, timeOffset: anchorsTimeOffsetSeconds)
        } else if anchorsURL.isGPXFileURL {
            try geotagger.loadAnchorsFromGPXFiles(at: [anchorsURL], timeOffset: anchorsTimeOffsetSeconds)
        } else if anchorsURL.isPhotoFileURL {
            try geotagger.loadAnchorsFromPhotos(at: [anchorsURL], timeOffset: anchorsTimeOffsetSeconds)
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
            try await geotagger.tagPhotosInDirectoryAt(
                inputURL,
                scanSubdirectories: true,
                outputDirectoryURL: outputURL,
                includeAlreadyTagged: self.includeAlreadyTagged,
                counter: counter,
                verbose: self.verbose,
                photoTimeOffset: photosTimeOffsetSeconds,
                timezoneOverride: photosTimezoneOffsetSeconds,
                timeAdjustmentSaveMode: self.saveTimeAdjustments
            )
        } else {
            let inputURL = URL(fileURLWithPath: self.input)
            let outputURL = self.output.flatMap { URL(fileURLWithPath: $0) }
            print("Started tagging...")
            try await geotagger.tagPhotos(
                at: [inputURL],
                includeAlreadyTagged: self.includeAlreadyTagged,
                counter: counter,
                verbose: self.verbose,
                photoTimeOffset: photosTimeOffsetSeconds,
                timezoneOverride: photosTimezoneOffsetSeconds,
                timeAdjustmentSaveMode: self.saveTimeAdjustments,
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
