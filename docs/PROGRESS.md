# Progress: Qodi v1.0

| Date | Task | What changed |
|---|---|---|
| 2 Nov 2026 | T0.1–T0.4 Skeleton | Spec approved (uses SliceLibrary 0.7.0). Xcode project copied from Duly's set-up (folder-synchronised groups): iPhone only, portrait, iOS 17, Swift 6, bundle `uk.slice-of-life.qrscanner`, display name Qodi, Hotspot Configuration entitlement, camera and photo-add usage text. SliceLibrary 0.7.0 linked (SliceUI, SliceQR, SliceRating, SlicePurchases, SliceAnalytics). `Packages/ScanKit`. Placeholder tabs on the Qodi themes. StoreKit test file with `qr_pro_weekly` (3-day trial) and `qr_pro_yearly`. CI: ScanKit tests + coverage, iPhone tests, Xcode 26.1 compile check, Release build. Placeholder icon (final icon in Phase 4) |
| 2 Nov 2026 | T1.1–T1.7 ScanKit | Test-first scan engine, 57 tests, 100% line coverage on CI: `BarcodeFormat` (names for Vision and AVFoundation, UPC-A from EAN-13), `PayloadParser` (links, Wi-Fi with escapes, vCard, MECARD, VEVENT/VCALENDAR, geo, tel, SMSTO/sms:, mailto/MATMSG, product barcodes, text), `SafeLink` (look-alike brands, bare IP, shorteners, plain http, broken), `CSVWriter` (RFC 4180), `QRPayloadBuilder` for the 8 Create types with round-trip tests. Every sample code in the mockup is a test |

## Waiting on

- Gonzalo: free about 20 GB on the Mac, clone, set the signing team, ⌘R (M0 ✅).
- UK title: "Qodi:" vs "Vide:" to confirm.
