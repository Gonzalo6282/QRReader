# To-do: Qodi (QR Reader) v1.0

One line = one task = one commit + push. Every push is tested by GitHub Actions. ✅ = checkpoint where you look at it on the Mac.

## M0 Project skeleton
- [x] T0.1 `SPEC.md` approved, `tasks/plan.md`, `tasks/todo.md`, `docs/PROGRESS.md`
- [x] T0.2 Xcode project `QRReader.xcodeproj`: app target (iOS 17, iPhone only, portrait, Swift 6, bundle `uk.slice-of-life.qrscanner`, display name "Qodi"), unit + UI test targets, shared scheme, folder layout, Assets, String Catalog, Hotspot entitlement, Info.plist (camera, photo-add), `.gitignore`, Config (App.xcconfig, Secrets.example.xcconfig)
- [x] T0.3 SliceLibrary 0.7.0 linked (SliceUI, SliceQR, SliceRating, SlicePurchases, SliceAnalytics); placeholder tabs Scan / Create / History / Settings on the library theme
- [x] T0.4 `Packages/ScanKit` (Swift tools 6.0, Swift Testing) linked to the app; design/mockup copied; CI (ScanKit tests, iPhone tests, Xcode 26.1 compile check, Release build)
- [ ] ✅ You: free about 20 GB, clone, open project, set signing team, ⌘R on iPhone 17 Pro sim

## M1 ScanKit (test-first, 100% coverage)
- [x] T1.1 `BarcodeFormat` + display names
- [x] T1.2 `PayloadParser`: URL, text, product barcodes
- [x] T1.3 Wi-Fi (escaping), phone, SMS, email, geo
- [x] T1.4 vCard, MECARD, VEVENT
- [x] T1.5 `SafeLink` (mockup rules)
- [x] T1.6 `CSVWriter`
- [x] T1.7 `QRPayloadBuilder` (8 Create types) + round-trip tests
- [x] ✅ CI green, 100% coverage (57 tests, 620 lines)

## M2 Foundation
- [ ] T2.1 `QodiTheme.brand` / `.main`, colour assets, text styles
- [ ] T2.2 SwiftData `ScanRecord`, `CreatedCode`, container, demo data
- [ ] T2.3 `AppState` (tab, scan count, settings), `Placement` + `Event` enums, keys
- [ ] T2.4 Design gallery (debug) screen
- [ ] ✅ You: gallery vs mockup

## M3 Scanner
- [ ] T3.1 Camera permission + denied state
- [ ] T3.2 VisionKit live scanner + reticle lock + debounce
- [ ] T3.3 AVFoundation fallback
- [ ] T3.4 Torch, 1×/2×, pinch zoom, sound, vibration
- [ ] T3.5 Photo / Files / PDF scanning + "No code found" error
- [ ] ✅ You: real iPhone, damaged / small / inverted / low-light / on-screen codes, screenshot, every barcode type

## M4 Result card
- [ ] T4.1 Sheet layout per type (link, Wi-Fi, contact, phone, SMS, email, event, location, text, product)
- [ ] T4.2 Safe-link banner + full URL
- [ ] T4.3 Actions + `gate(.scanResultAction)`; Wi-Fi join + failure text
- [ ] T4.4 Favourite, delete with confirmation, save to history
- [ ] ✅ You: every action on the iPhone

## M5 History, Create, Batch
- [ ] T5.1 History list, search, segments, empty state, 3-scan gate
- [ ] T5.2 Create: type grid + 8 forms + live preview
- [ ] T5.3 Colours, logo (correction H), save to Photos / share behind `gate(.qrCreateSave)`
- [ ] T5.4 Batch: chip gate, tray, list, CSV export
- [ ] ✅ You: created codes opened by the iPhone Camera

## M6 Money + first run
- [ ] T6.1 SlicePurchases set-up, StoreKit config file, placements
- [ ] T6.2 Paywall content per placement (+ SliceLibrary PR if weekly-first needs it)
- [ ] T6.3 Onboarding flow
- [ ] T6.4 Settings (StandardSettings + app sections, Pro card, support mail, legal text)
- [ ] ✅ You: keys in Secrets.xcconfig, sandbox purchase unlocks actions, restore

## M7 Analytics + release
- [ ] T7.1 SliceAnalytics + consent + events
- [ ] T7.2 Remote Config, Crashlytics dSYM, rating prompt
- [ ] T7.3 UI tests (first run, paywall close buttons, camera denied) + screenshot capture
- [ ] T7.4 Size check, Release build, iPad-in-iPhone-mode check
- [ ] ✅ You: fresh install + full bug checklist on device
