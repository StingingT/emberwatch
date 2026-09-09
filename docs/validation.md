# Current validation: recovery checkpoint

Date: 2026-09-09. Engine: **Godot 4.7.stable.official.5b4e0cb0f**, Windows. The six-mission campaign and interrupted-battle recovery are implemented. The complete working-source `tools/validate.ps1 -Capture` run and a fresh-source headless run passed with exit 0. Compatibility rendering was reviewed on an NVIDIA RTX 3060. This establishes Windows/source behavior, not a signed iPhone build or native-device performance.

The current detailed evidence is [recovery_validation.md](recovery_validation.md). The earlier first-playable checkpoint **`0a59cd5`** and campaign checkpoint **`25793af`** are historical; their evidence remains in [first_playable_acceptance.md](first_playable_acceptance.md) and [campaign_validation.md](campaign_validation.md). Full-game development remains active.

## Reproduce

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/validate.ps1 -Capture` from the project. The wrapper checks success markers and error output as well as exit status, rejecting script errors, explicit failures and reported ObjectDB leaks. README lists the equivalent direct Godot commands for Mac. Logs and captures are generated under `artifacts/`, outside source control.

| Suite | Passing assertions |
| --- | ---: |
| Economy and battle flow | 68 |
| Combat and physical rewards | 44 |
| Native-input UI, campaign, settings and Continue | 134 |
| Feedback and wave totals | 13 |
| Profile compatibility and storage recovery | 57 |
| Campaign lifecycle | 71 |
| Actor snapshots and silent restoration | 71 |
| Run journal and shared atomic storage | 68 |
| Root recovery/lifecycle/validation | 165 |
| Terminal identities and collision edges | 25 |
| Android Back routing | 9 |
| Paired continuation over 20 seconds | 1,242, including 1,200 per-step comparisons |

The first eleven suites total 725 assertions, including 9 Android Back-routing checks. These counts include repeated state assertions; they are not counts of independent gameplay scenarios. Tests use isolated paths or memory-only profile/run stores and preserve player files.

## Outcomes and evidence boundaries

- **Recovery:** one resumable battle, five-second deferred checkpoints plus pause/title/suspension/desktop-close handling; Continue restores paused with no offline time. Ordered actors, current rewards, modifiers, health and exact timers survive. Validation, backups, terminal retirement and idempotent profile reconciliation are covered.
- **Continuation:** a fresh JSON restoration matched uninterrupted real-root simulation at every step for 20 seconds. A second restoration after kills, collection and wall destruction also matched, without duplicated effects. Both runs reached the next authored wave; the progressed checkpoint restored identically.
- **Legal play:** the original Briarwood win and every campaign mission passed again under normal resources, movement, purchases and combat. The unattended defense still lost on wave 4. Complete-state automated play proves legal winning paths, not human pacing or difficulty.
- **Presentation:** actual rendering covered gameplay, Smith, pause, three-tier tower/wall/mine/Smith progression, six mission maps, campaign/settings/help/results and recovery title/paused/resumed views. Staged captures are visual evidence, not balance evidence.
- **Portable source:** the current recovery source passed import, every headless suite, original active/unattended scenarios and all six legal wins after extraction into a fresh Windows directory. The path and packaging evidence are recorded in [recovery_validation.md](recovery_validation.md). Rendering was checked separately in the working source.

## Reference loop retained

Portrait angled 3D, scrolling routes, move-and-auto-fire combat, real arrows, collectible gold, hero-only kill XP, active Volley, nearby live purchases, blocking/destructible walls, mines, Smith modifiers, three visible structure tiers and a vulnerable Keep remain covered. Campaign missions add route and plot strategies while preserving that loop. Previous construction-under-hero and held-purchase/input-interruption regressions remain covered by the expanded suites.

The implemented recovery contract is [run_recovery_plan.md](run_recovery_plan.md). The active roadmap is [campaign_plan.md](campaign_plan.md) and `PROJECT_PLAN.md`.

## Still pending

Human feedback on clarity, campaign pacing, economy, difficulty and enjoyment; further presentation/audio polish and release preparation remain. Passing this checkpoint does not finish the full-game goal.

Mac import, signed iOS export/install, Android APK export/install, real iPhone 12-16 and Android multi-touch/safe areas, operating-system interruption/relaunch behavior, sustained frame time, memory and heat require native testing. These later or parallel checks do not block compatible desktop development. The iOS and Android presets are **0.3.0/build 3**, with placeholder signing identities. No native-phone validation, GitHub publication, TestFlight/Play Store/App Store release or exact-commercial fidelity is claimed.
