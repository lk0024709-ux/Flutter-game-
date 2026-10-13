# Blade Brawl: Rannbhoomi

A top-down melee battle-royale RPG for Android, written in Flutter. Warm, earthy
premium look — no neon, no glow, no chrome — with a full 350-level campaign, an
elite chimera ladder, a loot and grade system, and a hand-written 3D arena slice
running on the same code base.

The project is built in playable increments; every increment ends with a running
game, a clean `flutter analyze` and a debug APK.

## Run locally

1. Install Flutter (stable channel) with a compatible Dart SDK.
2. Generate the Android runner once: `flutter create --platforms=android --project-name blade_brawl .`
3. `flutter pub get`
4. `flutter run` on a device or emulator.

No ads, no in-app purchases, no network calls: the game is fully offline and all
progress lives in `shared_preferences`.

## What is playable today

**2D campaign and progression**

- 350 campaign levels across seven 50-level ranks, each rank ending on a boss.
- Seven handcrafted maps (`lib/maps`) and seven twist types (`lib/twists`),
  including the storm, moving walls and elite arenas.
- Safe-zone and storm systems, poison pools, fire projectiles, power-ups.
- Creature roster (griffin, drake, iron boar, skyhawk, venomtail and more) with
  three modes — creature battle, free-for-all and ranked campaign.
- Seven elite chimera trials with three phases each, own dark palette and own
  arena rules.
- Victory chest with grade → chest-tier mapping, loot tables, XP and player
  levels, coin wallet, armour sets, boosters and a 3×3 weapon forge that
  persists between sessions.
- Grading: clear time, health left and damage taken; the final grade is the
  lowest of the three.

**3D arena slice**

The 3D pivot is being built next to the 2D engine, not on top of it. What exists
now:

- A software 3D renderer written directly against `Canvas.drawVertices`
  (`lib/engine3d/renderer3d.dart`): perspective projection, per-triangle lambert
  lighting, distance fog, bounding-sphere culling, painter's-algorithm depth
  sort and a single batched draw call per frame. No GPU pipeline, no new
  packages, so it compiles and runs anywhere Flutter does.
- A GLB loader (`gltf_loader.dart`) that parses real downloaded models —
  node transforms, embedded buffers, and per-vertex colours baked from each
  model's texture atlas.
- Procedural geometry for everything a download could not cover
  (`procedural_meshes.dart`), so the palette is never empty.
- Seeded arena generation (`arena3d.dart`): a masonry ring, scenery clusters that
  follow the map's decor style, landmarks, spawn plates and blocking-prop
  collision resolution.
- A playable screen: camera-relative movement (WASD, arrow keys or the on-screen
  joystick), an orbiting camera (drag to orbit, pinch to zoom), creatures that
  wander and back away from the player, an FPS/triangle/draw stats strip, and a
  live asset report at **Home → 3D Arena (preview)** and **Model arsenal**.

## Assets

Everything in `assets/` is free for commercial use, and every single file is
listed with its filename, source URL, licence and author in
[`assets/LICENSES.txt`](assets/LICENSES.txt):

| Group | Files | Licence | Where it comes from |
| --- | --- | --- | --- |
| `assets/models/kenney/**` | 52 GLB + 4 palette atlases | CC0-1.0 | Kenney mini-arena, mini-forest, cube-pets, graveyard |
| `assets/models/{player,creatures,props}` | 5 GLB | CC0-1.0 / CC-BY-4.0 | Khronos glTF Sample Assets |
| `assets/textures/*.jpg` | 8 JPEG (512×512) | CC0-1.0 | ambientCG colour maps |
| `assets/audio/{sfx,music}` | 20 OGG | CC0-1.0 | Kenney RPG Audio, Impact Sounds, Music Jingles |

`scripts/download_assets.sh` fetches the whole set (plus the remaining Kenney
kits) from the original hosts, is idempotent, appends a licence line for every
file it downloads, and can also generate silent placeholder audio:

```bash
./scripts/download_assets.sh                # models + textures + audio
./scripts/download_assets.sh --models       # only 3D models
./scripts/download_assets.sh --placeholders # silent audio stand-ins
```

Missing files are never fatal: models fall back to procedural geometry, missing
textures fall back to the palette, and the asset screens report exactly which
slot fell back and why.

## Tests and continuous integration

```bash
flutter analyze     # expected: no issues found
flutter test        # 4 test files
flutter build apk --debug
```

- `test/progression_test.dart` — 350 levels, seven 50-level ranks, one rank boss
  per rank, seven distinct chimeras, elite-trial ↔ armour pairing.
- `test/grade_test.dart` — time/health/damage sub-grades, the lowest-wins rule,
  grade persistence helpers and the grade → chest-tier mapping.
- `test/weapon_test.dart` — forge maths: merge rules, tiers, damage and coin
  costs.
- `test/engine3d_test.dart` — the 3D layer without loading a single file: maths,
  procedural meshes, the model palette, seeded arena layout and collision,
  camera projection/limits, a real render into a picture, and the audio
  catalogue.

`.github/workflows/flutter-ci.yml` generates the Android runner with
`flutter create`, then runs `pub get`, `analyze`, `test` and a debug APK build
on every push to `main` and on every pull request.

## Design system

- Palette: background `#F5F1EA`, surface `#FFFFFF`, surfaceAlt `#EDE7DB`, border
  `#E7E1D3`, primary `#D97706`, primaryDark `#B45309`, secondary `#3F6212`,
  accent `#7C2D12`, text `#1C1917`, muted `#78716C`, success `#15803D`, danger
  `#B91C1C`. Elite screens switch to the dark set (`#1C1917` background).
- Typography: Manrope 700–800 for headings (letterSpacing −0.5), Inter 400–500
  for body, Inter 600 for buttons (letterSpacing 0.2), tabular figures for
  numbers.
- Surfaces: 16–24 px card radius, 12 px buttons, 999 px pills; shadows
  `blurRadius` 12–24, offset (0, 4), black at 8%; 20–24 px screen padding,
  16 px between cards; 200–300 ms `easeOut` animations only.
- Emoji and procedural Canvas art only — no bitmap UI assets, no icon fonts
  beyond Material.

## 3D roadmap

The 3D work is planned in 15 phases; the phases finished so far are marked.

| Phase | Scope | Status |
| --- | --- | --- |
| 0 | Environment, asset download script, licence ledger | done |
| 1 | Download models, textures and audio from CC0 sources | done |
| 2 | Theme and design tokens reused by the 3D HUD | done |
| 3 | 3D engine bootstrap: maths, GLB loader, procedural meshes, camera, renderer, scene manager, arena generator, preview screen | done |
| 4 | Meshes for every slot, procedural fallback for anything missing | partial — slots registered, art pass continues |
| 5 | Audio service (playback) wired to the bundled cues | next |
| 6 | Entities and game loop in 3D (health, attacks, hit reactions) | not started |
| 7 | Creature and boss AI, combat resolution | not started |
| 8 | 3D input and HUD parity with the 2D battle screen | not started |
| 9 | State and persistence for 3D battles | not started |
| 10 | Home and forge in 3D | not started |
| 11 | Store, levels and grades on the 3D path | not started |
| 12 | Safe zones and map twists in 3D | not started |
| 13 | Elite trials in 3D | not started |
| 14 | Loot and XP presentation in 3D | not started |
| 15 | Polish: bosses, levels 50–350, loading screen, settings | not started |

The 2D game keeps working at every step, and the 3D preview is reachable from the
home screen, so both can be compared on a device at any time.
