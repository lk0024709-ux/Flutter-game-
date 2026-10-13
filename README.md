# Blade Brawl: Rannbhoomi

A Flutter + Flame top-down arena brawler with a premium, warm earthy UI. This repository is being built in playable increments.

## Run locally

1. Install Flutter 3.0+ and a compatible Dart SDK.
2. Generate the Android runner once: `flutter create --platforms=android --project-name blade_brawl .`.
3. Run `flutter pub get` from the project root.
4. Run `flutter run` on an Android device or emulator.

## Current playable foundation

- Persistent 3×3 weapon forge using `shared_preferences`.
- Same-tier merge progression across six weapon tiers.
- Coin wallet, armor purchase/equip, and booster store.
- Flame arena with virtual movement control, sword attacks, health bars, collision separation, and free-for-all creature targeting.
- Muted earthy Material theme with Manrope/Inter typography.

## Implementation status

This first feature branch establishes the playable core loop. The full specification's handcrafted map twists, 350-level campaign progression, storm/shrine/sanctuary systems, seven multi-phase chimera fights, elite loot, and detailed grade/reward breakdown are not yet implemented. They should be added and validated in follow-up increments before calling the game release-ready.
