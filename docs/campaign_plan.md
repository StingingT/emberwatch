# Campaign completion milestone

The user asked to continue finishing the game after the first playable was accepted. The architect promotes the roadmap's campaign, local saves, onboarding and settings into active implementation. The six-mission structure is the current design decision; it does not change the original combat/building loop or claim store-release completion.

## Playable campaign

- Six original missions: Briarwood Crossing, followed by five routes with different tower/wall/support opportunities and progressively stronger waves.
- Briarwood retains the accepted first-playable layout and balance as a regression baseline.
- Complete a mission to unlock the next. Replay unlocked missions and retain the best star rating and completion time. A win earns one star; keeping at least 40%/80% of maximum Keep health earns two/three.
- Each battle starts fresh: gold, structures, hero XP and Smith effects are local to that run. Campaign unlocks and results persist between app sessions.
- Mission selection states the tactical variation before battle. The sixth victory gives a campaign ending and keeps all missions replayable.
- No forced waiting, paid gates, online services or changes to hero-only kill XP.

## Saves and settings

- A versioned local profile stores mission results and sound, reduced-motion, larger-control and tutorial-hint preferences.
- Validate loaded primitives, preserve future-version files, and recover a malformed primary from a valid backup. A failed save must not crash or prevent session play, and must produce a visible status.
- Headless tests and screenshot fixtures use isolated or memory-only profiles so they cannot alter the user's campaign.
- First-run guidance explains movement/auto-fire, collecting gold, building, XP and Volley in response to actual actions. It remains noninteractive and can be disabled.
- Reduced motion removes cosmetic bobbing, scaling and impact flashes while keeping gameplay movement/projectiles. Larger controls keep the portrait layout usable.
- This profile milestone preserves completed missions and preferences. Restoring a partially completed battle after the operating system terminates the app is a separate outstanding save feature, not a completed claim.

## Ownership and interfaces

- `game/campaign_data.gd`: fresh mission dictionaries `{id,name,briefing,level,waves}`. Level adds optional starting gold, Keep health, building-limit overrides and palette to the existing schema.
- `game/player_profile.gd`: owns versioned profile serialization and recovery, not runtime actors or gameplay rules.
- `game/game.gd`: owns mission selection/unlocks, world replacement, run reset, results, tutorial decisions and preference application. Existing `start_run()` restarts the selected mission.
- `ui/hud.gd`: displays campaign/ending/preferences and emits selection or setting signals; it does not decide unlocks or write saves.
- `levels/battlefield.gd` and entity presentation consume mission palette/preferences without changing combat rules.

## Evidence required before campaign acceptance

1. All prior gameplay, touch, economy and feedback checks still pass.
2. Real profile roundtrip, backup recovery, future-version protection and failure handling pass without touching player files.
3. Locked missions reject selection; victory unlocks only the next; loss does not unlock; weaker replays cannot reduce records.
4. Switching and restarting missions replaces routes/plots/waves and clears the previous battle. Level-specific limits affect both purchases and UI.
5. All six missions have legal winning playthroughs using actual movement, gold, combat and purchases. Fixture grants or forced kills are not difficulty evidence.
6. Mission selection, settings, onboarding and campaign ending render and work with native touch. Larger controls and reduced motion receive dedicated checks.
7. The updated source package imports and runs from a fresh directory.

## Remaining full-game work

The full goal remains active beyond a campaign scaffold or passing profile test. Finish and validate campaign pacing, interrupted-run recovery, presentation/audio polish and release preparation as implementation progresses. Human play feedback and native Mac/iPhone export, signing, real-device input/performance remain later or parallel verification; they do not block compatible desktop work. GitHub publication remains a separate future action.

The campaign checkpoint evidence is recorded in [campaign_validation.md](campaign_validation.md). The next feature is specified in [run_recovery_plan.md](run_recovery_plan.md); it is a proposal for implementation, not a completed save/resume claim.
