# The Shattered Ancient — Game Document

## Game Overview

**The Shattered Ancient** is a 2D top-down action roguelite built in Godot 4 (GDScript).

You play as the **Radiant Ancient** — a shattered god reduced to a glowing ore fragment. Instead of controlling a single hero, you command a **living swarm** of units using RTS-style controls. Your unit count is your health: lose all units and the run ends, kill enemies to absorb new ones.

**Genre:** Action Roguelite + RTS Hybrid
**Inspirations:** Hades, Vampire Survivors, Thronefall, Dota 2

---

## How to Play

### Objective
Lead your swarm through a 10-room procedural dungeon. Survive combat encounters, recruit neutral units, collect hero boons, and defeat the final boss. Your army persists between rooms — every unit matters.

### Controls

| Input | Action |
|-------|--------|
| Left-click + drag | Draw selection box to select units |
| Left-click (no drag) | Select single unit / deselect all |
| Shift + left-click | Add to current selection |
| Double-click | Select all units of that type |
| Right-click | Move selected units to position (ring formation) |
| Ctrl + 1-9 | Save current selection as control group |
| 1-9 | Recall saved control group |

### Core Loop
1. **Draft your army** — spend a budget to pick Swordsmen, Archers, Priests, and Mages
2. **Enter the dungeon** — navigate a branching 10-room map
3. **Fight through rooms** — clear enemies to unlock doors and progress
4. **Recruit neutrals** — use Priests to convert wandering villagers into your swarm
5. **Choose boons** — after hero encounters, pick powerful boons that buff your army
6. **Beat the boss** — reach room 10 and defeat the Dire Ancient
7. **Earn shards** — spend Radiant Ore Shards on permanent meta upgrades between runs

---

## Unit Types

### Swordsman
- **Role:** Melee frontline
- **Cost:** 3 budget points
- **Color:** Gold (#FFD700)
- Chases nearest enemy and attacks in melee range. Your bread-and-butter unit.

### Archer
- **Role:** Ranged damage
- **Cost:** 4 budget points
- **Color:** Gold (#FFD700)
- **Attack Range:** 180px
- **Attack Cooldown:** 1.5s
- Fires projectile arrows at enemies from a distance. Supports frost arrows (slow on hit) and multishot (1-3 projectiles with pierce) through boons.

### Priest
- **Role:** Support / Recruitment
- **Cost:** 5 budget points
- **Color:** Gold (#FFD700)
- **Aura Radius:** 50px (base, expandable with upgrades)
- Does not attack. Emits a glowing gold aura that converts nearby neutral units into your swarm (4-second conversion timer). The only way to recruit neutrals.

### Mage
- **Role:** Ranged damage
- **Cost:** 6 budget points
- **Color:** Gold (#FFD700)
- **Attack Cooldown:** 1.8s
- Fires magic projectiles. Benefits from Arcane Surge synergy for bonus damage.

### Champion (Hero Unit)
- **Role:** Powerful unique unit from hero encounters
- **Color:** Hero-specific
- Spawned when you defeat a hero boss and choose their boon. Each champion has unique abilities tied to their hero (Juggernaut, Crystal Maiden, Drow Ranger, Omniknight).

---

## Enemy Types

### Dire Grunt
- Basic melee enemy. Low threat individually, dangerous in groups.

### Dire Captain
- Stronger variant of the grunt. More HP and damage.

### Dire Hound
- Fast-moving melee enemy. Rushes your backline.

### Dire Priest
- Enemy support unit with a red/purple conversion aura. Can steal neutral units before you recruit them. Creates a race to convert neutrals.

### Spearwall
- Organized formation enemies. Multiple units that fight as a coordinated group.

### Hero Bosses
Special boss enemies encountered in Hero rooms:
- **Juggernaut** — Melee, 2 damage, 5 HP
- **Crystal Maiden** — Ranged, 1 damage, 160 range, 5 HP
- **Drow Ranger** — Ranged, 1 damage, 200 range, 5 HP (meta unlock required)
- **Omniknight** — Melee, 2 damage, 8 HP (meta unlock required)

### Dire Ancient (Final Boss)
- The ultimate boss at the end of the dungeon.

---

## Systems

### Unit Count = Health
There is no HP bar. Your **unit count IS your health**:
- Taking damage = units are removed from your swarm
- Killing enemies = 30% chance to absorb a new unit (particles spiral from enemy into swarm)
- Run ends when unit count hits 0

### Neutral Recruitment
Neutral villagers wander randomly in villages and camps. They ignore all combat and factions.
- **Only Priests can recruit them** — no other method exists
- When a neutral enters a Priest's aura, their wandering biases inward (they tend to stay)
- After **4 seconds** inside the aura, the neutral converts: color lerps from grey to gold, joins your army
- Gold particle burst on conversion
- Dire Priests compete for the same neutrals with their own aura

### Synergies
Synergies activate automatically when you have enough of a unit type:

| Synergy | Requirement | Effect |
|---------|-------------|--------|
| **Volley Mode** | 3+ Archers | All archers fire synchronized volleys every 3 seconds |
| **Holy Shield** | 2+ Priests | Priests grant 1-charge shields to nearby units |
| **Arcane Surge** | 2+ Mages | Mages deal 1.4x damage |

### Hero Boon System
After defeating a hero boss, you choose from **3 random boons**. Each boon has **2 upgrade variants** that can appear in later offerings. 4 heroes provide 30+ total boon options:

**Juggernaut Boons:**
- Blade Fury — spinning area damage
- Healing Ward — periodically revives fallen swordsmen
- Omnislash — rapid multi-target strike

**Crystal Maiden Boons:**
- Frost Aura — slows nearby enemies
- Crystal Nova — periodic AoE burst
- Arcane Aura — buffs mage damage/speed

**Drow Ranger Boons:** *(requires meta unlock)*
- Precision Aura — increases archer range/damage
- Frost Arrows — arrows slow on hit
- Multishot — archers fire multiple projectiles

**Omniknight Boons:** *(requires meta unlock)*
- Purification — periodic healing burst
- Guardian Angel — spawn emergency units when swarm hits 0
- Degen Aura — slows and damages nearby enemies

### Map & Room Progression
Each run generates a **10-row procedural map**:
- **Row 0:** Starting room (always column 1)
- **Rows 1-2, 4-6, 8:** Combat rooms, villages, shops (branching paths)
- **Rows 3 & 7:** Miniboss encounters (funnel — all columns connect)
- **Row 9:** Final boss (funnel)

**Room Types:**
| Type | Description |
|------|-------------|
| Combat (Small) | 5 randomized combat variations |
| Combat (Medium) | Larger battles, may include villages with neutrals |
| Miniboss | Stronger enemy encounters with rewards |
| Hero Encounter | Fight a hero boss, choose a boon |
| Shop | Spend gold on buffs |
| Boss | Final Dire Ancient fight |

Between rooms, you choose your path on the map screen — different branches offer different room types.

### Army Draft
Before each run, you spend a **budget** (base 20, up to 30 with upgrades) to assemble your starting army:

| Unit | Cost |
|------|------|
| Swordsman | 3 |
| Archer | 4 |
| Priest | 5 (requires meta unlock) |
| Mage | 6 (requires meta unlock) |

### Shop Buffs
Shop rooms offer purchasable buffs for the current run:
- **Sharpened Blades** — melee damage boost
- **Enchanted Quiver** — ranged damage boost
- **Battle Standard** — army-wide buff

### Terrain Zones
Rooms can contain hazardous terrain:
- **Damage Zones** — deal damage to units that enter
- **Slow Zones** — reduce movement speed of units inside
- Both affect pathfinding weight (units prefer to avoid them when possible)

### Meta Progression
**Radiant Ore Shards** persist between runs and are earned by:
- Clearing a room: +2 shards
- Clearing without losing units: +1 bonus shard
- Beating the boss: +10 shards
- Beating the boss without losses: +3 bonus shards

**Upgrades (11 total):**

| Upgrade | Cost | Effect |
|---------|------|--------|
| Unlock Priest | 10 | Priest available in draft |
| Unlock Mage | 15 | Mage available in draft |
| Budget +5 | 20 | Draft budget increases to 25 |
| Budget +10 | 30 | Draft budget increases to 30 |
| Unlock Drow Ranger | 15 | Drow hero encounters + boons |
| Unlock Omniknight | 15 | Omniknight hero encounters + boons |
| Unlock Shop | 20 | Shop rooms appear on the map |
| Veteran Swordsmen | 10 | Swordsmen get +1 HP |
| Eagle Archers | 10 | Archers get +30 range |
| Holy Presence | 15 | Priest aura radius +30px |

Progress is saved to disk (JSON) and persists across sessions.

### Pathfinding
All units and enemies use **A* grid-based pathfinding** (AStarGrid2D):
- 16px cell size
- Walls marked as obstructions
- Doors can be opened/closed dynamically
- Damage and slow zones add weight to cells (units route around them when possible)
- Line-of-sight optimization with path smoothing
- Paths recalculated every 0.3 seconds

---

## Visual Style

All graphics are **colored rectangles** (ColorRect / Polygon2D) — no external sprites or imported assets.

### Color Palette

| Element | Color | Hex |
|---------|-------|-----|
| Player swarm units | Gold | #FFD700 |
| Enemies | Dark Red | #8B0000 |
| Radiant Ore core | Bright White-Gold | #FFFACD |
| Neutral villagers | Grey | #808080 |
| Walls | Dark Green | #1a2e1a |
| Floor | Very Dark Green | #0d1a0d |
| Converting units | Grey fading to Gold | lerp #808080 → #FFD700 |

### Particle Effects (GPUParticles2D)
Every major moment has a particle effect:

| Moment | Effect |
|--------|--------|
| Swarm movement | Subtle gold dust trail |
| Unit death | Burst of unit-color particles |
| Enemy death | Red particle burst |
| Enemy absorption | Particles spiral from enemy into swarm core |
| Right-click destination | Small sparkle at click point |
| Room cleared | Gold burst from all surviving units |
| Priest aura | Glowing ring with glitter particles |
| Boon activation | Hero-specific particle effects |
| Neutral conversion | Gold particle burst |

---

## Technical Architecture

### Autoloads (Global Singletons)
| Autoload | Purpose |
|----------|---------|
| SwarmManager | Swarm state, unit tracking, synergy thresholds, absorption |
| SelectionManager | RTS input: box select, control groups, move commands |
| RunManager | Run progression, map generation, room data, gold, shop buffs |
| MetaProgress | Persistent save data, shards, upgrades, unlock tracking |
| BoonManager | Hero boon application, 30+ boon effects with timers |
| Pathfinder | A* grid pathfinding, wall/door/zone management |
| SynergyManager | Synergy activation/deactivation, volley timers, shields |
| SceneTransition | Fade-to-black scene changes |

### Physics Collision Layers
| Layer | Name | Used By |
|-------|------|---------|
| 1 | swarm_units | Player unit CharacterBody2D |
| 2 | enemies | Enemy CharacterBody2D |
| 3 | swarm_core | SwarmCore (disabled) |
| 4 | walls | Wall StaticBody2D |
