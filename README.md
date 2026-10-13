# Battle of Sword Master

A premium, warm-earth 3D arena battler built with Flutter and `flutter_scene`. Forge and merge weapons, climb a 350-level campaign across seven ranked regions, and take on the Elite chimera trials. The arena uses procedural geometry and a top-down 3D camera; campaign progress and inventory are saved locally.

## Requirements

- Flutter **master** channel with Dart 3.10 or newer
- Android SDK for the Android build, or Chrome for the web preview
- Flutter native-assets support enabled for local builds:

```sh
flutter channel master
flutter upgrade
flutter config --enable-native-assets
flutter pub get
```

For Android, ensure the app's `<application>` in `android/app/src/main/AndroidManifest.xml` includes:

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableFlutterGPU"
    android:value="true" />
```

The GitHub Actions workflow generates the Android runner and applies this setting before verifying the project.

## Run

```sh
flutter run -d chrome
```

For a local Android runner, create the platform scaffold in the project checkout once, then launch on a connected device or emulator:

```sh
flutter create --no-pub --platforms=android --org=com.bosm --project-name=battle_of_sword_master .
flutter run --enable-flutter-gpu
```

## Game systems

- A persistent 3×3 Forge for merging six weapon tiers, offline crafting, and upgrades.
- 350 campaign levels across seven ranks, each with its own map, boss, modifiers, and progression rewards.
- Elite chimera trials with multi-phase bosses.
- Store inventory for armor and one-battle boosters.
- Free-for-all creature combat, procedural 3D combatants, shrinking safe zones, arena hazards, shrines, and touch controls.
- Local persistence under the `bosm_` preference-key namespace.

## Verification

`.github/workflows/flutter.yml` uses Flutter master, enables native assets and Flutter GPU for Android, resolves dependencies, runs static analysis and tests, then builds a debug APK.
