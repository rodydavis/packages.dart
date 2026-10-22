// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "flutter_sms",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "flutter-sms", targets: ["flutter_sms"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "flutter_sms",
      dependencies: []
    )
  ]
)
