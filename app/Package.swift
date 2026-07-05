// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Conduit",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Conduit", targets: ["Conduit"])
    ],
    targets: [
        .executableTarget(
            name: "Conduit",
            path: "Sources/Conduit"
        )
    ]
)
