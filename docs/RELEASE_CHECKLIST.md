# Release checklist — First Colors 1.1

Status as of the 1.1 release check (version 1.1, build 2). ✅ = done and verified in this repo, ⬜ = needs you.

## 1. Must do before submitting

| | Item | Notes |
|---|---|---|
| ⬜ | **Record voice lines** (210 files: 84 from 1.0, 126 new in 1.1) | Listed with exact words in `Resources/Audio/README.md`. Release builds are silent for names/sentences without them. |
| ⬜ | **Native-speaker review of Arabic** | Names and sentences in `scripts/drawings.py` (regenerate after edits), including the 1.1 category names in `CATEGORIES` and `CategoryDetails.spokenName`. |
| ⬜ | **Original-character check** | Look over `vehicles.png`, `rescue_pups.png`, `super_kids.png` (`DrawingPreviewTests`) once more before submitting: no franchise names, looks, badges or emblems (CLAUDE.md §2.9). |
| ⬜ | **Bundle Fredoka font** | Drop 3 TTFs + `OFL.txt` into `Resources/Fonts/`. Optional: the rounded system font is used otherwise. |
| ⬜ | **Bundle id and signing team** | Replace `com.firstcolors.KidsColoring`; set your team. |
| ⬜ | **Privacy policy URL** | Required for the Kids category even when no data is collected. One short page: "First Colors collects no data, has no accounts, ads or analytics, and works offline." |
| ⬜ | **Final app icon** | `AppIcon.png` is a placeholder rendered from the apple drawing (`scripts/make_app_icon.sh`). |
| ✅ | **Screenshots** | `./scripts/appstore-screenshots.sh` → `AppStore/screenshots/iphone-6.9/` (1320×2868) and `ipad-13/` (2064×2752), 6 each. Upload in order 01–06. |
| ⬜ | **On-device pass** | Real iPhone and iPad: sounds and volume balance, palm on screen while drawing, Photos permission and save, Back up → Files → Restore, VoiceOver, Guided Access. |
| ⬜ | **Force-quit during save** | Draw, lift, force-quit immediately from the app switcher, relaunch: the last stroke is there and nothing is corrupt. |
| ⬜ | **Storage-full check** | Fill a test device, color: the app keeps working and simply doesn't save (covered by tests with a read-only folder). |

## 2. Kids category (App Store Review Guidelines 1.3 and 5.1.4)

| | Requirement | Where it's met |
|---|---|---|
| ✅ | No third-party analytics or advertising | Zero dependencies; links only Apple frameworks (checked with `otool -L` on the Release build). |
| ✅ | No data collection, no tracking | `PrivacyInfo.xcprivacy`: tracking off, no collected data types. No accounts, names, photos or recordings from kids. |
| ✅ | No links out of the app, no purchases, no ads | None exist. `scripts/check-no-network.sh` bans `URLSession`, web views, Safari views and URLs. No networking symbols in the Release binary. |
| ✅ | Parental gate in front of anything for grown-ups | Press-and-hold 3 seconds (`ParentGateView`) before settings, profiles (including "+" on the profile picker), Save to Photos, backup/restore and Clear all art. UI-tested: a tap doesn't open it, a 3.5 s hold does. |
| ✅ | Content appropriate for 5 and under | Fruits, vegetables, vehicles, puppies and little heroes, all with smiling faces; no text needed. |
| ✅ | No licensed or franchise characters | All 1.1 characters are original. Names checked against known shows (renamed Star Girl → Little Star, Super Kitty → Cape Kitty); no red cross emblem on the ambulance. |
| ✅ | Photos access only when a grown-up asks | Add-only permission, requested from the parent area only; usage text in Info.plist. |
| ✅ | No system alerts during play (Guided Access friendly) | The only permission prompt is Photos, inside the parent area. |

## 3. Privacy manifest

| | Item |
|---|---|
| ✅ | `NSPrivacyTracking = false`, no tracking domains, no collected data types |
| ✅ | Required-reason APIs: **UserDefaults (CA92.1)**, settings only. A code scan found no file-timestamp, disk-space, boot-time or keyboard APIs, so only this one is declared. |
| ✅ | `plutil -lint` passes for the manifest and Info.plist |

## 4. Engineering gates (`./scripts/ci.sh`)

| | Gate | Result |
|---|---|---|
| ✅ | Offline | No network code or URLs |
| ✅ | Release build for device | Zero warnings, 3.5 MB app |
| ✅ | Unit + UI tests | 190 passing on iPhone 17 and iPad Air 11" (M4); 4 opt-in screenshot/preview tests skipped by default |
| ✅ | Accessibility audit | Every screen; exemptions are documented in `AccessibilityAuditUITests` |
| ✅ | Performance | 2,000 strokes on the apple and four busy 1.1 drawings: live frame 1–6 ms, finishing a stroke ~2 ms, undo of newest stroke ~1.5 ms, all layers 8–14 ms |

## 5. CLAUDE.md §11 testing checklist

| | Item | Covered by |
|---|---|---|
| ✅ | Works fully in Airplane Mode | No network code at all (script + binary symbol check) |
| ✅ | ViewModels unit-tested with fakes; navigation via coordinator callbacks | `ViewModelTests` |
| ✅ | Crayon stays inside the starting region and lines up on iPhone and iPad sizes | `StrokeRasterizerTests` (pixel checks at 3 canvas sizes) |
| ✅ | Mixed fill + crayon + eraser undo | `ColoringViewModelTests.mixedFillCrayonEraserUndoUnwindsInOrder` |
| ✅ | Long sessions stay smooth | `RenderPerformanceTests` |
| ⬜ | Kill the app right after lifting a finger → stroke saved | Saved on lift (tested); confirm by hand on a device |
| ⬜ | Force-quit during save → no corruption | Atomic writes (tested); confirm by hand |
| ✅ | Corrupt/garbage JSON → item skipped, no crash | `ProgressStoreTests`, `StrokeCodecTests` (fuzzed), `BackupRestoreTests` |
| ✅ | Upgrade from previous versions keeps art | Tolerant decoding of old and newer files; `migrateIfNeeded` hook. Re-test for every future version. |
| ✅ | Storage full → fails gracefully | `failedWritesReturnFalseInsteadOfCrashing`, `fullDiskNeverStopsTheChild` |
| ⬜ | Gallery with 200+ items on the oldest device | Lazy grid + off-main decoding; measure on the oldest supported device |
| ✅ | Parental gate protects Photos export, settings, clear data | One gate in front of the whole parent area |
| ✅ | Touch targets ≥ 60pt; usable without reading | Design tokens `DSMetrics` (60pt minimum), audit hit-region checks |
