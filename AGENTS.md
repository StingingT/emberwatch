# Emberwatch agent instructions

Read `docs/architecture.md`, `docs/army_progression.md` and
`docs/army_validation.md` before changing gameplay or progression. The user's
2026-09-14 authorization promotes army progression and simple menus; older HOLD
statements about that scope are superseded, not the outstanding combat/device tests.

The production entry point is `game/main.tscn` -> `game/army_game.gd`. Preserve the
updated combat in `game/game.gd`; do not replace it with the older main-branch game.
Run both the new entry-point suite and existing regression suites. Record actual
commands, pass markers and real renderer evidence; never infer playtest acceptance.

Keep red allies, green enemies, simple readable visuals, in-run building evolution,
and the separation between permanent training and hero/monster cosmetics. No
diamonds, gear, paid speed, live ad SDK or fake ad-completion button in this patch.

The branch is draft until engine import, runtime tests, visual inspection and
playtesting pass. Follow the explicit CONTINUE/HOLD work packets in the progression
specification. Do not merge or claim validation on behalf of a human reviewer.
