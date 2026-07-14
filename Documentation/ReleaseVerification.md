# Release verification

## Completed without Apple distribution credentials

- Swift package tests and Xcode-hosted unit/integration tests
- Direct and Store Release builds with code signing disabled
- Direct and Store unsigned archives
- ad-hoc signed drag-to-install DMG for local testing
- rule containment, adapter routing, scanner recovery, progressive state, and contrast checks
- required-reason privacy manifests and App Review path/action inventory

## Requires Developer ID or App Store credentials

- set the organization-owned Team ID and final bundle identifiers
- Developer ID signing, hardened-runtime signature validation, notarization, stapling, and Gatekeeper assessment on a clean Mac
- Apple Distribution signing and App Store archive upload
- App Review submission and external TestFlight/App Store validation

An ad-hoc DMG can be tested locally, but it is not suitable for sharing with general users because Gatekeeper cannot establish a trusted developer identity.
