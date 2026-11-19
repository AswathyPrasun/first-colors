# Prompt: add three new categories (Vehicles, Rescue Pups, Super Kids)

Paste everything below the line into a new Claude Code session at the repo root.

---

You are extending **First Colors**, a fully offline iOS coloring app for children aged 2–6
(Swift 6, SwiftUI, MVVM + Coordinator, zero dependencies). The app ships with two categories:
Fruits and Vegetables, 10 drawings each. Add **three new categories with 10 drawings each**:

1. **Vehicles** 🚗
2. **Rescue Pups** 🐶: an original team of puppy helpers (our own characters)
3. **Super Kids** 🦸: original, friendly little superheroes (our own characters)

`CLAUDE.md` is the source of truth. Read it, `README.md` and `docs/RELEASE_CHECKLIST.md` first.
If anything in this prompt conflicts with `CLAUDE.md`, follow `CLAUDE.md` and tell me about the
conflict. One known conflict: `CLAUDE.md` §12 puts vehicles in v2 and doesn't list the two
character categories. Update §1, §7 (starter content) and §12 to match this work in Phase 1.

Work in the phases below. **After each phase:**
- Build and run `./scripts/ci.sh`.
- Fix every warning and error.
- Give me a short summary: what changed and what to look at in the simulator.
- Stop and wait for me. Do not skip ahead.

Commit only when I ask.

## 0. Hard rules: original characters only

The app must **not** contain any existing franchise character. That means no PAW Patrol and no
Marvel, and also no Disney, DC, Bluey, Peppa Pig and so on. That covers their names, look,
logos, emblems, colors-as-identity, catchphrases and theme music. We have no license, the App
Store rejects unlicensed characters (guideline 5.2), and Kids-category apps are reviewed strictly.

**Rescue Pups.** Design generic puppies of different breeds, each with a job.
- **Do not use:** PAW Patrol names (Chase, Marshall, Skye, Rubble, Rocky, Zuma, Everest, Ryder
  and others), paw-print badges or pup-tag collars, the show's color-per-character uniforms or
  vehicles, the "PAW Patrol" wordmark, or a lookout tower.
- **Do use:** simple everyday job cues, such as a firefighter helmet, a doctor's bag, a hard
  hat, a life ring or a mail bag.

**Super Kids.** Design small children or animals in capes and eye masks, each with a simple
emblem made only from basic shapes.
- **Allowed emblem shapes:** heart, star, moon, sun, cloud, flower, raindrop, music note,
  rainbow.
- **Do not use:** Marvel or DC names, masks, suits or emblems. That includes spider webs, a
  round shield with a star, glowing chest circles, hammers, claws, armor suits, green giants,
  lightning bolts on the chest, bat or "S" shields, and star-spangled patterns.

**Names.** Give every character a short, original, easy-to-say name (for example, "Fire Pup",
"Doctor Pup", "Star Girl"). Search the names and avoid any that are a famous existing character.

**Review.** If a drawing could be mistaken for a known character, change it. List every
character in your Phase 2 summary with one line on why it is original.

## 1. Model and architecture (Phase 1)

### Categories and content

- Add `vehicles`, `rescuePups` and `superKids` to `Category`. Keep raw values stable forever:
  `"vehicles"`, `"rescue_pups"`, `"super_kids"`.
- Old saves and older content must keep working. Unknown categories in content JSON are already
  skipped; keep it that way.
- Move all per-category display data into one place. Today it is spread over
  `Features/Home/Category+Display.swift`, the hard-coded `"apple"`/`"carrot"` in
  `HomeViewModel` (around line 45) and the category voice text in `AudioService` (around
  line 62). Move it to a single table, for example `CategoryInfo`, holding:
  - title (en/ar)
  - cover item id
  - tile, tile-shadow and picker background colors
  - name-audio files
  - its palette (next section)

  No `switch` on category anywhere else. A test must fail if a category lacks an entry.
- Add `DSColor` tile, shadow and background tokens for each new category: light, cheerful and
  clearly different from each other. Keep text contrast ≥ 4.5:1.

### Palette

- Today's palette is 8 fixed colors with no gray or black. Vehicles need gray tires and
  light-blue windows. Keep the kid palette **at most 8 colors on screen** (CLAUDE.md §2.5),
  but let each category choose its 8 from a base set:
  - **Base set:** the current 8, plus **Gray `#78909C`** and **Sky `#81D4FA`**. No pure
    black: black fills hide the black outlines.
  - **Fruits and Vegetables:** unchanged.
  - **Vehicles:** Red, Orange, Yellow, Green, Blue, Sky, Gray, Brown.
  - **Rescue Pups:** Red, Orange, Yellow, Green, Blue, Purple, Gray, Brown.
  - **Super Kids:** Red, Orange, Yellow, Green, Blue, Purple, Pink, Sky.
- Saved art may contain any base color. A saved color that isn't in the current palette still
  renders. It just isn't offered as a swatch.
- Suggested colors for every region must come from that category's palette. Extend
  `BundledContentTests` to check this.

### Home screen

- Home now has 5 category tiles plus My Art.
  - **iPhone:** a 2-column scrolling grid, tiles at least 150pt tall, My Art last as a full-width
    row.
  - **iPad portrait:** 3 columns. **iPad landscape:** 3–5 columns. Fill the screen without big
    empty gaps (the current iPad Home has too much empty space; fix that too).
- Each tile keeps a speaker button that says the category name, a cover drawing, and a title.
  Kids don't need to read it, so the cover drawing must be enough on its own.
- The new tiles must pass the accessibility audit UI test. Add a tile identifier for each:
  `category.vehicles`, `category.rescue_pups`, `category.super_kids`.

### Tests (Phase 1)

- Category round trip and unknown-category skipping.
- Palette per category, with older saves showing colors outside the palette.
- Every category has a `CategoryInfo`.
- Home view model lists 5 categories in a fixed order.
- UI test: open each category from Home and go back.

## 2. Drawings and content (Phase 2)

Add all 30 drawings to `scripts/drawings.py`, then run `python3 scripts/drawings.py`. Follow the
art rules in `CLAUDE.md` §7 and `README.md` "Adding a drawing":
- 300×300 viewBox and thick, friendly shapes.
- **3–6 large regions** with stable ids, a smiling face in `details`, and every region big
  enough for a toddler's finger. The existing content tests check region size.
- Vehicles get friendly faces too, with eyes on the windshield or front.
- Add helpers to `drawings.py` where it helps, for example `wheel(cx, cy, r)`,
  `rounded_rect(...)`, `cape(...)` and `pup_head(...)`, so the shapes stay consistent.

### Vehicles

| id | Regions (bottom → top), suggested colors |
|---|---|
| `car` | body (Red, Blue, Yellow), window (Sky), wheel_front (Gray), wheel_back (Gray) |
| `bus` | body (Yellow, Orange), windows (Sky), wheel_front (Gray), wheel_back (Gray), door (Sky) |
| `fire_truck` | body (Red), ladder (Gray, Yellow), window (Sky), wheel_front (Gray), wheel_back (Gray) |
| `police_car` | body (Blue), light (Red, Blue), window (Sky), wheel_front (Gray), wheel_back (Gray) |
| `ambulance` | body (Red, Yellow), stripe (Red), window (Sky), wheel_front (Gray), wheel_back (Gray) |
| `train` | engine (Green, Red), cab (Blue), chimney (Gray), wheels (Gray) |
| `airplane` | body (Blue, Red), wings (Gray, Blue), tail (Red, Yellow), windows (Sky) |
| `boat` | hull (Red, Blue), cabin (Yellow), sail (Orange, Yellow), water (Blue, Sky) |
| `tractor` | body (Green, Red), cab (Yellow), big_wheel (Gray), small_wheel (Gray) |
| `rocket` | body (Gray, Red), window (Sky), fins (Red, Orange), flame (Orange, Yellow) |

### Rescue Pups (original characters)

| id | Character | Regions, suggested colors |
|---|---|---|
| `fire_pup` | Fire Pup, a spotted puppy with a firefighter helmet | fur (Brown, Yellow, Gray), ears (Brown), helmet (Red), vest (Yellow) |
| `doctor_pup` | Doctor Pup, a fluffy puppy with a doctor's bag | fur (Yellow, Brown), ears (Brown), coat (Blue, Green), bag (Red) |
| `builder_pup` | Builder Pup, a bulldog-type puppy with a hard hat | fur (Brown, Gray), ears (Brown), hat (Yellow, Orange), vest (Orange) |
| `swim_pup` | Swim Pup, a puppy with a life ring | fur (Yellow, Brown), ears (Brown), ring (Red, Orange), water (Blue) |
| `farm_pup` | Farm Pup, a sheepdog-type puppy with a straw hat and a carrot | fur (Gray, Brown), hat (Yellow), scarf (Red, Blue), carrot (Orange) |
| `mail_pup` | Mail Pup, a puppy with a cap and a mail bag | fur (Brown, Yellow), cap (Blue), bag (Brown, Red), letter (Yellow) |
| `garden_pup` | Garden Pup, a puppy holding a watering can | fur (Yellow, Brown), ears (Brown), can (Green, Blue), flower (Red, Purple) |
| `snow_pup` | Snow Pup, a husky-type puppy in a woolly hat | fur (Gray, Blue), hat (Red, Purple), scarf (Green, Orange) |
| `chef_pup` | Chef Pup, a puppy with a chef hat and a cupcake | fur (Brown, Yellow), hat (Gray), cupcake (Purple, Red), apron (Blue) |
| `pilot_pup` | Pilot Pup, a puppy in a small round plane | fur (Yellow, Brown), goggles (Blue), plane (Red, Orange), wing (Gray) |

### Super Kids (original characters)

| id | Character | Regions, suggested colors |
|---|---|---|
| `little_star` | Little Star, a cape with a star emblem | suit (Purple, Blue), cape (Red, Pink), emblem (Yellow), mask (Blue) |
| `heart_boy` | Heart Boy, with a heart emblem | suit (Green, Blue), cape (Red), emblem (Pink, Red), boots (Yellow) |
| `sun_hero` | Sun Hero, with a sun emblem | suit (Orange, Yellow), cape (Red), emblem (Yellow), mask (Orange) |
| `moon_hero` | Moon Hero, with a moon emblem | suit (Blue, Purple), cape (Purple), emblem (Yellow), boots (Sky) |
| `cloud_kid` | Cloud Kid, riding a cloud | suit (Sky, Blue), cape (Pink), emblem (Blue), cloud (Sky) |
| `flower_hero` | Flower Hero, with a flower emblem | suit (Green), cape (Pink, Purple), emblem (Yellow, Red), mask (Green) |
| `rainbow_hero` | Rainbow Hero, with a rainbow cape | suit (Blue), cape (Red, Orange), emblem (Yellow), mask (Purple) |
| `cape_kitty` | Cape Kitty, a kitten in a cape | fur (Orange, Yellow), cape (Red, Blue), mask (Purple), emblem (Yellow) |
| `hero_bear` | Hero Bear, a teddy bear in a cape | fur (Orange, Yellow), cape (Blue, Green), emblem (Red), belt (Yellow) |
| `music_hero` | Music Hero, with a music-note emblem | suit (Pink, Purple), cape (Blue), emblem (Yellow), boots (Red) |

### Names and voice lines

- Every item needs an English and an Arabic name, plus a short, positive color sentence. Examples:
  - "Fire trucks can be red!"
  - "Fire Pup has a red helmet!"
  - "Little Star has a yellow star!"
- Mark the Arabic text for native-speaker review in the checklist.

### Covers and order

- **Cover items:** `car`, `fire_pup`, `little_star`.
- **Picker order:** as listed above.

### Tests (Phase 2)

- Bump `shipsTenFruitsAndTenVegetables` into a per-category check: 10 items each, in this order.
- Run all existing content tests on the new items: regions, palette, canvas bounds and finger
  size.
- Render the preview sheets (`DrawingPreviewTests`) and check every drawing yourself.
  - Fix anything that looks off: thin slivers, faces off-center, regions too small, shapes that
    look like something else.
  - Check the shapes against the franchise rules in section 0.
  - Show me `vehicles.png`, `rescue_pups.png` and `super_kids.png`.

## 3. Audio (Phase 3)

- `Resources/Audio/README.md`: list every new voice file with its exact words.
  - Per item: `<id>_en.m4a`, `<id>_ar.m4a`, `<id>_sentence_en.m4a`, `<id>_sentence_ar.m4a`.
  - Per category: a name line, for example `category_vehicles_en.m4a`.
  - Total: 30 items × 4 = 120 files, plus 6 category names.
- Debug builds speak missing lines with the system voice. Release builds stay silent, as today.
- Optional, synthesized like the existing effects in `scripts/make_sounds.py` (original, no
  licenses):
  - A short "vroom" for finishing a vehicle.
  - A "woof" chime for Rescue Pups.
  - A "whoosh" for Super Kids.
- No music or sounds from any show.

## 4. Polish, docs and release (Phase 4)

- **Celebration:** keep the same flow. Use the sentence for the category ("Yummy!" fits food
  only). Add a per-category cheer word in `CategoryInfo`, for example "Vroom!", "Woof woof!",
  "Super!".
- **Accessibility:**
  - VoiceOver names every new region, for example "Fire truck ladder".
  - The audit UI test passes on iPhone and iPad.
- **Performance:** opening any new drawing and finishing a stroke stay within the current
  `RenderPerformanceTests` budgets.
- **Docs:**
  - Update `README.md` (content counts and categories).
  - Update `RELEASE_NOTES.md`: "What's New" for 1.1, and the description now says 50 pictures
    in 5 categories.
  - Update `docs/RELEASE_CHECKLIST.md` with the new voice lines and Arabic review.
- **Screenshots:**
  - Update `Tests/UITests/AppStoreScreenshotsUITests.swift` so the shots show the new
    categories: Home with 5 tiles, a vehicle being colored, and a Super Kids celebration.
  - Re-run `./scripts/appstore-screenshots.sh` and show me the results.
- **Version:** bump the marketing version to 1.1 and the build number.
- **Final gate:** `./scripts/ci.sh` passes on iPhone 17 and on `SIM="iPad Air 11-inch (M4)"`,
  with zero warnings.

## Definition of done

- 50 drawings in 5 categories. All are original, and none resembles a franchise character.
- Every kid-facing label has a voice line or an icon. No reading is needed.
- Old saved art from 1.0 opens unchanged, covered by a test using a 1.0-format save.
- Offline and privacy unchanged: no network, no new data collected, privacy manifest unchanged.
- CI is green on iPhone and iPad, and the screenshots are regenerated.
