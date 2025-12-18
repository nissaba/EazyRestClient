// swift-tools-version:6.2
import PackageDescription

let package = Package(
  name: "EazyRestClient",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v15),
    .watchOS(.v8),
    .visionOS(.v1)
  ],
  products: [
    .library(name: "EazyRestClient", targets: ["EazyRestClient"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "EazyRestClient", dependencies: []),
    .testTarget(name: "EazyRestClientTests", dependencies: ["EazyRestClient"]),
  ]
)
