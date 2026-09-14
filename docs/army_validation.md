# Army progression validation status

## Evidence for this branch

Base: `codex/battle-recovery`, commit `5e5c523c7bcba59281f5dae20a29de0e538bb9e6`.
The parent branch was read through the GitHub connection before changes.

Implemented in source: additive Supplies/training ledger, wave/victory receipts,
one-time achievement grants, copied per-run training, recovery adapter, flat menus,
1x/2x and Start Now controls, staffed evolving towers, and a disabled-by-default ad
provider boundary with a 50% bonus formula.

**Not executed here:** Godot import, GDScript runtime tests, rendering, mobile tests,
normal-speed playtesting, balance testing or an actual rewarded advertisement.
The execution environment has no Godot binary and could not download the engine.
Do not carry over prior milestone pass counts as proof for these new files.

A static checker verifies selected content/configuration invariants and references.
It is not a GDScript parser or substitute for the tests below. The pull request stays
in draft until actual runtime and visual acceptance are recorded.

## Commands for the engine-equipped environment

Use the repository-pinned standard Godot build. Example shell commands (set
`GODOT` to its executable path):

```sh
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script tests/check_army_progression.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_economy.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_combat.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_ui.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_recovery.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_recovery_edges.gd --fixed-fps 60 --quit-after 4000
"$GODOT" --headless --path . --script tests/check_campaign_playthrough.gd --fixed-fps 60 --quit-after 150000
```

Require `ARMY_PROGRESSION_OK` and all other suite success markers, with no script or
parser errors; an exit code alone is insufficient. Older suites preload game.gd;
the new suite explicitly loads army_game.gd. Test both rather than only the old root.

## Still required

- Extend targeted checks to invalid trained-health payloads, old zero-training
  snapshots, per-wave checkpoint rollback and crashes between wallet/journal writes.
- Exercise a fake provider in tests only: completion, repeat callback, cancellation,
  no-fill, callback after leaving the result screen and reload after a claimed bonus.
- Disk IO failures, backup restoration and future-schema protection for the new file.
- Real menu screenshots at standard, compact, large-control and safe-area sizes;
  no clipped costs, overlapping buttons, hidden save notices or touch leaks.
- Normal camera comparison of all tower tiers and live 1/2/3-arrow salvos; check the
  unchanged total damage and higher projectile/crew rendering load.
- Play the first three missions without ads at zero and early permanent training;
  tune the provisional rewards, gates and difficulty from observed results.
- Physical Android/iPhone performance and touch acceptance remain separate.

## Automatic-wave follow-up

Read [wave_pacing.md](wave_pacing.md) for the user's clarified automatic-start
contract, the hidden-countdown finding and the new production-scene regression.
Also run `tests/check_wave_pacing.gd` with `--fixed-fps 60 --quit-after 60000` and
require `WAVE_PACING_OK`. This suite has been added but not executed here. Only
source-preservation, layout-arithmetic and passive-timer static checks were run;
the reported runtime stall has not yet been reproduced or proven resolved.
