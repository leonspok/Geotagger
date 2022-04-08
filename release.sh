#!/bin/sh

swift build \
    --configuration release \
    --arch arm64 --arch x86_64

cp -f \
    .build/apple/Products/Release/geotagger \
    geotagger

