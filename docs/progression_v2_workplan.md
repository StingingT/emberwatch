# Gameplay & Progression v2 — implementation workplan

Base reviewed: `StingingT/emberwatch` main at
`758b20b2d38a002779ed3f7995ce20c430940fe8`.
Target branch: `codex/progression-v2-targeting`.

This records the approved v2 contract and its latest range amendment for agents.
It is a staged workplan, not a claim of implemented feature parity. The full user
specification is `Emberwatch_Gameplay_Progression_Spec_v2.md`; the amendment below
is additive. Preserve the Godot repository and keep the web version separate.

## Latest confirmed amendment: one attack range

Ranged monsters/goblins use the hero's **basic bow attack range**, including when
shooting at blocking walls. Do not use the larger Volley radius, a separate
seven-unit ranger range, or a short melee distance for ranged wall attacks.
The current configured bow range is 8 world units. Read its shared/current value.
Recheck eligibility at release. Death of the hero does not change wall range.

Implementation default: the same horizontal centre-to-centre convention and
strict outer-boundary comparison as the hero target selector. Range parity does
not remove wall priority, wall occlusion, visible wind-up, non-homing bolts or
attack cooldown. Future range upgrades must also preserve sufficient projectile
lifetime and frozen saved stats; do not change only the target-check number.

## Approved whole-milestone rules

### Fortress and wave resolution

Start with 10 fortress lives, configurable in mission data. A normal/elite/boss
consumes 1/2/5 lives once on arrival and leaves play. Classification is independent
of locomotion/attack role. Leaks are not kills: no coins or kill reward; previously
earned hero damage XP remains. Keep killed and leaked counts separate from lost
life total. `spawned = killed + leaked + living`. Waves resolve after all spawns
and living enemies have resolved, and still start automatically after their wait.
Defeat at zero lives takes precedence over final-wave victory in the same step.

Victory ratings: zero lost lives = 3 stars; 1–4 = 2; 5–9 = 1. Defeat = 0. Hero death
alone does not change stars. No fortress healing, extra lives or leak reduction.
Walls and hero keep HP. Masonry/Fortify become WALL-only; preserve paid ranks and
update all descriptions, previews and runtime multipliers together.

### Finite Stars and repeatable Supplies

Keep best stars per mission/normal difficulty, lifetime earned, and spent purchase
records. Available = earned minus spent. New stars = max(old best, rating) minus
old best. Spending never erases mastery. A 3-star replay after spending awards zero
new stars; improving 1 -> 2 -> 3 awards +1 each time. Six normal missions have 18
possible earned stars. No farmable refill or hard mode yet.

Stars buy permanent hero technologies/building unlocks. Supplies buy generic
bounded training: hero damage/health, tower damage/fire rate, wall health, mine
output. Remove star gates from Supplies training when the coordinated migration
lands; do not delete purchased ranks. Retain physical in-run gold for building,
in-run tiers and Smith purchases. Freeze training and technology at run start.

Proposed, data-driven one-time technologies: Siege Engineering (2 stars, Ballista
unlock); Combat Readiness (2, start level 2 with one ordinary choice before prep);
Field Recovery (2, respawn 8 -> 6 seconds); Volley Discipline (3, cooldown 12 -> 10).
Do not grant free buildings, enemy XP or rewards for starting level. Baseline hero
and Archer Towers must counter mandatory flyers even without a Ballista purchase.
Existing buildings, abilities and missions stay available after spending stars.

Normal wave/victory Supplies remain repeatably earnable. Defeat keeps completed
wave Supplies. Only an improved best rating earns more stars. Optional real ad
completion adds floor(normal battle Supplies * 0.50), once per terminal run, excluding
achievement grants and ALL stars. No provider is enabled by this work.

### Enemy roles, routes and flight

Declare classification, locomotion and attack role separately. Only ranged enemies
attack the hero; others ignore them, with no retaliation/contact damage/chase. No
enemy attacks towers, Mine or Smith. Ground enemies attack blocking walls; flyers
follow routes at visible altitude and pass over walls without stopping or attacking.
Flyer coins land on collectible ground. Ranged attackers prioritise an in-range
blocking wall; otherwise they may shoot an eligible hero and move during recovery.

Choose the shortest allowed AUTHORED route by polyline length with stable ties.
Default: destructible walls do not cause a longer detour; ground units break walls
on their chosen shortest route. Flyers follow the permitted route above walls,
not arbitrary straight-line shortcuts. Use multiple spawn entries and shared graph
costs; no random longer paths simply to fill the map. Persist route identity and
progress. Announce new routes/roles before combining them into dense waves.

### Ballista

Long range, slow rate, heavy travelling bolt, limited direct piercing, then ONE
small ground-only splash on landing. Lock a ground aim point at release; a killed
target does not cancel flight. Sweep real 3D trajectory segments in hit order.
Base max_direct_hits=1 means one enemy TOTAL. Exhausting that budget does not stop
flight or detonate the bolt. Direct hits may hit airborne volumes actually crossed;
splash eligibility always excludes flying units. A surviving direct-hit ground
enemy may also receive the one splash. Stable IDs prevent repeat per-frame/restore
hits. No friendly damage or hero XP. Multiple operators fire one machine/one bolt.

Initial tuning (L1/L2/L3): costs 90/140/210 gold, range 11/12/13, interval 3.2/3.0/2.8,
direct damage 32/52/78, splash 12/20/30, radius 1.20/1.45/1.70, distinct direct hits
1/2/3. Apply generic tower/Smith multipliers once to each component. Compare with
equal-gold Archer Tower deployments. Eligible tower plots gain a Ballista option
after Siege Engineering; allowed_buildings is plot data, not hard-coded UI.

Visuals: timber firing bed and one operator -> larger braced swivel with two ->
reinforced siege platform/winding machinery with three. Red clothes/ornaments;
wood and restrained metal structure. Show loading, aim, release, recoil and dust
impact, not a magical fireball. Model muzzle and actual shot originate together.

### Art and menus

Mine: visible quarry depression -> covered timber mine entrance -> hoist/crane,
carts, rails and loading area. The pit needs a terrain opening or inset patch;
putting it below an opaque plane does not work. Build, tier change, removal, restart
and recovery must correctly add/replace/remove the visual ground patch. No changed
walking collision or fall hazard. Preserve real physical mine output.

All living on-screen enemy bars appear even at full HP; camera-facing, green fill,
dark backing, approximately 32x5 phone pixels as a review target. Derive height from
model bounds/altitude. Elite/boss markers and larger bars follow classification
when those properties are integrated. Dead/leaked/behind-camera bars are hidden.
Inspect opacity/order/scaling at real gameplay camera size, not just isolated art.

Simple portrait HUD shows fortress lives, separate hero HP, gold and automatic
wave countdown with optional Start Now. Results distinguish match rating from
NEW stars (+0 on mastered replay), previous/new best, lives lost and Supplies.
Upgrade menus split Technologies/Stars and Training/Supplies; Achievements remain
separate. Star wallet shows available and earned. Keep red allies, green enemies,
1/2/3 archer tower crews and family-specific believable age progression. No automatic
hero/monster cosmetic changes from stats or technologies.

### Difficulty and preservation

Retune existing mission IDs: basic grounds -> runners/elite -> ranged pressure ->
first flyers/two entries -> mixed approaches -> coordinated waves/boss. These are
tuning proposals, not proof of difficulty. Test zero/early training and different
star-purchase choices with no ads. Layout, coverage, enemies and progression must
work together; do not cancel permanent upgrades with dynamic enemy stat scaling.

Version and back up migrations. Preserve historic best stars, Supplies, ranks,
settings and earned achievements. Seed existing normal star entitlement once.
Settle old terminal transactions under old rules first. Do not convert old active
HP battles to lives by rounding: mark incompatible with a clear notice. New saves
need lives/leaked counts, wave/spawn IDs, route progress, frozen technologies and
projectile hit history. Best-rating credit plus star entitlement and each purchase
must be atomic/recoverably once-only. Use non-recycled enemy IDs. Resume paused at
1x; do not apply later purchases retrospectively to an interrupted battle.

## Work packets and current status

| Packet | Status | Dependency / acceptance |
| --- | --- | --- |
| G0 branch/contract inventory | Started | Source pinned; latest range rule recorded |
| G1a enemy targeting + HP bars | Implemented in source; NOT engine-verified | New actual-entry tests and renderer inspection required |
| G1b lives + leaks + ratings + saving | Not implemented | Replace HP outcomes and snapshot invariants together; test final-wave defeat |
| G2 shortest graph/multiple spawns/flying content | Not implemented | G1 lifecycle first; preserve stable route/actor IDs |
| G3 spendable stars/technologies/migration | Not implemented | G1b outcomes, atomic best-result delta and purchase receipts |
| G4 quarry and remaining UI/art | Not implemented except bars | Terrain lifecycle, phone readability, no balance logic in visuals |
| G5 Ballista | Not implemented | G1/G2 lifecycle + G3 building unlock contract |
| G6 campaign retuning | Not implemented | After the features; measure no-ad play, leaks and upgrade value |

The G1a patch deliberately does not change fortress HP, star wallets, progression
saving, wave scheduling, tower art or the web prototype. Existing hunter visuals
are retained as fast route runners. A locomotion field prepares wall-bypass logic;
this is not a claim that visible flying enemies now exist in missions.

CONTINUE with runtime/visual validation of G1a, then G1b and the remaining dependent
packages. HOLD merge/release until actual tests and playtest evidence exist. HOLD
hard mode, diamonds, paid speed, gear, cosmetic store/loot, live ads, fortress healing
and unrelated persistence rewrites. No background execution is implied by this plan.
