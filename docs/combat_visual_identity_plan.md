# Combat & Visual Identity Pass

Status: active milestone, authorized by the user on 2026-09-12. Implementation and acceptance are not yet complete. This supersedes earlier deferrals of hero damage/death, expanded abilities and enemy targeting. Keep Godot 4.7, portrait mobile play and the existing six missions.

## HOLD until this milestone passes

- Additional campaign missions.
- More save-system work or recovery complexity.
- More settings.
- Monetization, equipment and meta progression.

Do not replace this milestone with infrastructure cleanup or more automated proof of the old combat loop. Existing persistence is retained; only essential compatibility adjustments for new combat state are permitted, with no new recovery features or storage redesign. Do not claim that an old checkpoint preserves newly introduced combat state unless verified.

## Design and acceptance

### 1. Hero danger

The hero owns health and exposes damage/death state. Enemy attacks have visible wind-up, clear reach and recovery time. The HUD shows hero health independently of XP and Keep health. Getting hit is legible; being near an enemy does not cause untelegraphed damage every frame. Movement remains responsive while attacking.

Acceptance: a player can recognize a threatening attack, move out of it, take damage if caught, and distinguish hero damage from Keep damage. Pause stops attack timers and damage.

### 2. Death and respawn

Hero death does not end the defense. Shooting, abilities, collection and construction stop while the hero is down; enemies, towers and waves continue. Show a respawn countdown, then return the hero to a clear friendly spawn with full health and a brief, visibly indicated protection period. Keep destruction still ends the mission. Preserve earned run XP and chosen abilities on respawn; do not add a currency penalty initially.

Initial tuning proposal: eight-second respawn, 1.5-second protection. Store these as balance data. Tune from actual play rather than treating these numbers as acceptance requirements.

### 3–4. Three meaningful level-up choices and visible abilities

Offer three clearly different combat choices at level-up milestones, with brief descriptions of what changes. Initial design: Multishot for wider coverage, Volley for a stronger active burst, Piercing for enemies lined up along the route. Subsequent choices strengthen a selected approach or add another. Choices are local to the current run, not persistent progression.

Pause the battle while choosing and discard held movement/purchase inputs when opening or closing the choice panel. Ordinary construction remains live. Hero XP is earned from actual hero damage, proportional to the fraction of enemy maximum health removed. Fractional XP accumulates immediately; tower damage and kill credit award no hero XP. Overkill is capped to remaining health. This replaces the earlier kill-only rule at the user's request.

Acceptance: each choice changes actual combat behavior, not just a percentage label. Multishot visibly sends several arrows; Volley has a distinct burst and cooldown; Piercing travels through multiple enemies without repeatedly damaging the same enemy on successive frames. Shapes, motion and trajectories distinguish them without relying on color alone. No choice may become a free unavoidable replacement for every other choice.

### 5–6. Two new enemy roles

- Ranged goblin: a readable ranged weapon, wind-up and visible projectile aimed at the hero's position when fired, allowing movement to evade it. Uses bounded attack range and returns to the defense route when the hero is unavailable.
- Hero hunter: a distinct silhouette, bounded pursuit/leash and a telegraphed close attack. It pressures aggressive coin/XP collection without chasing forever across the map. Return to the route when the hero dies or leaves pursuit range.

Introduce these gradually within the existing first three missions. Early encounters teach each threat before mixing it into a crowded wave. Existing route attackers continue threatening walls and the Keep, so evading the hero threat is not sufficient to win.

### 7. Building tiers with strong visual differences

All four existing building types need unmistakable L1/L2/L3 silhouettes at the actual portrait camera distance. Towers gain height and visibly stronger weapon/platform features; walls change construction material, thickness and defensive features; mines gain extraction machinery; Smiths grow into substantial active forges. Red faction accents remain consistent. Recoloring or modest uniform scaling alone does not pass.

Acceptance: inspect each tier in normal battlefield views as well as a comparison gallery. A human tester should identify which building is upgraded without reading a label. Footprints, paths and plot interaction must remain usable.

### 8. Floating Smith bulbs

Replace the current row of rectangular Smith buttons with three visually distinct floating purchase bulbs associated with the forge. Each shows an intelligible effect and price, responds immediately to purchase and communicates affordability. Keep sufficiently large, separate touch targets. Track the forge's screen position and clamp away from the HUD, movement stick and Volley control. Do not introduce a fullscreen shop.

### 9. Combat and construction spectacle

Strengthen coin emergence and collection, kill reactions, arrow impacts, hero attacks and rapid building construction. Use a consistent original effect style, distinct sound cues and bounded simultaneous effects. Visuals must convey actual reward/damage events without obscuring enemies or fabricating extra rewards. Respect the existing reduced-motion preference; do not add settings.

Acceptance: compare normal-speed busy combat before/after. Coins, kill attribution, attack direction and completed upgrades remain readable while effects are active. The reviewer must see the improvement in play, not only in staged stills.

### 10. Human playtest and reassessment

Play the first two to three missions with the new systems. Record whether hero danger feels fair, choices change strategy, the two enemy roles are recognizable, tiers are distinguishable, Smith purchases work with movement, and effects improve excitement without hiding the action. Record confusing moments, failed attempts and stretches of waiting.

Automated tests establish damage/reward correctness and lifecycle regressions; they do not substitute for this acceptance. Collect human feedback and reassess before promoting further systems or missions.

## Implementation order

First integration: hero health, local melee attack markers/wind-up, dodgeable strikes, death/countdown and clear-position respawn are implemented in source. Dead heroes cannot build, upgrade, use Volley or collect coins. The HUD shows health/countdown/protection. Existing snapshot fields were extended only for this combat state; changed combat fingerprints keep old checkpoints from being silently reinterpreted. Ranged enemies, hunters, level choices, ability variants and the visual overhaul remain outstanding. This is not milestone acceptance.

1. Hero health, telegraphed enemy damage, death/respawn and the two enemy roles as one playable combat loop.
2. Run-local choice UI and three distinct projectile/ability behaviors.
3. Stronger building models, floating Smith bulbs and coordinated feedback/audio.
4. Tune the first three existing missions, then human playtest and reassess.

Validate each change with targeted behavioral checks and actual rendering. Run broader regression checks at integration points, not repeatedly in place of gameplay work. Keep completed, implemented-but-unverified and outstanding requirements explicit.

Hunter actor implementation: wolf-pelt silhouette with paired blades, bounded pursuit within 7 units of the hero and 5 units of its current route segment, and existing telegraphed melee. Barricades block pursuit. Targeted checks verify pursuit, leash refusal and abandoning a dead hero. It is not yet placed in campaign waves; rendered inspection and encounter tuning remain pending.

Hunters now appear in Amberfield waves 1/3/5 and Stonegate waves 2/4, replacing some scouts. The first encounter is a single hunter with a slower spawn cadence. All six missions passed the legal campaign simulation before the XP change; the portrait hunter model was rendered and inspected.
