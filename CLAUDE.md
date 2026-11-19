# CLAUDE.md — Kids Coloring App (working title)

Guidance for Claude when working in this repository. Read this before making changes.

## 1. Product overview

A **fully offline** iOS coloring app for **toddlers and kindergarten kids (ages ~2–6)**.
Kids pick a picture, tap regions to fill them with color, and the app **suggests realistic colors** for each region (e.g. apple body → red/green/yellow, leaf → green). Kids can still use any color — suggestions guide, never block.

- **v1 categories:** Fruits 🍎 and Vegetables 🥕
- **v1.1 categories:** Vehicles 🚗, Rescue Pups 🐶 and Super Kids 🦸 (our own original characters)
- **Later:** Animals, Shapes

## 2. Non-negotiable principles

1. **100% offline.** No network calls, no remote config, no analytics/ads/third-party SDKs. All content ships in the app bundle.
2. **No reading required.** Use icons, images and voice. Text exists only in the parent area.
3. **Big touch targets.** Minimum 60–80pt for kid-facing buttons, thick outlines (6–10pt).
4. **No failure states.** Nothing is ever "wrong". Every action gets positive feedback.
5. **Minimal choices.** Show 5–8 colors at a time, no full color picker.
9. **Original characters only.** No existing franchise characters (names, look, logos, emblems, music), e.g. no PAW Patrol, Marvel, DC, Disney. We have no license, and App Store guideline 5.2 rejects them.
6. **Never crash on bad data.** Corrupt or unknown saved data is skipped or reset, never fatal.
7. **Kids Category compliant.** Parental gate for anything outside the kid area. No external links, no IAP or ads in the kid area.
8. **Privacy label = "Data Not Collected".** Do not add features that collect photos, voice recordings or personal info from kids.

## 3. Tech stack

- **Language/UI:** Swift, SwiftUI
- **Architecture:** MVVM + Coordinator (see §4)
- **Drawings:** vector paths (from SVG), one closed `Path` per fillable region
- **Fill mode (v1):** hit-test taps with `path.contains(point)`, then fill the region (no pixel flood-fill)
- **Crayon / freehand mode (v1):** custom SwiftUI `Canvas` + `DragGesture`, strokes clipped to the region where the stroke started (see §6)
- **Audio:** `AVAudioPlayer` with bundled `.m4a` files
- **Export:** `ImageRenderer` → PNG
- **Persistence:** JSON files on disk (see §8). `UserDefaults` for settings only.
- **Min target:** iPhone + iPad (iPad-optimized layout in v2)

## 4. Architecture: MVVM + Coordinator

### Layers

| Layer | Responsibility | Must NOT |
|---|---|---|
| **View** (SwiftUI) | Render state, forward user intents to the ViewModel | Navigate, do I/O, hold business logic |
| **ViewModel** (`@Observable`, `@MainActor`) | Screen state, intents, calls services, asks coordinator to navigate | Import SwiftUI navigation types, touch the file system directly, know about other screens |
| **Coordinator** | Owns navigation state, builds screens (View + ViewModel), injects dependencies | Hold screen/business state |
| **Services** | `ContentRepository`, `ProgressStore`, `AudioService`, `RenderService`, `ProfileService` | Know about Views or ViewModels |
| **Models** | Plain `Codable` / value types | Contain UI or I/O code |

### Coordinators

- **`AppCoordinator`** (root, `@Observable`): owns the `NavigationStack` path and modal state, holds the `DependencyContainer`, and decides the start screen (profile picker or Home).
- **`ParentCoordinator`** (child): presented as a sheet after the parental gate passes; handles Settings, Profiles, Export, Backup/Restore, and dismisses itself back to the `AppCoordinator`.

```swift
enum AppRoute: Hashable {
    case picker(category: Category)
    case coloring(itemId: String)
    case celebration(itemId: String)
    case gallery
}

enum AppSheet: Identifiable {
    case parentArea
    var id: String { "parentArea" }
}

@MainActor @Observable
final class AppCoordinator {
    var path: [AppRoute] = []
    var sheet: AppSheet?
    let deps: DependencyContainer

    init(deps: DependencyContainer) { self.deps = deps }

    func showPicker(_ c: Category) { path.append(.picker(category: c)) }
    func showColoring(_ id: String) { path.append(.coloring(itemId: id)) }
    func showCelebration(_ id: String) { path.append(.celebration(itemId: id)) }
    func showGallery() { path.append(.gallery) }
    func popToHome() { path.removeAll() }
    func openParentArea() { sheet = .parentArea }   // only after gate passes

    @ViewBuilder
    func view(for route: AppRoute) -> some View {
        switch route {
        case .picker(let c):
            PickerView(vm: PickerViewModel(category: c, content: deps.content,
                                           progress: deps.progress,
                                           onSelect: { [weak self] in self?.showColoring($0) }))
        case .coloring(let id):
            ColoringView(vm: ColoringViewModel(itemId: id, content: deps.content,
                                               progress: deps.progress, audio: deps.audio,
                                               onDone: { [weak self] in self?.showCelebration(id) }))
        case .celebration(let id):
            CelebrationView(vm: CelebrationViewModel(itemId: id, audio: deps.audio,
                                                     onFinish: { [weak self] in self?.popToHome() }))
        case .gallery:
            GalleryView(vm: GalleryViewModel(progress: deps.progress,
                                              onOpen: { [weak self] in self?.showColoring($0) }))
        }
    }
}
```

### Rules

- **ViewModels never navigate directly.** They call closures (or a small protocol) supplied by the coordinator, e.g. `onDone`, `onSelect`.
- **The coordinator is the only place** that creates ViewModels and wires up dependencies.
- **Inject services through protocols** (`ProgressStoring`, `ContentProviding`, `AudioPlaying`) so ViewModels can be unit tested with fakes.
- **One ViewModel per screen.** Shared subcomponents (palette, toolbar) get small child view models or plain bindings, not their own coordinators.
- **`DependencyContainer`** is created once in the `App` struct and passed to `AppCoordinator`. No singletons.
- **Root view:** `NavigationStack(path: $coordinator.path)` with `.navigationDestination(for: AppRoute.self) { coordinator.view(for: $0) }` and `.sheet(item: $coordinator.sheet)`.

## 5. Screens

1. **Home** — big category tiles in a grid (2 columns on iPhone, 3–5 on iPad), then My Art. Categories with no drawings are hidden.
2. **Picker** — grid of large thumbnails; colored items show the child's version.
3. **Coloring screen**
   - Centered drawing (no pinch-zoom in v1)
   - Palette strip of large round color blobs
   - Tools: Fill 🪣, Crayon 🖍️, Eraser, Undo, Hint 💡, Magic ✨
   - Big "Done" ⭐ button
4. **Celebration** — confetti, sound, voice says the item name; art saved to gallery.
5. **My Art (Gallery)** — thumbnails of saved art, lazy loaded.
6. **Parent area** (behind parental gate, e.g. hold 3s or simple sum) — sound/music, language, profiles, storage used, clear gallery, export to Photos, backup/restore.

## 6. Crayon / freehand mode (v1)

### Behaviour

- The child drags a finger to draw with the selected color.
- **Stay inside the lines:** a stroke is clipped to the region where it started (`context.clip(to: regionPath)`). This keeps toddler scribbles neat.
- **Crayon brush:** a single thick brush (about 18–24pt, round caps and joins) with slightly soft edges. No size picker in v1. An optional crayon texture overlay can be added later.
- **Eraser:** in crayon mode it removes strokes it touches; in fill mode it clears a region's fill.
- Fill and crayon can be mixed on the same drawing.
- Palm/multi-touch: only the first touch draws; ignore extra fingers.

### Rendering order (bottom → top)

1. White background
2. Region fills
3. Crayon strokes (each clipped to its region)
4. Black outlines (always on top, so lines stay crisp)

### Undo

A single undo stack of actions covers both modes:

```swift
enum ColoringAction {
    case fill(regionId: String, oldColor: String?, newColor: String?)
    case stroke(Stroke)                // undo removes it
    case erase(removed: [Stroke])      // undo restores them
}
```

Cap the undo stack (for example 50 actions) to limit memory.

### Performance

- Smooth input with simple point smoothing (for example quadratic curves through midpoints).
- Drop points closer than about 2pt to the previous point while drawing.
- Draw the in-progress stroke separately; merge finished strokes into a cached layer so long sessions stay fast.

## 7. Suggested colors feature

Each drawing has regions; each region has `suggested` colors.

- When a region is selected (or the drawing opens), matching palette colors **glow/bounce**.
- **Hint:** show a faint preview of the real colors, or a short animation.
- **Magic:** auto-fill all regions with the first suggested color (guaranteed win for the youngest kids).
- **Free play:** any color is allowed.
- **Completion voice line:** e.g. "Yummy! Apples can be red!"

### Content JSON (bundled, read-only)

```json
{
  "version": 1,
  "items": [
    {
      "id": "apple",
      "category": "fruits",
      "svg": "apple.svg",
      "nameAudio": { "en": "apple_en.m4a", "ar": "apple_ar.m4a" },
      "regions": [
        { "id": "body", "suggested": ["#E53935", "#7CB342", "#FDD835"] },
        { "id": "leaf", "suggested": ["#43A047"] },
        { "id": "stem", "suggested": ["#6D4C41"] }
      ]
    }
  ]
}
```

### Starter content (v1)

- **Fruits:** apple, banana, orange, strawberry, grapes, watermelon, pear, cherry, pineapple, mango
- **Vegetables:** carrot, tomato, broccoli, eggplant, corn, potato, cucumber, pumpkin, onion, peas

### Added content (v1.1)

- **Vehicles:** car, bus, fire_truck, police_car, ambulance, train, airplane, boat, tractor, rocket
- **Rescue Pups:** fire_pup, doctor_pup, builder_pup, swim_pup, farm_pup, mail_pup, garden_pup, snow_pup, chef_pup, pilot_pup
- **Super Kids:** little_star, heart_boy, sun_hero, moon_hero, cloud_kid, flower_hero, rainbow_hero, cape_kitty, hero_bear, music_hero
- Category raw values are stable forever: `fruits`, `vegetables`, `vehicles`, `rescue_pups`, `super_kids`.
- All per-category UI and palette data lives in `CategoryDetails` (the only `switch` over `Category`).

### Art rules

- Thick black outlines, 3–6 large regions per drawing, friendly faces encouraged.
- Every fillable region is a closed path with a stable `id` matching the JSON.
- Base palette: red, orange, yellow, green, blue, light blue, purple, pink, gray, brown (`KidPalette.base`). Each category shows 8 of them (`CategoryDetails.palette`). No pure black fill (it hides the outlines); the eraser clears to white. Saved colors outside a category's palette still render.

## 8. Local storage rules (important)

### Where things live

| Data | Format | Location |
|---|---|---|
| Coloring progress | Small JSON per drawing (`regionId → color`) + `version` | `Application Support/Profiles/<profileId>/` |
| Finished art | Coloring JSON + small thumbnail PNG | same folder |
| Settings | `UserDefaults` | — |
| Full-quality image | Rendered on demand at export only | Photos (from parent area) |

### Saved progress format

```json
{
  "version": 1,
  "itemId": "apple",
  "updatedAt": "2026-11-16T09:00:00Z",
  "fills": { "body": "#E53935", "leaf": "#43A047" },
  "strokesFile": "apple.strokes"
}
```

### Stroke storage

- Strokes are stored in a separate file per drawing (`<itemId>.strokes`) so the main progress JSON stays tiny and quick to load.
- Model: `Stroke { id: UUID, regionId: String, color: String, width: Float, points: [Point] }`.
- Encode as compact binary (or JSON) and compress with `NSData.compressed(using: .lzfse)`.
- Store points in **drawing coordinates** (the SVG's own coordinate space), not screen points, so strokes still line up on any device size.
- Limits: cap points per drawing (for example 50,000). After the cap, show a gentle "Great drawing! Let's start a new one" rather than an error.
- Save strokes when a stroke ends (finger lifted), not on every point.

### Rules

- **Never** store user data in `Caches` or `tmp`. iOS can delete these.
- **Store coloring data, not full images.** Re-render from vector + fills. Keep only small thumbnails.
- **Atomic writes only:** `Data.write(to:options: .atomic)`.
- **Autosave after every fill**, so a crash loses at most one tap.
- **Safe loading:** wrap decoding in `do/catch`; on failure, skip/reset that item and log it. Never crash at launch.
- **Version everything:** include `version` in all saved and content JSON from day one.
- **Stable region IDs:** never reuse an ID for a redrawn item; create a new item ID (e.g. `apple_v2`).
- **Ignore unknown region IDs** when loading old saves.
- **Profiles:** simple local avatar-based profiles (🐻 / 🐰), no names or personal data, one folder each.
- **Gallery:** `LazyVGrid` + thumbnails; decode images off the main thread.

### Known challenges with local storage (and mitigations)

| Challenge | Mitigation |
|---|---|
| App deleted → all art lost | Store in backed-up folders; parent export to Photos; optional Backup/Restore zip to Files |
| No cross-device sync | Future: optional CloudKit private database (no login, offline-first) |
| Storage growth | Save fills JSON, not images; thumbnails only; show usage + "Clear gallery" in parent area |
| Corruption on crash/battery death | Atomic writes, frequent autosave, safe fallback loading |
| App updates / migrations | `version` fields, stable IDs, tolerant decoding, test upgrades from every past version |
| Siblings sharing one device | Local profiles |
| Gallery slowness / memory | Thumbnails, lazy loading, background decoding |
| No field analytics | Rely on Xcode Organizer crash reports; thorough edge-case testing |

## 9. Project structure

```
App/
  KidsColoringApp.swift          # creates DependencyContainer + AppCoordinator
  DependencyContainer.swift
Coordinators/
  AppCoordinator.swift
  AppRoute.swift
  ParentCoordinator.swift
Features/
  Home/          HomeView.swift, HomeViewModel.swift
  Picker/        PickerView.swift, PickerViewModel.swift
  Coloring/      ColoringView.swift, ColoringViewModel.swift
                 Components/ (DrawingCanvas, PaletteView, ToolbarView)
                 Engine/     (FillEngine, StrokeEngine, UndoStack)
  Celebration/   CelebrationView.swift, CelebrationViewModel.swift
  Gallery/       GalleryView.swift, GalleryViewModel.swift
  ParentArea/    ParentGateView, SettingsView, ProfilesView + ViewModels
Core/
  Models/        ContentItem, Region, ColoringProgress, Stroke, Profile
  Services/      ContentRepository, ProgressStore, AudioService,
                 RenderService, ProfileService (+ protocols)
Resources/
  Content/content.json
  Drawings/*.svg
  Audio/en/, Audio/ar/
Tests/
  ViewModelTests/  # with fake services
  StorageTests/    # atomic writes, migrations, corrupt files
  EngineTests/     # hit-testing, clipping, undo
```

## 10. Coding conventions

- Follow MVVM + Coordinator strictly (§4). Views stay thin; ViewModels are `@MainActor @Observable`.
- All disk I/O goes through `ProgressStore`; views and view models never touch the file system directly.
- Heavy work (stroke encoding, thumbnail rendering, decoding) runs off the main thread.
- No force unwraps or `try!` on loaded data.
- Undo uses the `ColoringAction` stack (§6).
- Every kid-facing string must also exist as audio or an icon.
- Keep dependencies at zero unless discussed; no third-party SDKs.

## 11. Testing checklist

- [ ] App works fully in Airplane Mode
- [ ] ViewModels unit tested with fake services; navigation tested via coordinator callbacks
- [ ] Crayon strokes stay inside the starting region and line up on iPhone and iPad sizes
- [ ] Mixed fill + crayon + eraser undo works correctly
- [ ] Long drawing sessions (thousands of strokes) stay smooth
- [ ] Kill the app right after lifting a finger → stroke is saved
- [ ] Force-quit during save → no corruption, app relaunches cleanly
- [ ] Corrupt/garbage JSON in a save file → item skipped, no crash
- [ ] Upgrade from every previous version keeps all saved art
- [ ] Device storage full → save fails gracefully
- [ ] Gallery with 200+ items scrolls smoothly on oldest supported device
- [ ] Parental gate protects Photos export, settings, clear data
- [ ] All touch targets ≥ 60pt; usable by a toddler without reading

## 12. Roadmap

- **v1 (MVP):** 10 fruits + 10 vegetables, tap-to-fill, **crayon/freehand mode**, suggested-color glow, Hint, Magic, Undo, Eraser, voice names, celebration, gallery, parent area, local profiles. MVVM + Coordinator architecture.
- **v1.1:** Vehicles, Rescue Pups and Super Kids categories (30 drawings), per-category palettes, Home grid. Then: stickers, crayon texture and brush sizes.
- **v2:** More categories (animals, shapes), simple quiz games ("Find the red fruit"), iPad layout, Apple Pencil, optional CloudKit sync.
