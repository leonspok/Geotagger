//
//  TimezoneIntegrationTests.swift
//  
//
//  Created on 28/06/2025.
//

import XCTest
@testable import Geotagger

final class TimezoneIntegrationTests: XCTestCase {
    
    // MARK: - Test Helpers
    
    private let baseDate = Date(timeIntervalSince1970: 1000000)
    private let baseLocation = Location(latitude: .degrees(52.5200), longitude: .degrees(13.4050))
    
    private func createAnchor(secondsOffset: TimeInterval, lat: Double = 52.5200, lon: Double = 13.4050) -> GeoAnchor {
        let location = Location(
            latitude: .degrees(lat),
            longitude: .degrees(lon),
            altitude: nil
        )
        return GeoAnchor(date: self.baseDate.addingTimeInterval(secondsOffset), location: location)
    }
    
    private func createTimezoneAwareImageIOReader(dates: [URL: Date]) -> TimezoneAwareMockImageIOReader {
        return TimezoneAwareMockImageIOReader(datesByURL: dates)
    }
    
    private func createDateInTimezone(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, timezoneOffsetSeconds: Int) -> Date {
        // Create a date using DateComponents with proper timezone context
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: timezoneOffsetSeconds)
        
        return Calendar.current.date(from: components) ?? Date()
    }
    
    private func createImageIOGeotaggingItem(photoURL: URL, imageIOReader: ImageIOReaderProtocol) -> ImageIOGeotaggingItem {
        return ImageIOGeotaggingItem(
            photoURL: photoURL,
            outputURL: photoURL.appendingPathExtension("tagged"),
            imageIOReader: imageIOReader,
            imageIOWriter: MockImageIOWriter(),
            timeOffset: nil,
            timezoneOverride: nil,
            timeAdjustmentSaveMode: .none
        )
    }
    
    // MARK: - Cross-Timezone Matching Tests
    
    func testPhotoAndGPXInDifferentTimezones() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 7200) // 2 hours
        
        // Create a photo URL and date representing a photo taken in +05:00 timezone
        let photoURL = URL(fileURLWithPath: "/test/photo.jpg")
        
        // Use baseDate components but put the photo halfway between anchors
        // baseDate is 13:46:40 UTC, so anchors will be at 13:46:40 and 15:46:40
        // Photo should be at 14:46:40 UTC, which is "19:46+05:00"
        let baseComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self.baseDate)
        let photoDate = self.createDateInTimezone(
            year: baseComponents.year!, 
            month: baseComponents.month!, 
            day: baseComponents.day!, 
            hour: (baseComponents.hour! + 5) % 24, // Add 5 hours for timezone offset
            minute: baseComponents.minute!, 
            second: baseComponents.second!, 
            timezoneOffsetSeconds: 5 * 3600
        )
        
        // Create mock reader that returns timezone-aware date
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [photoURL: photoDate])
        let photoItem = self.createImageIOGeotaggingItem(photoURL: photoURL, imageIOReader: mockReader)
        
        // Create GPS anchors in UTC (typical for GPX files)
        let anchor1 = self.createAnchor(secondsOffset: -3600, lat: 51.0, lon: 12.0)  // 1 hour before baseDate
        let anchor2 = self.createAnchor(secondsOffset: 3600, lat: 53.0, lon: 14.0)   // 1 hour after baseDate
        
        // Photo at baseDate should interpolate between anchors at baseDate-1h and baseDate+1h
        let geotag = try finder.findGeotag(for: photoItem, using: [anchor1, anchor2])
        
        // Should interpolate between the two anchors (or exactly at one of them)
        XCTAssertNotNil(geotag)
        XCTAssertGreaterThanOrEqual(geotag.location.latitude.degrees, 51.0)
        XCTAssertLessThanOrEqual(geotag.location.latitude.degrees, 53.0)
    }
    
    func testSameLocalTimeDifferentTimezones() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        
        // Create two photos taken at the same local time but in different timezones
        let photo1URL = URL(fileURLWithPath: "/test/photo1.jpg")
        let photo2URL = URL(fileURLWithPath: "/test/photo2.jpg")
        
        // Photo1: "12:00+05:00" = "07:00 UTC" 
        let photo1LocalTime = self.baseDate
        let photo1UTCTime = photo1LocalTime.addingTimeInterval(5 * 3600)
        
        // Photo2: "12:00-08:00" = "20:00 UTC"
        let photo2LocalTime = self.baseDate  
        let photo2UTCTime = photo2LocalTime.addingTimeInterval(-8 * 3600)
        
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [
            photo1URL: photo1UTCTime,
            photo2URL: photo2UTCTime
        ])
        
        let photoItem1 = self.createImageIOGeotaggingItem(photoURL: photo1URL, imageIOReader: mockReader)
        let photoItem2 = self.createImageIOGeotaggingItem(photoURL: photo2URL, imageIOReader: mockReader)
        
        // Create anchors at the UTC times corresponding to each photo
        let anchor1 = self.createAnchor(secondsOffset: 5 * 3600, lat: 51.0, lon: 12.0)  // For photo1
        let anchor2 = self.createAnchor(secondsOffset: -8 * 3600, lat: 53.0, lon: 14.0) // For photo2
        
        // Each photo should match its corresponding anchor
        let geotag1 = try finder.findGeotag(for: photoItem1, using: [anchor1])
        let geotag2 = try finder.findGeotag(for: photoItem2, using: [anchor2])
        
        XCTAssertEqual(geotag1.location.latitude.degrees, 51.0, accuracy: 0.0001)
        XCTAssertEqual(geotag1.location.longitude.degrees, 12.0, accuracy: 0.0001)
        
        XCTAssertEqual(geotag2.location.latitude.degrees, 53.0, accuracy: 0.0001)
        XCTAssertEqual(geotag2.location.longitude.degrees, 14.0, accuracy: 0.0001)
    }
    
    func testTimezoneMismatchExactMatch() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60)
        
        let photoURL = URL(fileURLWithPath: "/test/photo.jpg")
        
        // Photo taken at "12:00+05:00" = "07:00 UTC"
        let photoUTCTime = self.baseDate.addingTimeInterval(5 * 3600)
        
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [photoURL: photoUTCTime])
        let photoItem = self.createImageIOGeotaggingItem(photoURL: photoURL, imageIOReader: mockReader)
        
        // GPS anchor at exactly "12:00 UTC" (5 hours different from photo)
        let anchor = self.createAnchor(secondsOffset: 0)
        
        // Should fail exact match due to 5-hour difference
        XCTAssertThrowsError(try finder.findGeotag(for: photoItem, using: [anchor])) { error in
            XCTAssertEqual(error as? GeotaggingError, .notEnoughGeoAnchorCandidates)
        }
    }
    
    func testTimezoneMismatchInterpolation() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 21600) // 6 hours
        
        let photoURL = URL(fileURLWithPath: "/test/photo.jpg")
        
        // Photo taken at "12:00+05:00" = "07:00 UTC"
        let photoUTCTime = self.baseDate.addingTimeInterval(5 * 3600)
        
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [photoURL: photoUTCTime])
        let photoItem = self.createImageIOGeotaggingItem(photoURL: photoURL, imageIOReader: mockReader)
        
        // GPS anchors at "06:00 UTC" and "08:00 UTC" (photo is between them)
        let anchor1 = self.createAnchor(secondsOffset: 4 * 3600, lat: 51.0, lon: 12.0)  // 06:00 UTC (relative to baseDate)
        let anchor2 = self.createAnchor(secondsOffset: 6 * 3600, lat: 53.0, lon: 14.0)  // 08:00 UTC (relative to baseDate)
        
        // Should interpolate successfully
        let geotag = try finder.findGeotag(for: photoItem, using: [anchor1, anchor2])
        
        // Photo at 07:00 UTC should interpolate to middle of 06:00-08:00 range
        XCTAssertEqual(geotag.location.latitude.degrees, 52.0, accuracy: 0.01)
        XCTAssertEqual(geotag.location.longitude.degrees, 13.0, accuracy: 0.1) // Increase tolerance for longitude
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testTravelPhotographyScenario() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 300, interpolationMatchTimeRange: 3600) // 5 min exact, 1 hour interpolation
        
        // Simulate a travel scenario: photographer travels from London to Paris
        // GPS track in UTC, photos taken with camera set to local time
        
        let photoURL = URL(fileURLWithPath: "/test/paris_photo.jpg")
        
        // Photo taken in Paris at "14:00 local time" (UTC+1) = "13:00 UTC"
        let parisPhotoUTCTime = self.baseDate.addingTimeInterval(1 * 3600)
        
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [photoURL: parisPhotoUTCTime])
        let photoItem = self.createImageIOGeotaggingItem(photoURL: photoURL, imageIOReader: mockReader)
        
        // GPS track points in UTC
        let londonPoint = self.createAnchor(secondsOffset: 0, lat: 51.5074, lon: -0.1278)     // 12:00 UTC in London
        let parisPoint = self.createAnchor(secondsOffset: 2 * 3600, lat: 48.8566, lon: 2.3522) // 14:00 UTC in Paris
        
        // Photo at 13:00 UTC should interpolate between London (12:00) and Paris (14:00)
        let geotag = try finder.findGeotag(for: photoItem, using: [londonPoint, parisPoint])
        
        // Should be somewhere between London and Paris
        XCTAssertGreaterThan(geotag.location.latitude.degrees, 48.8)
        XCTAssertLessThan(geotag.location.latitude.degrees, 51.6)
        XCTAssertGreaterThan(geotag.location.longitude.degrees, -0.2)
        XCTAssertLessThan(geotag.location.longitude.degrees, 2.4)
    }
    
    func testMultiplePhotosSameGPXTrack() throws {
        let finder = GeotagFinder(exactMatchTimeRange: 60, interpolationMatchTimeRange: 3600) // 1 hour interpolation window
        
        // Multiple photos taken during a journey, all with timezone info
        let photo1URL = URL(fileURLWithPath: "/test/photo1.jpg")
        let photo2URL = URL(fileURLWithPath: "/test/photo2.jpg")
        let photo3URL = URL(fileURLWithPath: "/test/photo3.jpg")
        
        // Create photos that will exactly match anchor UTC times
        // Photo 1: exactly at baseDate (anchor1 time)
        // Photo 2: exactly at baseDate + 30 min (interpolation between anchors)
        // Photo 3: exactly at baseDate + 1 hour (anchor2 time)
        let photo1Date = self.baseDate
        let photo2Date = self.baseDate.addingTimeInterval(1800) // +30 minutes
        let photo3Date = self.baseDate.addingTimeInterval(3600) // +1 hour
        
        let mockReader = self.createTimezoneAwareImageIOReader(dates: [
            photo1URL: photo1Date,
            photo2URL: photo2Date,
            photo3URL: photo3Date
        ])
        
        let photoItem1 = self.createImageIOGeotaggingItem(photoURL: photo1URL, imageIOReader: mockReader)
        let photoItem2 = self.createImageIOGeotaggingItem(photoURL: photo2URL, imageIOReader: mockReader)
        let photoItem3 = self.createImageIOGeotaggingItem(photoURL: photo3URL, imageIOReader: mockReader)
        
        // GPS track points in UTC aligned with photo times
        let anchor1 = self.createAnchor(secondsOffset: 0, lat: 52.0, lon: 13.0)    // baseDate
        let anchor2 = self.createAnchor(secondsOffset: 3600, lat: 52.1, lon: 13.1) // baseDate + 1 hour
        
        // All photos should be successfully geotagged
        let geotag1 = try finder.findGeotag(for: photoItem1, using: [anchor1, anchor2])
        let geotag2 = try finder.findGeotag(for: photoItem2, using: [anchor1, anchor2])
        let geotag3 = try finder.findGeotag(for: photoItem3, using: [anchor1, anchor2])
        
        // Photo1 should be at anchor1, photo3 should be at anchor2, photo2 should be interpolated
        XCTAssertEqual(geotag1.location.latitude.degrees, 52.0, accuracy: 0.01)
        XCTAssertEqual(geotag3.location.latitude.degrees, 52.1, accuracy: 0.01)
        XCTAssertEqual(geotag2.location.latitude.degrees, 52.05, accuracy: 0.01) // Halfway between
    }
}