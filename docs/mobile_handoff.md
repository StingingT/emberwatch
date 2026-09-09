# Mobile handoff: iOS and Android

Emberwatch uses one Godot project for Windows, iOS and Android. The game remains portrait, touch-first and on the Compatibility renderer. Android is a secondary validation target alongside the iPhone-first plan; it does not require a separate gameplay implementation or an engine change.

## Current status

The source project and desktop validation are ready for both mobile export paths. Windows is now configured with OpenJDK 17, the Android SDK, platform tools and the Godot 4.7 export templates. A debug APK exported successfully from the Android preset on 2026-09-09; no physical Android device is currently connected, so touch, lifecycle, safe-area and performance results remain pending. The iOS preset is a signing template and has not been installed on a physical iPhone.

## Android setup

1. Install the pinned Godot 4.7 stable release and matching export templates.
2. Install Android Studio's Android SDK, platform tools and OpenJDK 17. In Godot Editor Settings, set the Android SDK and Java paths.
3. Enable USB debugging on the test phone, or create a portrait Android emulator. Keep signing keys outside the repository.
4. Import `project.godot`, run the headless checks from the README, then export the Android preset to a local APK path.

Example debug export from a configured machine:

```sh
godot --path . --export-debug "Android" builds/android/Emberwatch-debug.apk
adb install -r builds/android/Emberwatch-debug.apk
```

Use a release export and a private keystore for distribution. Never commit the keystore, passwords or generated APKs. The current local debug APK is `builds/android/Emberwatch-debug.apk` (28,405,199 bytes; SHA-256 `6955EAF49A5FDBB9B19C6BA54BE4D1204048C35282436226AAA0B3E37426493B`).

## Android acceptance

- The game opens in portrait and keeps the HUD, campaign cards, settings, Continue screen and controls inside the device safe area.
- Two-finger movement plus construction, upgrades and Volley work without a stuck touch after pause, app switching or rotation attempts.
- Android Back pauses an active battle; from an overlay it follows the screen's Back action. A title-screen Back may exit only after the intended product behavior is confirmed.
- Closing or backgrounding a busy battle writes a checkpoint. Relaunching and choosing Continue restores it paused, with no offline time or duplicate rewards.
- Play all six missions, including Sunscar's support choice and Moonfen's mine limit. Check victory, loss, retry, unlocks, saved settings and the final ending.
- Measure busy-wave frame time, memory, battery draw and device temperature on at least one mid-range Android phone and one newer phone. Record actual Android version, device, Godot version and renderer.

The existing Windows tests prove game rules and controlled lifecycle behavior; they do not prove Android GPU performance, release signing, OEM safe areas or physical touch feel. Record those results in [mac_iphone_handoff.md](mac_iphone_handoff.md) and [recovery_validation.md](recovery_validation.md) when a device run is available.
