// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Hume",
  platforms: [
    .iOS(.v16),
    .macOS(.v12),
  ],
  products: [
    // Products define the executables and libraries a package produces, making them visible to other packages.
    .library(
      name: "Hume",
      targets: ["Hume"]),
    .library(
      name: "HumeTestingUtils",
      targets: ["HumeTestingUtils"]
    ),
    .library(
      name: "HumeServer",
      targets: ["HumeServer"]
    ),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .target(
      name: "Hume",
      swiftSettings: [
        .define("HUME_WIDGET", .when(platforms: [.iOS]))
      ]),
    .testTarget(
      name: "HumeTests",
      dependencies: ["Hume"],
      path: "Tests/HumeTests"
    ),
    .testTarget(
      name: "HumeServerTests",
      dependencies: ["HumeServer", "Hume"],
      path: "Tests/HumeServerTests"
    ),
    .target(
      name: "HumeTestingUtils",
      dependencies: ["Hume"]
    ),
    .target(
      name: "HumeServer",
      dependencies: ["Hume"],
      swiftSettings: [
        .define("HUME_SERVER", .when(platforms: [.macOS, .linux]))
      ]
    ),
  ]
)
