# Kingshot-Style Commercial Remake --- Main Architect Instructions

## 1. Purpose

This document is the source of truth for the Main Architect and all
implementation agents.

The Main Architect owns: - system boundaries and dependencies; -
implementation order; - acceptance criteria; - scope control; - CONTINUE
/ HOLD decisions; - integration review.

Specialist agents must not expand scope or implement dependent systems
without approval from the Main Architect.

------------------------------------------------------------------------

## 2. Game Vision

Create a fast, highly readable mobile tower-defense/action game inspired
by the *gameplay concept* shown in misleading mobile-game
advertisements, while using an original visual identity, characters,
assets, world, UI, progression, and implementation.

The player directly controls an archer hero while simultaneously
constructing and upgrading defenses during active enemy waves.

### Core loop

1.  Enemies advance through the level.
2.  The hero moves and attacks in real time.
3.  Friendly defenses attack automatically.
4.  Defeated enemies drop physical coins.
5.  The player collects/spends coins during combat.
6.  Coins build or upgrade structures.
7.  Hero kills grant hero XP.
8.  Hero levels unlock or improve combat abilities.
9.  Waves become progressively more dangerous.
10. Survive and protect the Keep to complete the level.

The experience must feel fast. Waiting, long build timers, excessive
menus, and visually subtle upgrades are contrary to the design.

------------------------------------------------------------------------

## 3. Non-Negotiable Design Pillars

### 3.1 Fast gameplay

-   Construction occurs in real time.
-   Buildings appear rapidly after purchasing them.
-   Upgrades are similarly fast.
-   Combat should produce frequent kills, coins, projectiles, upgrades,
    and visual feedback.
-   Avoid idle downtime during normal levels.

### 3.2 Large and readable visuals

-   Buildings are major visual objects, not small background props.
-   Heroes, enemies, projectiles, coins, build plots, and upgrade states
    must remain readable on a phone.
-   Prefer strong silhouettes and simple shapes over fine detail.
-   Do not clutter maps with unnecessary decorative assets.

### 3.3 Strong visual progression

A gameplay upgrade must feel like an upgrade visually.

Building Level 1 → 2 → 3 must create obvious silhouette/scale/feature
changes.

Examples: - taller tower; - additional platform; - additional archer; -
larger cannon; - stronger wall materials; - larger forge; - stronger
projectile effects.

Simple recolors are not sufficient as the primary visual difference.

### 3.4 Original visual identity

Do not copy Kingshot assets, characters, UI, maps, logos, or exact
visual designs.

Retain useful readability principles while creating a distinct game.

### 3.5 Faction readability

Friendly/player faction: - primary identification color: **RED**.

Enemy faction: - primary identification color: **GREEN**; - initial
enemy family: goblins.

Red should appear consistently where faction identification matters,
including flags, banners, friendly-unit accents, selected UI accents,
and building identity.

Do not make every friendly asset entirely red. Maintain material and
environmental variation.

------------------------------------------------------------------------

## 4. Initial Scope

The first objective is a polished vertical slice.

Do NOT begin campaign systems, monetization, advertisements, cosmetics,
equipment inventories, multiple heroes, multiplayer, extensive metagame
systems, or large content libraries before the vertical slice passes
acceptance.

### Initial vertical slice

Required: - one large playable level; - one controllable archer hero; -
hero movement; - basic bow attack; - enemy pathing; - waves; - enemy
health/death; - physical coin drops; - coin collection; - fixed building
plots; - Archer Tower; - Wall; - Smith; - Gold Mine; - three building
levels; - hero XP from hero kills; - hero level-up; - at least one
unlockable active hero ability; - Keep; - win/loss conditions.

Barracks, Cannon Tower, hero death/respawning, advanced enemy targeting,
and additional abilities may follow once the core slice is stable unless
the Architect explicitly promotes them into the active milestone.

------------------------------------------------------------------------

## 5. Hero System

### Initial hero

Archetype: Archer.

### Required actions

-   move freely through permitted terrain;
-   basic ranged attack;
-   collect nearby physical coins;
-   gain XP from enemies personally killed;
-   level up;
-   unlock/improve abilities.

### XP rule

Hero XP is awarded for **hero kills**.

Tower/unit kills: - may drop normal coin rewards; - do not grant hero
kill XP by default.

This intentionally creates tension between safe automated defense and
aggressive hero play.

### Progression direction

Possible progression includes: - attack damage; - attack speed; -
projectile count; - piercing; - critical effects; - Multishot; -
Piercing Shot; - Volley; - visually enhanced versions of existing
attacks.

Exact numbers are balancing data and must not be permanently hard-coded
into gameplay scripts.

### Visual progression

Skill unlocks/upgrades should visibly change combat.

Examples: - additional arrows; - larger projectiles; - trails; -
stronger impact effects; - broader attack cones; - distinct ability
animation.

------------------------------------------------------------------------

## 6. Hero Risk and Death

Early levels may contain enemies that focus primarily on reaching the
player's defenses/Keep.

Later enemy types may: - target the hero; - retaliate against the
hero; - pursue the hero; - use ranged attacks; - use area attacks.

This makes aggressive XP farming increasingly risky.

### Hero death

Hero death should not automatically end the level.

Planned behavior: 1. hero is defeated; 2. hero disappears/becomes
inactive; 3. respawn timer begins; 4. defenses must survive without the
hero; 5. hero respawns at a defined friendly location.

Respawn duration and penalties must be data-driven.

This system is not required for the earliest prototype unless promoted
by the Architect.

------------------------------------------------------------------------

## 7. Enemy System

Initial enemy family: goblins.

Minimum enemy requirements: - spawn; - follow defined level routes; -
receive damage; - die; - drop coins; - reach/attack appropriate
defensive objectives.

Later enemies can introduce: - different movement speeds; - armor; -
ranged attacks; - hero targeting; - structure targeting; - elite
units; - bosses.

Do not create a large enemy roster before the basic enemy loop is
validated.

------------------------------------------------------------------------

## 8. Economy and Physical Coins

Enemies drop visible coins into the world.

Coins must: - be visually obvious; - be collectible by the hero; -
provide immediate feedback; - update the player's available construction
currency.

The economy should create frequent decisions between: - new
structures; - individual building upgrades; - Smith global upgrades; -
economy investment.

Coin values, drop chances, costs, and scaling must be data-driven.

------------------------------------------------------------------------

## 9. Building Plot System

There is **no unrestricted building placement** in the initial design.

Each level defines its available plots.

This allows each level to control strategic composition and keeps mobile
interaction simple.

### Plot categories

Potential categories: - tower plot; - wall/defensive plot; -
economy/support plot; - special plot.

A level can deliberately provide: - many tower opportunities; - many
walls; - few walls; - restricted economy positions; - unusual defensive
layouts.

The level designer, not the player, determines where plots exist.

### Interaction

When the hero/player activates an available plot: 1. valid construction
options appear; 2. cost is immediately readable; 3. player selects a
building; 4. coins are spent; 5. construction occurs rapidly in the live
game; 6. the finished structure becomes active.

Construction should be satisfying but short.

Avoid long timers.

------------------------------------------------------------------------

## 10. Buildings

Initial maximum building level: **3**.

### Archer Tower

Role: - ranged damage; - reliable single-target defense.

Visual upgrades should clearly increase tower presence and offensive
capability.

### Wall

Role: - block/delay enemies; - protect important positions.

Visual progression should move from visibly weak/basic construction
toward substantially stronger fortification.

### Gold Mine

Role: - economy investment; - generates additional value/coins.

Gold Mine competes with Smith where the level uses shared
economy/support plots.

### Smith

Role: - global combat/defensive enhancement.

The player does **not enter the Smith**.

Interaction occurs while the hero is close enough to the building.

### Keep

Role: - primary defensive objective.

If the Keep is destroyed, the level is lost unless a specific future
level defines another rule.

### Later buildings

After validation: - Barracks; - Cannon Tower; - additional specialized
defenses.

------------------------------------------------------------------------

## 11. Building Limits

Building limits must be data-driven.

Example initial configuration:

``` text
Gold Mine:
    max_per_level = 1

Smith:
    max_per_level = 1
```

The gameplay therefore initially permits only one Gold Mine and one
Smith, while the architecture allows future levels/modifiers to change
these values without rewriting the building system.

Do not encode assumptions such as `if smith_exists` as permanent global
design rules when a configurable building limit can solve the
requirement.

------------------------------------------------------------------------

## 12. Smith System

The Smith provides global upgrades without opening a separate interior
or full-screen management scene.

### Interaction

When the hero enters the Smith interaction radius: - three large upgrade
bulbs/options appear floating above or immediately around the Smith; -
options must be readable without obscuring combat; - player selects one
directly; - coins are spent; - the improvement applies immediately.

### Three-bulb presentation

The Smith presents **three upgrade choices at a time**.

Examples: - ranged damage; - melee damage; - melee defense; - unit
health; - structure health; - attack speed; - critical damage.

The exact pool can expand later.

### Global effects

Smith upgrades affect the appropriate friendly category globally for the
current level/run.

Example: `Ranged Damage +10%`

could affect: - Archer Towers; - ranged friendly units; - other systems
explicitly tagged as ranged.

Whether the hero receives a specific Smith bonus must be defined per
upgrade/tag rather than assumed.

### Visual feedback

Purchasing an upgrade should produce: - clear bulb activation; - short
Smith animation/effect; - readable upgrade feedback; - immediate
combat-stat effect where applicable.

------------------------------------------------------------------------

## 13. Building Upgrade Interaction

Built structures can be upgraded from Level 1 → Level 2 → Level 3.

Upgrade requirements: - clear coin cost; - fast interaction; - no
separate management screen for routine upgrades; -
immediate/statistically meaningful improvement; - major visual change.

The player should be able to understand a building's approximate level
from its world model without reading text.

------------------------------------------------------------------------

## 14. Map and Level Design

Maps should be significantly larger than a single-screen arena.

The camera follows the hero.

Enemy paths may wind through the environment before reaching defensive
areas and the Keep.

### Level-specific strategy

Building opportunities are intentionally different per level.

Examples: - tower-heavy map; - wall-heavy choke-point map; - limited
tower map; - economy-rich map; - long path with distributed defenses; -
later multi-entry map.

Do not normalize every level to the same number/type of plots.

### Future layouts

Later maps may include: - multiple enemy entrances; - branching
routes; - bridges; - choke points; - separated defensive sectors; -
multiple areas requiring hero travel.

------------------------------------------------------------------------

## 15. Camera and Mobile Readability

The camera follows the hero rather than showing the complete map at all
times.

The player must still be able to understand: - enemy direction; - nearby
threats; - build opportunities; - coin drops; - friendly structures; -
hero status.

Camera scale must preserve large, readable characters and buildings.

Do not zoom out merely to show more of the map if doing so makes
gameplay objects small.

------------------------------------------------------------------------

## 16. Visual Direction

Target: - friendly; - colorful; - simplified; - large shapes; - low
visual noise; - immediately readable; - strong animation feedback.

Avoid: - realistic textures; - excessive surface detail; - tiny
buildings; - tiny units; - muddy palettes; - excessive particles; -
visually complicated terrain; - overly intricate architecture.

The visual target is **simple enough to understand instantly but
polished enough to feel satisfying when something upgrades or is
destroyed.**

### Player faction

Primary: red.

Suggested uses: - roofs/cloth accents; - banners; - shields; - friendly
markers; - UI accents; - tower identification.

### Enemies

Initial goblins naturally provide green enemy identification.

Enemy UI/markers should reinforce this without requiring every enemy
asset to be monochrome green.

------------------------------------------------------------------------

## 17. Technical Architecture --- Godot

Target engine: Godot.

Keep systems modular.

Suggested high-level structure:

``` text
Game
├── Level
│   ├── Navigation
│   ├── EnemyRoutes
│   ├── BuildPlots
│   ├── SpawnPoints
│   └── Keep
│
├── Hero
│   ├── Movement
│   ├── Targeting
│   ├── Combat
│   ├── Health
│   ├── XP
│   └── Abilities
│
├── Enemies
│   ├── Navigation
│   ├── Targeting
│   ├── Combat
│   ├── Health
│   └── Drops
│
├── Buildings
│   ├── BaseBuilding
│   ├── ArcherTower
│   ├── Wall
│   ├── GoldMine
│   ├── Smith
│   └── Keep
│
├── Systems
│   ├── WaveManager
│   ├── EconomyManager
│   ├── BuildManager
│   ├── UpgradeManager
│   └── RunState
│
└── UI
```

This is guidance, not permission to create unnecessary abstraction. The
Architect may simplify it where appropriate.

------------------------------------------------------------------------

## 18. Data-Driven Requirements

The following should be configurable rather than buried in gameplay
code:

### Hero

-   health;
-   damage;
-   attack speed;
-   movement speed;
-   XP thresholds;
-   ability values;
-   respawn duration.

### Enemies

-   health;
-   speed;
-   damage;
-   coin reward;
-   XP reward eligibility;
-   targeting behavior;
-   resistances/tags.

### Buildings

-   construction cost;
-   upgrade costs;
-   max level;
-   max-per-level;
-   health;
-   attack values;
-   production values;
-   valid plot categories.

### Waves

-   enemy type;
-   count;
-   timing;
-   spawn location;
-   difficulty modifiers.

### Levels

-   available plots;
-   plot types;
-   building limits/overrides;
-   routes;
-   spawn points;
-   Keep position;
-   wave configuration.

Do not overengineer a generic data framework before these values
actually need configuration.

------------------------------------------------------------------------

## 19. Agent Model

The Main Architect is the integration authority.

Suggested specialist responsibilities:

### Hero/Combat Agent

Owns: - movement; - bow combat; - hero targeting; - hero health; - hero
XP; - abilities.

### Enemy/Wave Agent

Owns: - enemy movement; - routes; - spawning; - waves; - enemy
combat/targeting.

### Building/Economy Agent

Owns: - build plots; - construction; - upgrades; - coins; - building
limits; - Smith; - Gold Mine.

### Level Agent

Owns: - map assembly; - route placement; - plot placement; - spawn/Keep
positions; - navigation integration.

### UI/Feedback Agent

Owns: - HUD; - coin feedback; - level-up presentation; - build
selection; - Smith bulbs; - upgrade feedback.

### Art/Asset Agent

Owns: - original simplified art; - red friendly faction language; -
green goblin enemy language; - three visually distinct building
levels; - readability at gameplay camera scale.

Agents must not independently redefine another agent's public interface.

------------------------------------------------------------------------

## 20. Main Architect CONTINUE / HOLD Protocol

Every specialist agent must submit a proposed implementation step before
beginning work when it changes shared architecture, public interfaces,
data formats, or dependencies.

The Main Architect replies with one of:

### CONTINUE

Use when: - dependencies exist; - interfaces are sufficiently defined; -
work does not conflict with another active change; - acceptance criteria
are clear; - scope belongs to the current milestone.

Architect response should include: - approved scope; - relevant
interfaces; - files/systems the agent may modify; - acceptance
criteria; - integration notes.

### HOLD

Use when: - dependency is unfinished; - another agent owns required
interfaces; - design decision is unresolved; - implementation would
cause likely rework; - task is outside the current milestone; - agent
proposes premature abstraction/content.

Architect response should state: - exact reason for HOLD; - blocking
dependency; - what must become true before CONTINUE.

### REVISE

Use when the task is valid but the proposed approach conflicts with
architecture or scope.

Architect specifies what must change before resubmission.

------------------------------------------------------------------------

## 21. Architect Review Rules

The Main Architect should NOT manually review every line of every
isolated implementation if automated tests and ownership boundaries can
validate it.

Architect attention should focus on: - cross-system interfaces; - scene
ownership; - signals/events; - shared resources; - save/run state; -
data schemas; - dependencies; - integration; - scope.

Specialist agents are responsible for local implementation quality and
local tests.

This prevents the Main Architect from becoming a bottleneck.

------------------------------------------------------------------------

## 22. Dependency Order

Preferred first implementation chain:

``` text
Level shell
    ↓
Hero movement
    ↓
Basic bow combat
    ↓
Basic enemy + route
    ↓
Damage / death
    ↓
Wave spawning
    ↓
Coin drops + collection
    ↓
Building plots
    ↓
Archer Tower
    ↓
Wall
    ↓
Building upgrades L1-L3
    ↓
Hero XP + level-up
    ↓
First hero ability
    ↓
Gold Mine
    ↓
Smith + three upgrade bulbs
    ↓
Vertical-slice balancing/polish
```

Parallel work is encouraged when dependencies permit it.

Example: - Art Agent can prototype building silhouettes while combat is
implemented. - UI Agent can build isolated mock components once
interfaces are defined. - Enemy Agent can develop wave data while
Building Agent works on plots.

Do not serialize unrelated work through the Architect unnecessarily.

------------------------------------------------------------------------

## 23. Vertical Slice Acceptance Criteria

The first vertical slice passes only when all of the following are true:

### Gameplay

-   hero movement feels responsive;
-   hero can reliably shoot enemies;
-   enemies traverse the intended route;
-   enemies can threaten the Keep;
-   enemies die and drop coins;
-   hero can collect coins;
-   coins can be spent during active gameplay;
-   construction is fast;
-   buildings function immediately after construction;
-   buildings upgrade to Level 3;
-   every building level has a major visible difference;
-   hero kills grant XP;
-   hero can level up;
-   at least one ability visibly changes combat;
-   Smith can be built where valid;
-   Gold Mine can be built where valid;
-   initial building limits are respected;
-   Smith shows three nearby upgrade bulbs;
-   Smith upgrade selection applies immediately;
-   level has working win/loss conditions.

### Visual/readability

-   player faction reads as red;
-   enemies read as green;
-   buildings are large;
-   enemies remain readable;
-   coin drops are obvious;
-   available plots are obvious;
-   building levels can be distinguished visually;
-   combat remains understandable during a busy wave;
-   map is larger than the camera viewport and requires hero movement.

### Feel

The slice should repeatedly produce this sequence:

**shoot → kill → coins → collect → build → visible power increase →
larger wave → level up → stronger attack → upgrade defenses → survive.**

If this loop is not satisfying, do not solve the problem by adding more
systems.

Fix the core loop first.

------------------------------------------------------------------------

## 24. Explicitly Deferred Systems

Unless the Main Architect changes the milestone, HOLD requests
involving:

-   multiplayer;
-   PvP;
-   large campaign map;
-   advertisements;
-   monetization;
-   premium currencies;
-   equipment inventory;
-   loot rarity;
-   multiple playable heroes;
-   clans/guilds;
-   extensive cosmetics;
-   battle passes;
-   large skill trees;
-   large enemy libraries;
-   procedural generation;
-   online backend;
-   account systems.

These may be designed later after the vertical slice proves the core
game.

------------------------------------------------------------------------

## 25. Scope-Control Principle

Agents must not implement a feature merely because:

> "We will probably need this later."

Implement the smallest architecture that correctly supports the current
milestone while avoiding obvious dead ends.

Future extensibility is valuable.

Premature systems are not.

------------------------------------------------------------------------

## 26. Architect's Immediate Objective

The Main Architect's current mission is:

> Coordinate agents to produce one polished, fast, readable vertical
> slice demonstrating the hero + tower-defense + physical-coin +
> real-time-building + hero-leveling + Smith-upgrade loop.

All CONTINUE/HOLD decisions should be judged against that objective
until the milestone is formally completed.
