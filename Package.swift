// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EventStore",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "PostgresSource",
            targets: ["Source", "PostgresSource"]),
        .library(
            name: "PostgresProjection",
            targets: ["Projection", "PostgresProjection"]),

        .library(
            name: "SQLiteSource",
            targets: ["Source", "SQLiteSource"]),
        .library(
            name: "SQLiteProjection",
            targets: ["Projection", "SQLiteProjection"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/codewinsdotcom/PostgresClientKit", from: "1.5.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Source",
            dependencies: []),
        .testTarget(
            name: "SourceTests",
            dependencies: ["Source"]),
        .target(
            name: "Projection",
            dependencies: []),
        .testTarget(
            name: "ProjectionTests",
            dependencies: ["Projection"]),

        .target(
            name: "Postgres",
            dependencies: ["PostgresClientKit"],
            resources: [.process("Schema/schema.sql")]),
        .target(
            name: "PostgresSource",
            dependencies: ["Source", "Postgres"]),
        .testTarget(
            name: "PostgresSourceTests",
            dependencies: ["PostgresSource"]),
        .target(
            name: "PostgresProjection",
            dependencies: ["Projection", "Postgres"]),
        .testTarget(
            name: "PostgresProjectionTests",
            dependencies: ["PostgresProjection", "PostgresSource"]),

        .target(
            name: "SQLite",
            dependencies: [],
            resources: [.process("Schema/schema.sql")]),
        .target(
            name: "SQLiteSource",
            dependencies: ["Source", "SQLite"]),
        .testTarget(
            name: "SQLiteSourceTests",
            dependencies: ["SQLiteSource"]),
        .target(
            name: "SQLiteProjection",
            dependencies: ["Projection", "SQLite"]),
        .testTarget(
            name: "SQLiteProjectionTests",
            dependencies: ["SQLiteProjection", "SQLiteSource"]),

    ]
)
