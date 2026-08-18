// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Shimmer",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "Shimmer",
      targets: ["Shimmer"]
    )
  ],
  targets: [
    .target(name: "Shimmer"),
    .testTarget(
      name: "ShimmerTests",
      dependencies: ["Shimmer"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
