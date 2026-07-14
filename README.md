# CleanSpace v2

CleanSpace is a native SwiftUI macOS 26 storage-visibility and user-directed cleanup utility. Trust is the central contract: every size carries an explicit measurement confidence, and no unknown path is eligible for deletion.

## Current implementation

This repository currently contains a buildable foundation slice:

- `CleanSpaceCore`, with domain, presentation, infrastructure-port, and shared UI layers
- separate `CleanSpaceDirect` and `CleanSpaceStore` executable entry points
- a production-style `CleanSpace.xcodeproj` with shared Direct and Store schemes
- Hardened Runtime configuration for both applications and Store-only App Sandbox entitlements
- Store Home-folder selection with a persisted security-scoped bookmark and visible denied/stale/restored states
- injected distribution capabilities through `AppEnvironment`
- immediate Foundation volume-capacity reporting
- cancellation-aware background scans of the registered user cache and Trash roots
- item-level scans of registered developer caches, AI/model caches, device backups, Application Support, Containers, Xcode data, and major personal folders
- safe cache preselection, model/backup/Trash opt-in selection, and reveal-only unknown application or personal data
- rule-validated permanent deletion and move-to-Trash execution with explicit confirmation totals
- post-cleanup capacity remeasurement and APFS estimate-difference explanations
- progressive ring replacement and a derived `System & Unclassified` residual
- contextual inspector, incomplete-scan reporting, and a state-driven glass cleanup shelf
- required-reason privacy manifests for displayed disk-capacity information
- contract tests for residual semantics, coverage, cleanup totals, and path containment

Cleanup is available only for items produced by the versioned local catalog. Every operation must match its registered rule identifier, distribution profile, action, and allowed-root containment. Unknown Application Support, Containers, and personal files remain reveal-only.

## Build and test

```sh
xcodebuild -project CleanSpace.xcodeproj -scheme CleanSpaceDirect build
xcodebuild -project CleanSpace.xcodeproj -scheme CleanSpaceStore build
xcodebuild -project CleanSpace.xcodeproj -scheme CleanSpaceDirect test
xcodebuild -project CleanSpace.xcodeproj -scheme CleanSpaceDirect -archivePath /tmp/CleanSpaceDirect.xcarchive CODE_SIGNING_ALLOWED=NO archive
xcodebuild -project CleanSpace.xcodeproj -scheme CleanSpaceStore -archivePath /tmp/CleanSpaceStore.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

The project requires Xcode 26 and macOS 26. `Package.swift` remains available as a fast secondary build and test surface. Bundle identifiers and the development team must be replaced with the final organization-owned values before signed distribution archives are produced.

## Build a drag-to-install disk image

```sh
./Tools/build-dmg.sh
```

The script creates `dist/CleanSpace-<version>.dmg` containing CleanSpace and an Applications shortcut. When a Developer ID Application identity is installed, the script signs the application and disk image automatically. Set `NOTARY_PROFILE` to a `notarytool` keychain profile to submit and staple the disk image. Without a Developer ID identity, the script produces an ad-hoc-signed image suitable for local installation and testing only. Local builds use a stable designated requirement so macOS permission decisions survive rebuilds with the same bundle identifier.

## Next implementation gates

1. Extract and test the bounded file-tree aggregation engine with hard-link, symlink, overlap, mounted-volume, cancellation, and file-race fixtures.
2. Add the versioned cleanup and model-signature registries, recognized-item discovery, and application-running checks.
3. Implement permanent-delete and Trash adapters behind validated cleanup plans, then capacity-before/after result measurement.
4. Add snapshot, UI, accessibility, contrast, large-fixture performance, archive, signing, and notarization verification.

## Safety invariants already encoded

- `StorageMeasurement` cannot represent unavailable bytes with a numeric value.
- available capacity is measured; `System & Unclassified` is always computed as a derived residual.
- permission failures remain unsized coverage issues.
- cleanup confirmation models permanent deletion and moved-to-Trash totals separately.
- cleanup rules use component-aware containment and reject their root itself and sibling-prefix paths.
- cleanup results require measured reclaimed capacity and never count estimates as actual results.
