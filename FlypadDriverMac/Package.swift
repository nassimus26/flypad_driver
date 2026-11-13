// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlypadDriverMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "FlypadDriverMac",
            targets: ["FlypadDriverMac"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FlypadDriverMac",
            path: "FlypadDriverMac",
            exclude: [
                "Info.plist",
                "FlypadDriverMac.entitlements"
            ],
            linkerSettings: [
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("GameController"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
