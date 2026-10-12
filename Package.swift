// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "Pulsebar",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "PulsebarKit", linkerSettings: [.linkedFramework("IOKit")]),
    .executableTarget(name: "Pulsebar", dependencies: ["PulsebarKit"]),
    .testTarget(name: "PulsebarKitTests", dependencies: ["PulsebarKit"]),
  ]
)
