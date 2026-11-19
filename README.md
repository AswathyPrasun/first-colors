# First Colors

A fully offline coloring app for toddlers and kindergarten kids (ages 2–6). Kids pick a fruit or
vegetable, tap to fill parts or scribble with a crayon, and the app gently suggests realistic colors.
No reading needed, no failure states, no accounts, no network.

- **Platforms:** iPhone (portrait) and iPad (portrait and landscape), iOS 17+
- **Tech:** Swift 6, SwiftUI, MVVM + Coordinator, zero third-party dependencies
- **Content:** 50 pictures in 5 categories: Fruits, Veggies, Vehicles, Rescue Pups and Super Kids
  (10 each), each with 3–6 colorable parts and a friendly face. All characters are our own originals
  (CLAUDE.md §2.9).

`CLAUDE.md` is the source of truth for product rules, architecture and storage. This README covers
building, testing, and adding content.

---

## Build and run

1. Open `KidsColoring.xcodeproj` in Xcode 27.2 or later.
2. Pick the **KidsColoring** scheme and an iPhone or iPad simulator.
3. Run.

For a device, set your team under *Signing & Capabilities* and change the bundle id
(`com.firstcolors.KidsColoring` is a placeholder).

### Before you ship

```sh
./scripts/ci.sh                               # offline check, plists, warning-free Release build, all tests
SIM="iPad Air 11-inch (M4)" ./scripts/ci.sh   # same on iPad
```

See `docs/RELEASE_CHECKLIST.md` for the App Store and Kids-category checklist.

---

## Project layout

```
App/            KidsColoringApp, DependencyContainer
Coordinators/   AppCoordinator, ParentCoordinator, routes
Features/       Home, Picker, Coloring (+ Engine, Components), Celebration, Gallery,
                Profiles, ParentArea (gate, settings, profiles, export, backup)
Core/           Models, Services (content, storage, audio, render, profiles, photos, zip),
                Drawing (SVG parser, drawing model, renderer), DesignSystem
Resources/      Content/content.json, Drawings/*.svg, Audio/, Fonts/, Assets.xcassets,
                PrivacyInfo.xcprivacy
Tests/          ViewModelTests, StorageTests, EngineTests, TestSupport (fakes), UITests
scripts/        content, sound and icon generators; offline check; CI gate
Config/         Info.plist (fonts, launch screen)
```

The Xcode project uses folder-synchronized groups: any file you add to these folders is picked
up automatically. No project-file editing needed.

---

## Adding a drawing

Drawings are generated from one Python file so ids, colors and art stay in sync.

1. **Draw it** in `scripts/drawings.py` by adding an entry to `ITEMS`:
   ```python
   dict(
       id="kiwi", category="fruits",
       name=("Kiwi", "كيوي"), sentence=("Kiwis are green inside!", "الكيوي أخضر من الداخل!"),
       regions=[                                   # bottom → top; later regions cover earlier ones
           ("skin",  [BROWN],          circle(150, 160, 110)),
           ("flesh", [GREEN, YELLOW],  circle(150, 160, 85)),
       ],
       details=face(150, 160),                     # eyes + smile, drawn on top, not fillable
   ),
   ```
   Rules (CLAUDE.md §7):
   - 300×300 coordinate space, 3–6 regions, thick friendly shapes.
   - Region ids are stable forever. To redraw an item, make a **new item id** (`kiwi_v2`), never
     reuse region ids with different meanings: saved art refers to them.
   - Suggested colors must come from the category's 8-color palette (`CategoryDetails.palette`;
     constants such as `RED`, `SKY`, `GRAY` are at the top of the file).
   - New category? Add a case to `Category`, one entry in `CategoryDetails` (title, cover, colors,
     palette, cheer word, finish sound) and a row in `CATEGORIES` in `drawings.py`.
   - Overlap is fine: a later region (a leaf) hides the part of an earlier one (the body) under it.
     The app cuts the hidden part out automatically for fills, crayon and taps.
   - Use `circle()`, `face()` and any SVG path data (`M L H V C S Q T A Z`, absolute or relative).
2. **Generate:** `python3 scripts/drawings.py` writes `Resources/Drawings/<id>.svg`,
   `Resources/Content/content.json` and the voice-line list `Resources/Audio/README.md`.
3. **Check it:** the content tests (`BundledContentTests`) verify every drawing loads, has 3–6
   regions, uses palette colors, stays inside the canvas, and that every region is big enough for
   a toddler's finger. To look at all the art:
   ```sh
   TEST_RUNNER_DRAWING_PREVIEW_DIR=$PWD/build/previews xcodebuild -project KidsColoring.xcodeproj \
     -scheme KidsColoring -destination 'platform=iOS Simulator,name=iPhone 17' \
     -only-testing:KidsColoringTests/DrawingPreviewTests test
   ```
   This writes one sheet per category (`fruits.png`, `vehicles.png`, …: blank + suggested colors)
   and `metrics.tsv`.
4. **Add its voice lines** (next section).

A drawing can also be authored in any SVG editor: one `<path id="regionId">` per region, face and
decorations inside `<g id="details">` (circles are filled, paths are stroked), `viewBox="0 0 300 300"`.

---

## Adding audio

### Voice lines (names and color sentences)

Not recorded yet. `Resources/Audio/README.md` lists every file name and the exact words to say,
in English and Arabic (210 files: 84 from 1.0, 126 added in 1.1). To add recordings:

- Format: AAC `.m4a`, mono, 44.1 kHz, peaks around −3 dB, silence trimmed.
- Put them in `Resources/Audio/en/` and `Resources/Audio/ar/` with exactly the listed names.
  Names must be unique across folders (Xcode copies them flat into the app).
- That's it. The `nameAudio` / `colorSentenceAudio` fields in `content.json` already point at them.

Until a file exists, **debug builds** speak the text with the system voice so you can test, and
**release builds stay silent**. Never ship the system voice as the main voice.

### Sound effects and music

`sfx_tap`, `sfx_pop`, `sfx_sparkle`, `sfx_cheer`, `sfx_crayon_loop`, `music_loop` and the 1.1
finish sounds `sfx_vroom`, `sfx_woof`, `sfx_whoosh` are synthesized (original, no licenses) by
`python3 scripts/make_sounds.py` (pass names to regenerate only those). Replace any of them with a
recording of the same name to change it.

All audio respects the Ring/Silent switch and the Sounds / Music / Voice language settings in the
parent area.

---

## Fonts

Kid screens are designed for **Fredoka** (SIL Open Font License). Add `Fredoka-Medium.ttf`,
`Fredoka-SemiBold.ttf`, `Fredoka-Bold.ttf` and `OFL.txt` to `Resources/Fonts/`. They're already
registered in `Config/Info.plist`, and the app switches to them automatically. Until then it uses
the rounded system font.

---

## Tests

| Suite | What it covers |
|---|---|
| `EngineTests` | SVG parser, hit-testing (smallest-first + slop), stroke building and smoothing, crayon clipping on real pixels, undo for every action, performance with 2,000 strokes |
| `StorageTests` | Progress store (round trip, atomic writes, corrupt/unknown/old/new versions, full disk, unsafe ids), stroke codec, backup/restore, zip, bundled content checks, settings |
| `ViewModelTests` | Every ViewModel with fakes, coordinator routing, profiles, autosave, parental gate timing (manual clock), Photos export, accessibility actions |
| `UITests` | Pick avatar → color apple → Done → My Art; Color more; gallery and parental gate; accessibility audit of every screen |

Opt-in extras (skipped unless the variable is set):

```sh
TEST_RUNNER_SCREENSHOT_DIR=$PWD/build/shots …  -only-testing:KidsColoringUITests/ScreenshotTourUITests test
TEST_RUNNER_PERF_REPORT_DIR=$PWD/build      …  -only-testing:KidsColoringTests/RenderPerformanceTests test
```

UI tests launch with `-uiTesting` (debug builds only), which uses a throwaway data folder so they
always start at first launch and never touch real art.

---

## Scripts

| Script | Does |
|---|---|
| `scripts/drawings.py` | Generates all drawings and `content.json` |
| `scripts/make_sounds.py` | Synthesizes sound effects and the music loop |
| `scripts/make_app_icon.sh` | Renders the placeholder app icon from `apple.svg` |
| `scripts/check-no-network.sh` | Fails if any network API or URL appears in the code |
| `scripts/ci.sh` | Full release gate |
| `scripts/appstore-screenshots.sh` | App Store screenshots (iPhone 6.9", iPad 13") into `AppStore/screenshots/` |
