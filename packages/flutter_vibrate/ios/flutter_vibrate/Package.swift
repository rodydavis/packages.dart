// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_vibrate",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "flutter-vibrate", targets: ["flutter_vibrate"])
    ],
    dependencies: [
         .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_vibrate",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
