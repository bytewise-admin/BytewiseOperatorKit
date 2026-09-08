# BytewiseOperatorKit — the official Swift SDK (operator companion)

The Swift client for the Bytewise Solutions **operator API** (the `v1-operator-mobile` OpenAPI
contract). This is the kit an operator's own companion app uses to read and act on their projects:
crash triage, feedback, revenue, feature board, flags, stores, customers, status.

It is **not** `BytewiseClientKit`. Every call here is **authenticated** — a personal access token
injected by a credential provider, plus `X-Requested-With` on unsafe methods — and scoped to the
operator's own projects. `BytewiseClientKit` is the anonymous, project-scoped kit you embed in a
customer-facing app.

Platforms: iOS 17+, macOS 14+. Deliberately higher floors than `BytewiseClientKit`: this ships to one
operator's own app, where moving to a current OS is free.

## Installation

```swift
.package(url: "https://github.com/bytewise-admin/BytewiseOperatorKit", from: "0.1.0")
```

```swift
.product(name: "BytewiseOperatorKit", package: "BytewiseOperatorKit")
```

> **This repository is a publication MIRROR — do not open pull requests against it.** The source of
> truth is the private Bytewise Solutions repository; this tree is produced by `scripts/swift-kit-mirror.sh`
> and pushed here. Issues are welcome; code changes are made upstream.
>
> **Status 2026-09-08:** the repository exists and the first release version is **0.1.0**. The snippet
> above works from the moment the `0.1.0` tag is pushed here — until then, resolution finds no version.
> Inside the source repository the kit is consumable with `.package(path: "sdk/swift/BytewiseOperatorKit")` and always
> was; what did not work, and is what this mirror fixes, is `.package(url:)` against the source
> repository — the manifest lives under `sdk/swift/` rather than at the root, the internal release tag
> `swift-sdk-v0.2.0` is not a version SwiftPM recognizes, and that repository is private. See
> `docs/deployment/swift-sdk-packaging.md` upstream.

Licensed MIT (`LICENSE` in this package). The licence covers this kit, not the Bytewise Solutions
server — see `LICENSE-PACKAGES.md` in the source repository for the exact scope.

## Usage

```swift
import BytewiseOperatorKit

let client = OperatorClient(
    baseURL: URL(string: "https://api.your-server.com")!,
    credential: KeychainCredentialProvider())

let overview = try await client.dashboard.summary(project: "acme-notes")
let issues   = try await client.crashes.issues(project: "acme-notes")
_ = try await client.crashes.triageIssue(project: "acme-notes", externalId: issues.items[0].externalId, ...)
```

The façades on `OperatorClient` are the **only** public API: `dashboard`, `crashes`, `feedback`,
`revenue`, `account`, `featureBoard`, `pairing`, `localization`, `inbox`, `tasks`, `abuse`,
`storesReviews`, `status`, `customers`, `changelog`, `roadmap`, `flags`, `links`. Each maps the
internal generated transport types to stable public models and one error taxonomy.

## Offline reads

`OperatorClient.cache` is the read-cache seam (in-memory by default). It backs the timestamped
last-successful-response / stale-banner model an operator app wants on a flaky connection; supply your
own `OperatorReadCache` to persist it.

## Architecture

The transport core under `Sources/BytewiseOperatorKit/Generated/` is produced by
`apple/swift-openapi-generator` in the **manual/CLI** workflow with **committed** output — not the
build plugin — so the generated tree is drift-checkable and a consumer never runs code generation.
The generated code is `internal`; the hand-written wrapper (`OperatorClient`, the façades, the error
taxonomy) is the only public surface and the package's stability boundary.

A consumer therefore resolves exactly four Apple packages — `swift-openapi-runtime`,
`swift-openapi-urlsession`, `swift-http-types` and `swift-collections`. The generator is declared for
the regeneration command plugin only, and SwiftPM prunes it for anyone who is not regenerating
(measured 2026-09-08).

## A note on what publishing this exposes

The `openapi.json` in this package describes the operator API surface — 61 operations. Publishing the
kit publishes that shape. That is intended for a companion SDK, and it is not a credential: every one
of those operations is authenticated and authorized server-side. It is recorded here so the choice is
visible rather than incidental.
