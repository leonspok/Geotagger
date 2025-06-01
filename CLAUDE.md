# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project
swift build

# Build release version (universal binary for arm64 and x86_64)
./release.sh

# Run tests
swift test

# Build and run the CLI tool
swift run geotagger
```

## Architecture Overview

The Geotagger project is a Swift Package Manager-based tool for adding geolocation data to photos using GPX tracks and other geotagged photos as location references.

### Core Architecture

The project separates library functionality from the CLI interface:

- **Geotagger Library** (`Sources/Geotagger/`): Core geotagging logic
  - `Geotagger`: Main facade class that orchestrates the geotagging process
  - `GeotagFinder`: Finds appropriate geotags for photos based on time and location anchors
  - Uses protocol-based design with `GeoAnchorsLoaderProtocol` and `GeotaggingItemProtocol`

- **CLI** (`Sources/CLI/`): Command-line interface using swift-argument-parser
  - `DirectoryScanner`: Recursively scans for photos and GPX files
  - `GeotaggingCounter`: Tracks statistics during batch operations

### Key Components

**Location Anchor Sources:**
- `GPXGeoAnchorsLoader`: Loads waypoints from GPX files using CoreGPX
- `ImageIOGeoAnchorsLoader`: Extracts locations from already geotagged photos

**Geotagging Strategy:**
- Exact match: Finds closest anchor within time range (default: 60 seconds)
- Interpolation: Calculates position between two anchors (default: 240 seconds)

**ImageIO Integration:**
- `ImageIOReader`: Reads EXIF data and photo timestamps
- `ImageIOWriter`: Writes GPS data to photo EXIF metadata
- Uses Apple's ImageIO framework for metadata manipulation

### Dependencies

- **CoreGPX** (0.9.0): GPX file parsing
- **swift-argument-parser** (1.1.1): CLI interface
- Minimum Swift 5.5, macOS 11.0+