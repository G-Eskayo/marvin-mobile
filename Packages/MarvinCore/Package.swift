// swift-tools-version: 6.2
import PackageDescription

// Platform-agnostic core for MARVIN Mobile (PRD G-Eskayo/marvin#152): talking to the
// mobile backend over Tailscale, and the connection state the app shows.
// Builds for macOS too so `swift test` runs without a simulator.
let package = Package(
    name: "MarvinCore",
    platforms: [.iOS("26.0"), .macOS("26.0")],
    products: [.library(name: "MarvinCore", targets: ["MarvinCore"])],
    targets: [
        .target(name: "MarvinCore"),
        .testTarget(name: "MarvinCoreTests", dependencies: ["MarvinCore"]),
    ]
)
