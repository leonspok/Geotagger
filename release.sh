#!/bin/sh

# Build for arm64
swift build \
    --configuration release \
    --arch arm64

# Build for x86_64
swift build \
    --configuration release \
    --arch x86_64

# Create universal binary
lipo -create -output geotagger \
    .build/arm64-apple-macosx/release/geotagger \
    .build/x86_64-apple-macosx/release/geotagger

echo "Universal binary created successfully!"
file geotagger