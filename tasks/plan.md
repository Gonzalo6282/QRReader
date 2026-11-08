# Build plan: Qodi (QR Reader) v1.0

Source: `SPEC.md` in the private `QRReader-docs` repo (approved 2 Nov 2026), the approved mockup
(`design/mockup/index.html`), Build Doc 2. Every task ends with: tests green → `docs/PROGRESS.md`
updated → commit + push to `main`.

## How the work runs

- **Where code is written:** a cloud clone of `github.com/Gonzalo6282/QRReader`. Each task is pushed
  to `main`. The Mac folder (`~/Desktop/QrCodeReader/QRReader`) gets it with **Source Control → Pull**
  in Xcode (or `git pull`).
- **Tests:** GitHub Actions (macOS 26 runner) runs `swift test` for ScanKit and `xcodebuild test` on an
  iPhone simulator after every push, plus a compile check with Xcode 26.1 (the Mac's version).
  I read the result and fix failures before moving on.
- **On the Mac (✅ checkpoints):** signing, real-iPhone checks (camera, Wi-Fi join, purchases) and
  looking at the UI against the mockup.
- **Xcode project:** folder-synchronised groups (Xcode 16+ format), copied from Duly's set-up, so new
  Swift files appear in Xcode by themselves.
- **Library:** SliceLibrary from tag 0.7.1 ("Up to Next Minor"). Library changes only on their own
  branch + pull request in SliceLibrary, generic, with tests and a new tag.

## Milestones

| # | Milestone | What | Checkpoint (you on the Mac) |
|---|---|---|---|
| M0 | Project skeleton | Xcode project (iPhone only, iOS 17, Swift 6), SliceLibrary linked, ScanKit package, test targets, CI, mockup in repo | Open project, set signing team, ⌘R shows the tab bar on the iPhone 17 Pro simulator |
| M1 | Scan engine | `ScanKit`, test-first, 100% coverage: payload parser (all types), safe-link check, barcode formats, CSV, QR payload builders for Create | CI green (nothing to look at) |
| M2 | Foundation | Qodi theme (brand dark + system light/dark), SwiftData models, app state, history 3-scan rule, Placement + Event enums | Design gallery screen vs the mockup |
| M3 | Scanner | Live camera (VisionKit + AVFoundation fallback), reticle lock, torch, 1×/2× + pinch zoom, sound/vibration, photo/Files/PDF scan, camera-denied state | **Real iPhone:** scan the bug-checklist codes |
| M4 | Result card | Sheet per type, safe-link banner, actions (Safari, Wi-Fi join, contact, calendar, maps, call, SMS, email, copy, share), favourite, delete | Real iPhone: every action, Wi-Fi join |
| M5 | History, Create, Batch | History (search, segments, gate after 3), Create (8 types, colours, logo, save/share), batch tray + list + CSV | Created codes read by the iPhone Camera |
| M6 | Money + first run | Onboarding flow, SlicePurchases set-up, 6 placements, native paywall content, Settings (StandardSettings + app sections), support mail, legal text | Needs keys and products (below); sandbox purchase unlocks actions |
| M7 | Analytics + release | SliceAnalytics + events, consent (EEA/UK), Remote Config, Crashlytics dSYM, rating prompt, UI tests, size check, Release build, bug checklist | Fresh install walk-through + full bug checklist on device |

## What I need from you, and when

| When | What |
|---|---|
| M0 ✅ | Pull the repo on the Mac (commands in the hand-over), choose the Slice of Life Ltd team in Signing, ⌘R. About 20 GB free disk |
| M3 ✅ | Your iPhone connected in Developer Mode |
| M4 | Hotspot Configuration capability on the App ID (done per your list) |
| M6 | Products `qr_pro_weekly` ($9.99/week, 3-day trial) and `qr_pro_yearly` ($59.99/year) in one subscription group in App Store Connect: I can create them through Chrome on your Mac when we get there, you confirm before anything is saved. Sandbox tester. RevenueCat project (entitlement `pro`, offering) and Superwall app (placements) with their keys in `Config/Secrets.xcconfig` on the Mac |
| M7 | Firebase iOS app for `uk.slice-of-life.qrscanner`; `GoogleService-Info.plist` placed in `QRReader/Resources/` on the Mac (git-ignored, never sent to me) |

## Module notes (decisions from the spec, no new choices)

**ScanKit (M1).** Pure Swift, Foundation only, Swift Testing, macOS + iOS so `swift test` runs on CI.
`BarcodeFormat` (qr, ean13, ean8, upcA, upcE, code128, code39, dataMatrix, pdf417, aztec) with display
names as in the mockup ("EAN-13", "UPC-A", "Code 128"). `Payload` + `PayloadParser.parse(raw:format:)`:
URL (http/https), `WIFI:` (T, S, P, H, escaped `\;` `\:` `\\`), `BEGIN:VCARD` (FN, N, ORG, TEL, EMAIL,
URL, ADR), `MECARD:`, `BEGIN:VEVENT` / `BEGIN:VCALENDAR` (SUMMARY, DTSTART, DTEND, LOCATION), `geo:`,
`tel:`, `SMSTO:` / `sms:`, `mailto:` (subject, body), `MATMSG:`; numeric 8–14 digits on a 1D format →
product; anything else → text. `SafeLink.check(url)` → `.ok` / `.warn(kind)` with the mockup's
rules in this order: broken, look-alike brand (paypa1, g00gle, amaz0n, app1e, micros0ft), bare IP,
shortener (bit.ly, tinyurl.com, t.co, goo.gl), not https. `CSVWriter` (RFC 4180) for batch export.
`QRPayloadBuilder` for Create: link, text, Wi-Fi (escaped), vCard 3.0, mailto, tel, SMSTO, social
(Instagram/TikTok/X handle → URL). Round-trip tests: build → parse → same fields.

**Foundation (M2).** `QodiTheme.brand` = `SliceTheme` always dark: lime `#7fee64`, onAccent black,
canvas `#000000`, surface `#181818`, surfaceAlt `#242624`, ink `#ddffdc`, inkSecondary `#8cab87`.
`QodiTheme.main` = `SliceTheme(appearance: .system)` with the mockup's light/dark greens (bg
`#f1f3ef`/`#000000`, surface `#ffffff`/`#1b1e1a`, label `#0e130d`/`#eef3ec`, lime-ink `#2a7d17`/`#7fee64`).
SwiftData: `ScanRecord` (id, raw, format, kind, title, date, isFavourite, source camera/photo/batch),
`CreatedCode` (id, type, fields JSON, colour hex, hasLogo, date). `scanCount` in UserDefaults for the
3-scan history rule (not reset by deleting).

**Scanner (M3).** `DataScannerViewController` (recognizedDataTypes: barcode of all ScanKit symbologies,
qualityLevel .accurate, isHighlightingEnabled false; our own reticle) when `isSupported && isAvailable`,
otherwise `AVCaptureSession` + `AVCaptureMetadataOutput`. Photo: `PhotosPicker` + `fileImporter`
(images, PDF) → `VNDetectBarcodesRequest` (inverted retry with `CIColorInvert`). Debounce: the same
payload is ignored for 2 s. Sound (`AudioServicesPlaySystemSound`) and haptic follow Settings.

**Result card (M4).** One sheet, sections per `Payload`, wording from the mockup. Primary action and
every paid action go through `PaywallService.shared.gate(.scanResultAction)`. Links open with
`UIApplication.open` (Safari, never an in-app browser). Wi-Fi: `NEHotspotConfigurationManager.apply`;
failure text "Couldn't join <network>. The password in this code may be out of date." Contact:
`CNContactViewController(forNewContact:)`. Calendar: `EKEventEditViewController`. Auto-open links (Pro
setting) skips the card only when `SafeLink` is `.ok`.

**History, Create, Batch (M5).** History: `@Query` sorted newest first, `.searchable`, segments Scanned /
Favourites / Created, empty state "No scans yet". Opening the tab after 3 scans without Pro →
`gate(.historyOpen)`; closing returns to the previous tab. Create: type grid → form → live preview
(SliceQR, recoloured, logo badge with correction `.high`) → Save to Photos / Share behind
`gate(.qrCreateSave)`. Batch: chip → `gate(.batchScan)`, tray "N codes · View list", list with CSV
export through `ShareLink`.

**Money + first run (M6).** Onboarding: welcome (reticle lock animation) → camera warm-up → system
prompt (or "Scan from photos instead") → "More than your Camera app" → paywall
`gate(.onboardingEnd, onFinished:)` (close after 2.5 s) → scanner; consent alert after the paywall closes
(EEA/UK). Placements: `onboarding_end`, `scan_result_action`, `qr_create_save`, `history_open`,
`batch_scan`, `settings_upgrade`. `PaywallContent` per placement: heading "Do everything with your scans",
5 benefits, context line (e.g. "Open, join, save and share with Pro"), trial timeline. **Library gap to
check:** the template selects the yearly plan first; the spec wants weekly (trial) selected. If 0.7.0 has
no option for it, I add one in SliceLibrary on its own branch + PR (generic `initialPlan` setting) and
tag 0.7.1 or 0.8.0. Settings: `StandardSettings` with a Pro card header, app sections (Sound, Vibration,
Open links automatically), `account: nil`.

**Analytics + release (M7).** `Event` enum: first_open, onboarding_complete, camera_permission,
scan_success, paywall_view, qr_created, result_action, consent, support_email (trial/purchase events come
from RevenueCat → Firebase). Remote Config default `onboarding_soft_paywall = true`. Rating:
`RatingPrompt` after successful actions (moment `actionDone`). Checks: app size (Release archive, App
Thinning report) under about 30 MB, Release configuration compiles, iPad runs the iPhone app.

## Risks

| Risk | Plan |
|---|---|
| Disk nearly full on the Mac (8.9 GB) | Free about 20 GB before M0 ✅; CI does most builds |
| Library paywall selects yearly first | Small generic PR to SliceLibrary (M6) |
| Firebase + RevenueCat + Superwall push size past 30 MB | Measure at M6 with a Release archive; drop unused Firebase products |
| `DataScannerViewController` not on older iPhones | AVFoundation fallback (M3) |
| Hotspot capability missing from the provisioning profile | Checked at M4 on device |
