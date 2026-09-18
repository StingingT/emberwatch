# Permanent army progression and simple menus

Authorized direction: 2026-09-14. Implementation target is a replayable offline
hero/tower-defense game with meaningful permanent strength, not an ad-dependent
progression wall. This specification supersedes conflicting older meta-progression
HOLD instructions; it does not sign off earlier human/device acceptance.

## Economy

| Resource | Earned | Used | Lifetime |
| --- | --- | --- | --- |
| Gold | Physical enemy drops, mine production | Build, tier upgrades, Smith | Current battle |
| Supplies | Cleared waves, victories, achievements | Permanent army training | Persistent |
| Stars | Best mission performance | Training/achievement milestones | Persistent, never spent |

No diamonds or gear are introduced. Rewarded ads are optional and unavailable
until a real provider is integrated.

Initial, explicitly provisional tuning:

- Completed wave: `12 + 4 * zero_based_mission_index` Supplies.
- Victory: another `40 + 12 * mission_index + 8 * stars` Supplies.
- First victory on a mission: another 40 Supplies, once.
- Loss: retain completed-wave Supplies. Restarting midway through an uncleared
  wave earns nothing for that wave. No premium-per-kill currency.
- Repeating a victory earns normal wave/victory Supplies, never more total stars
  unless the saved best rating improves.
- Ad bonus: **50% of the total normal battle Supplies**, rounded down. For 180 normal
  Supplies, completion grants 90 more, total 270. One claim per finished run.
  Bonuses from achievements are not included in the ad multiplier.

The ledger checkpoints cumulative wave rewards and terminal outcomes by run ID.
First clears and achievement grants are recorded in the same document as their
wallet changes. New runs have new IDs; reopening an old result or replaying a saved
checkpoint must not create another reward.

## Permanent strength

Six upgrade tracks, five ranks each:

| Track | Per rank | Maximum |
| --- | --- | --- |
| Bow training | Hero attack, level-scaled damage and Volley base damage +6% | +30% |
| Endurance | Hero max health +10% | +50% |
| Archer drills | Tower damage +6% | +30% |
| Ready strings | Tower firing rate +4% | +20% |
| Masonry | Wall and Keep health +10% | +50% |
| Mining tools | Physical mine gold output +10%, rounded to integer | +50% |

Rank prices: 80, 140, 240, 400, 650 Supplies. Required total best stars: 0, 3, 6,
9, 12. Numbers are data, not a claim that the campaign has been balanced.

The training and Smith multipliers combine multiplicatively. No enemy stat scales
with the player's training rank. Later levels can remain harder while returning to
an earlier level should feel easier. Training is copied into a new battle and
remains fixed across death/respawn/recovery. It never alters selected cosmetics.

Keep all currently unlocked skills and three building tiers available. The preview
images were layout references, not approval to re-lock existing tier access behind
Supplies, introduce diamonds or recolor friendly archers blue.

## Achievements and visual identity

Eight initial achievements award Supplies and an earned entry: clear one/three/six
missions, and reach three/six/nine/twelve/eighteen total best stars. Grants happen
once, including applicable grants for existing campaign saves. No unimplemented
skin is advertised as available.

Future hero/monster cosmetic unlocks may come only from achievements, a reviewed
store or reviewed chance-based loot. Run leveling and permanent stat training do
not change cosmetics. Gameplay-required ability trajectories remain readable; they
are functional feedback, not a cosmetic reward grant.

Archer Towers now grow from a wooden frontier platform into masonry and a larger
reinforced stronghold, with 1/2/3 red archers. This is one family-specific path, not
a universal material rule. Other building families retain separate workshop,
extraction and fortification identities. The extra archers fire real arrows,
sharing the tier's existing total salvo damage rather than accidentally multiplying
it by the crew count. Footprints remain unchanged; growth is predominantly upward
with top-platform overhang. Check visibility, projectiles and occlusion in-engine.

## Menu layouts

Use simple old-school game menus, not an ornate mobile-store dashboard.

Home: small title; Supplies and stars; Continue when relevant; Battle; Army upgrades;
Campaign; existing Settings and Help.

Upgrades: a small balance header and three tabs. Hero shows two rows; Defenses four;
Achievements four per page. Each upgrade row has its name/rank, current-to-next
benefit, cost or exact star gate. No giant art header, currency storefront or extra
reward tracks on the same screen. All training applies to the next new battle.

Results: outcome and mission; earned stars, Keep percentage, waves and simulation
time; normal Supplies already earned; optional +50% button; separate achievement
reward where earned; Upgrades, Main Menu and Next/Retry. Never hide normal rewards
behind a claim/ad choice. An unavailable ad is disabled and labeled unavailable.

Pacing: free Start Now during preparation/inter-wave downtime. It changes only the
remaining wait; it must not simulate extra mine cycles, healing or ability cooldowns.
Free 1x/2x in pause. All battle systems scale together; use normal-speed controls in
menus and restore interrupted games at 1x. No real-money entitlement is added.

## Architect work packets

CONTINUE A — Core integration: validate main.tscn -> army_game.gd, copied run ranks,
profile preservation, actor health validation, economy math and once-only receipts.
Own game/army_*.gd and tests/check_army_progression.gd; coordinate any shared changes.

CONTINUE B — Menus: render and adjust ui/army_menu.gd using actual mobile safe-area
sizes. Reuse touch ownership/reset behavior. Keep payments/ads outside the view.

CONTINUE C — Building evolution: inspect common/army_building_visuals.gd and the
building actor's shot origins; refine silhouettes without expanding ground blockers
or violating the red faction rule. Other families may evolve differently.

CONTINUE D — Progression balance: play the existing first three missions at zero,
early and relevant capped training. Record victory/failure, Supplies per minute,
number of replays to the next useful upgrade, idle stretches, hero deaths and Keep
health. Improve enemy combinations and pressure rather than merely increasing
health. Do not make the easiest opening-wave reset the optimal progression route.

HOLD E — Live advertising/store: keep the provider absent. Later add verified reward
completion, failure/no-fill handling, consent/privacy and physical-device tests as
a separate approved integration. Do not add a debug reward button to release play.

## Acceptance before merge

Run the new targeted suite against the actual entry point, then existing combat,
economy, UI, campaign and recovery suites. Verify training across new runs, deaths,
settings changes, restarts and continued battles; bad/newer saves; duplicate grants;
50% math; disabled/cancelled ads; one-time achievements; fractional JSON numbers;
2x/pause clock reset; live wall/Keep health; mine pickups; tier crew counts and total
salvo damage. Inspect real portrait and compact-device renders, then human-playtest
normal busy combat. Source-only and simulated math checks are not acceptance.
