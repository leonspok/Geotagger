#!/bin/sh

# Fetch tags from remote
echo "Fetching tags from remote..."
git fetch --tags

# Get current version from git tag
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Get latest tag from main branch
LATEST_TAG=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "")
LATEST_VERSION=$(echo "$LATEST_TAG" | sed 's/^v//')

# Check if current commit has the latest tag
if [ -n "$LATEST_TAG" ] && [ "v$CURRENT_VERSION" != "$LATEST_TAG" ]; then
    echo "Warning: Current version (v$CURRENT_VERSION) is not the latest tag from main branch ($LATEST_TAG)"
    echo "Do you want to continue? (y/n)"
    read -r response
    if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
        echo "Build cancelled."
        exit 1
    fi
fi

# Run tests before building
echo "Running tests..."
swift test
if [ $? -ne 0 ]; then
    echo "Tests failed. Build cancelled."
    exit 1
fi
echo "All tests passed!"

# Set version and commit hash for build
VERSION=$CURRENT_VERSION
COMMIT_HASH=$CURRENT_COMMIT

# Create temporary Version.swift with actual values
VERSION_FILE="Sources/CLI/Version.swift"
cp "$VERSION_FILE" "$VERSION_FILE.backup"

sed -i '' \
    -e "s/VERSION_NUMBER/$VERSION/g" \
    -e "s/GIT_COMMIT_HASH/$COMMIT_HASH/g" \
    "$VERSION_FILE"

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

# Restore original Version.swift
mv "$VERSION_FILE.backup" "$VERSION_FILE"

echo "Universal binary created successfully!"
echo "Version: v$VERSION ($COMMIT_HASH)"
file geotagger