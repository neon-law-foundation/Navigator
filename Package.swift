// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Navigator",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
    ],
    products: [
        .library(name: "NavigatorDAL", targets: ["NavigatorDAL"]),
        .library(name: "NavigatorRules", targets: ["NavigatorRules"]),
        .library(name: "NavigatorElementary", targets: ["NavigatorElementary"]),
        .library(name: "NavigatorOIDCMiddleware", targets: ["NavigatorOIDCMiddleware"]),
        .library(name: "NavigatorDatabaseService", targets: ["NavigatorDatabaseService"]),
        .library(name: "NavigatorWeb", targets: ["NavigatorWeb"]),
        .executable(name: "NavigatorApp", targets: ["NavigatorApp"]),
        .executable(name: "NavigatorCLI", targets: ["NavigatorCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.52.2"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.33.2"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.13.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.8.1"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.12.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.0"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.8.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(
            url: "https://github.com/swift-server/async-http-client.git",
            from: "1.0.0"
        ),
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.7.1"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "5.0.0"),
        .package(
            url: "https://github.com/apple/swift-openapi-generator.git",
            from: "1.10.3"
        ),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.9.0"),
        .package(url: "https://github.com/vapor/swift-openapi-vapor.git", from: "1.0.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "7.3.0"),
        .package(url: "https://github.com/apple/swift-configuration.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor-community/vapor-elementary.git", from: "0.2.2"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "GenerateSeedsExec",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ]
        ),
        .plugin(
            name: "GenerateSeedsPlugin",
            capability: .buildTool(),
            dependencies: ["GenerateSeedsExec"]
        ),
        .target(
            name: "NavigatorRules",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            plugins: ["GenerateSeedsPlugin"]
        ),
        .target(
            name: "NavigatorDAL",
            dependencies: [
                "NavigatorRules",
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "FluentSQL", package: "fluent-kit"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Yams", package: "Yams"),
            ],
            exclude: [
                "README.md",
                "ERD.svg",
                "ERD.png",
                "ERD.md",
                "export-erd.sh",
            ],
            resources: [
                .copy("Examples"),
                .copy("Seeds"),
            ]
        ),
        .target(
            name: "NavigatorElementary",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ]
        ),
        .target(
            name: "NavigatorOIDCMiddleware",
            dependencies: [
                "NavigatorDAL",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
        .target(
            name: "NavigatorDatabaseService",
            dependencies: [
                "NavigatorDAL",
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
        .target(
            name: "NavigatorWeb",
            dependencies: [
                "NavigatorDAL",
                "NavigatorOIDCMiddleware",
                "NavigatorDatabaseService",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIVapor", package: "swift-openapi-vapor"),
                .product(name: "Queues", package: "queues"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoSES", package: "soto"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Elementary", package: "elementary"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Vapor", package: "vapor"),
            ],
            resources: [
                .copy("openapi.yaml")
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        .executableTarget(
            name: "NavigatorApp",
            dependencies: [
                "NavigatorDatabaseService",
                "NavigatorWeb",
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "VaporElementary", package: "vapor-elementary"),
                .product(name: "Elementary", package: "elementary"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            resources: [
                .copy("Content")
            ]
        ),
        .executableTarget(
            name: "NavigatorCLI",
            dependencies: [
                "NavigatorRules",
                "NavigatorDAL",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [
                .copy("AgentDocumentation")
            ]
        ),
        .testTarget(
            name: "NavigatorDALTests",
            dependencies: [
                "NavigatorDAL",
                "NavigatorOIDCMiddleware",
                "NavigatorRules",
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "NavigatorCLITests",
            dependencies: [
                "NavigatorCLI",
                "NavigatorRules",
                "NavigatorDAL",
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "NavigatorWebTests",
            dependencies: [
                "NavigatorWeb",
                "NavigatorDAL",
                "NavigatorOIDCMiddleware",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Queues", package: "queues"),
            ]
        ),
        .testTarget(
            name: "NavigatorWebStagingE2ETests",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .testTarget(
            name: "NavigatorAppTests",
            dependencies: [
                "NavigatorApp",
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
