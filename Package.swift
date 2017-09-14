// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "SwiftServerHTTP",
    targets: [
        Target(name: "CHTTPParser"),
        Target(name: "HTTP", dependencies: [.Target(name: "CHTTPParser")]),
    ],
    dependencies: [
        .Package(url: "https://github.com/gtaban/security.git", majorVersion: 0),
        .Package(url: "https://github.com/gtaban/TLSService.git", majorVersion: 0),
        ]
)

