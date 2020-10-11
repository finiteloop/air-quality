// swift-tools-version:5.1
// Copyright 2020 Bret Taylor
import PackageDescription

let package = Package(
    name: "AQI",
    products: [
        .library(name: "AQI", targets: ["AQI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.12.0"),
    ],
    targets: [
        .target(name: "AQI", dependencies: ["SwiftProtobuf"], path: "."),
    ]
)
