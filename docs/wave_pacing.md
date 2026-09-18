# Automatic waves and the optional early-start shortcut

User clarification, 2026-09-14: the Next Wave control must only make the game
faster. It must never turn automatic waves into a manual-ready system.

## Required behavior

A new battle runs its preparation countdown automatically. After the last enemy
of a non-final wave dies, the existing inter-wave countdown begins automatically.
At zero, the following wave starts without a click. Use the existing data values
(currently five simulation seconds each); do not lengthen them to encourage clicks.

The HUD shows a passive `Auto in Ns / Wave N` indicator beside a smaller optional
`Start now` button. Ignoring the button never pauses, restarts or extends the timer.
The button only removes the remaining wait: no free mine cycles, cooldown recovery,
enemy kills, currency or wave-completion rewards. It cannot skip an active wave,
start past the final wave, or make a stale touch affect a later wave.

Explicit pause, level-up choice and restored-battle pause keep their existing
semantics. Resume continues the remaining countdown. Hero death, low Keep health,
insufficient gold and unspent upgrades do not introduce additional readiness gates.
At 2x the same simulation countdown runs at the selected battle speed. Mission
victory still requires clearing its final wave; this is not auto-starting the next
campaign mission. Overlapping waves are not introduced by this change.

## Source finding and change

Reviewed branch: `codex/army-progression-menus`, base commit
`310992be2a4a7cec680a08b4ae931666ff483a3f`.

`game/game.gd::_physics_process` already advances `_advance_waves(delta)` while
playing; `_advance_waves` starts the next wave when `wave_timer <= 0`.
`game/army_game.gd::start_next_wave_now` already only clears the remaining timer.
No mandatory-click gate was found in this source revision. The reported runtime
stall has therefore **not been reproduced or proven resolved**.

The confirmed UI defect was `ui/army_menu.gd`: its full-size Start Now button covered
the entire wave panel, hiding the countdown and suggesting that player confirmation
was required. This patch separates a non-interactive countdown from the shortcut,
retains automatic scheduling, and releases held touch state when the countdown ends
or its wave identity changes. Other menus and gameplay balance are unchanged.

## Regression checks

Run the production-scene scheduler suite, not only a test of the button handler:

```sh
"$GODOT" --headless --path . --editor --import --quit
"$GODOT" --headless --path . --script tests/check_wave_pacing.gd --fixed-fps 60 --quit-after 60000
"$GODOT" --headless --path . --script tests/check_army_progression.gd --fixed-fps 60 --quit-after 4000
```

Require `WAVE_PACING_OK` and `ARMY_PROGRESSION_OK` with no script/parser errors.
The new suite uses the real `game/main.tscn` entry point, memory-only persistence
and engine-driven physics. It covers initial automatic starts, all subsequent
waves and final victory without a shortcut click at both 1x and 2x, paused and
restored countdowns, dead-hero scheduling, double/stale shortcut calls, reward
invariance, and separation of passive text from the button at several widths.

Its automated wave-clear fixture disables hero firing and removes enemies through
real damage calls to isolate scheduling from combat and XP choice overlays. This
is **not** a legal combat playthrough or a balance/visual-acceptance result.

This session checked the modified source scope against the original GitHub blob
and statically checked the layout arithmetic and presentation-only timer boundary.
**Godot import, the new GDScript suite, rendering and device tests were not run:**
no Godot binary is available in this execution environment. Existing PR remains
draft. The tests above and normal play are still required before claiming the
reported gameplay stall is fixed.

If the stall persists in that build, record branch/commit, wave number, displayed
countdown, remaining enemy count, visible pause/choice state and the first debugger
error. Do not add a second per-frame wave clock or silently bypass a level-up
choice as a speculative fix.
