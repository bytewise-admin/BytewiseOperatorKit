// swift-tools-version: 6.0
import PackageDescription

// BytewiseOperatorKit — the official Swift SDK for the Bytewise Solutions operator-companion
// mobile API (the `v1-operator-mobile` OpenAPI contract, bearer-only).
//
// The transport core under Sources/BytewiseOperatorKit/Generated/ is produced by
// apple/swift-openapi-generator in the MANUAL/CLI workflow with COMMITTED output (not the
// build-plugin) so the generated tree is drift-checkable — see ../regenerate.sh. The generated
// code is `internal`; the hand-written wrapper (OperatorClient, façades, error taxonomy) is the
// only public surface and the package's stability boundary.
//
// Generator/runtime versions are pinned exactly (see ../regenerate.sh header). Generator upgrades
// land as dedicated changes so generator churn stays distinguishable from contract churn.
let package = Package(
    name: "BytewiseOperatorKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "BytewiseOperatorKit", targets: ["BytewiseOperatorKit"]),
    ],
    dependencies: [
        // Command plugin used only by ../regenerate.sh to (re)generate the committed core.
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.12.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.3.1"),
        // The wrapper imports HTTPTypes directly (Credential.swift, Errors.swift). It arrives
        // transitively via swift-openapi-runtime, but a DOWNSTREAM test bundle (e.g. the iOS app's
        // XCTest target) building this kit under the testability build fails to link the transitive
        // product ("Undefined symbols: HTTPTypes.*"). Declare it explicitly (a package should depend
        // on what it imports); pinned exact to the version openapi-runtime 1.12.0 already resolves.
        .package(url: "https://github.com/apple/swift-http-types", exact: "1.6.0"),
    ],
    targets: [
        .target(
            name: "BytewiseOperatorKit",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
            // NOTE: no OpenAPIGenerator build-plugin here on purpose — output is committed under
            // Generated/ and regenerated via the command plugin (../regenerate.sh), so the drift
            // gate can diff a clean regeneration against the committed tree.
        ),
        .testTarget(
            name: "BytewiseOperatorKitTests",
            dependencies: [
                "BytewiseOperatorKit",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            ]
        ),
    ]
)
