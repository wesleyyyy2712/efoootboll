// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EFootballAssistant",
    platforms: [.iOS(.v17)],
    products: [.library(name: "EFootballAssistant", targets: ["EFootballAssistant"])],
    targets: [
        .target(name: "EFootballAssistant", path: "Sources/EFootballAssistant"),
        .testTarget(name: "EFootballAssistantTests", dependencies: ["EFootballAssistant"], path: "Tests/EFootballAssistantTests")
    ]
)
