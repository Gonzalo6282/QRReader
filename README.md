# Qodi: QR Code Reader & Barcode (Slice of Life Ltd)

iPhone QR code and barcode scanner that also creates QR codes and keeps a history. No ads, no account; scans stay on the phone. The spec and strategy docs live in the private `QRReader-docs` repo.

## Status

- [x] Phase 1: research (handoff, 1 Nov 2026)
- [x] Phase 2: clickable mockup, approved 1 Nov (`design/mockup/`)
- [ ] Phase 3: Swift/SwiftUI app, version 1.0 (see `tasks/todo.md` and `docs/PROGRESS.md`). Xcode 26.1.1, SliceLibrary 0.7.x
- [ ] Phase 4: App Store icon, screenshots, listing
- [ ] Phase 5: landing page
- [ ] Phase 6: launch video
- [ ] Phase 7: submit

[![CI](https://github.com/Gonzalo6282/QRReader/actions/workflows/ci.yml/badge.svg)](https://github.com/Gonzalo6282/QRReader/actions/workflows/ci.yml)

## Run it

1. `open QRReader.xcodeproj` (Xcode 26.1.1 or newer). The first open downloads SliceLibrary, Firebase, RevenueCat and Superwall.
2. Signing & Capabilities → Team: Slice of Life Ltd.
3. ⌘R on an iPhone simulator or your iPhone.

Keys: copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` and fill in the RevenueCat and Superwall keys; put `GoogleService-Info.plist` in `QRReader/Resources/`. Both are git-ignored. Without them the app runs with that service switched off.

## Layout

| Path | What |
|---|---|
| `QRReader/` | The app (folder-synchronised: new files appear in Xcode automatically) |
| `Packages/ScanKit/` | Scan engine: payload parsing, safe-link check, CSV, QR payloads (`swift test --package-path Packages/ScanKit`) |
| `QRReaderTests/`, `QRReaderUITests/` | App unit and UI tests |
| `design/mockup/` | Approved clickable mockup: double-click `index.html` |
| `tasks/`, `docs/PROGRESS.md` | Plan, to-do, progress log |

Shared code comes from [SliceLibrary](https://github.com/Gonzalo6282/SliceLibrary) by version tag.
