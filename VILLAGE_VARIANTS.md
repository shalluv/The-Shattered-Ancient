# Village Room Variants Documentation

## Overview
Village rooms are special encounter rooms where players can rescue neutral villagers and convert them into units. Each variant offers unique challenges and mechanics.

---

## Variant 1: The Divided Village (`VillageDivided`)

### Concept
A village split by a central damage zone (lava). Players must navigate around hazards to rescue villagers on both sides.

### Layout
- **Player Spawn**: Bottom center (512, 700)
- **Damage Zone**: Central horizontal lava strip
- **Buildings**: Scattered throughout safe zones

### Enemies
- **DirePriest** x1 (converts villagers, conversion aura)
- **StationaryGuard** x5 (melee, patrol behavior)
- Guards patrol in 40px radius around spawn point
- Aggro radius: 100px

### Villagers
- **Top Section**: 2 villagers (mix of Neutral/Archer/Mage)
- **Bottom Section**: 2 villagers (mix of Neutral/Archer/Mage)

### Clear Condition
Kill all enemies (standard)

---

## Variant 2: The Contested Crossroads (`VillageContested`)

### Concept
DirePriests are actively converting villagers. Players must eliminate priests before villagers are lost.

### Layout
- **Player Spawn**: Bottom center (512, 700)
- **Slow Zone**: Central area
- **Buildings**: Strategic cover positions

### Enemies
- **DirePriest** x3 (converts villagers, conversion aura)
- **StationaryGuard** x4 (melee, patrol near priests/chokepoints)
- **DireGrunt** x2 (aggressive)

### Villagers
- **Left side**: 4 villagers (1 Archer, 3 Neutral)
- **Right side**: 4 villagers (1 Archer, 3 Neutral)
- **Total**: 8 villagers at risk of conversion by priests

### Clear Condition
Kill all enemies (standard)

### Special Mechanic
- Priests have conversion aura
- Villagers in aura slowly convert to enemies
- Priority: Kill priests first

---

## Variant 3: The Gauntlet Village (`VillageGauntlet`)

### Concept
A layered defense with enemies in three tiers. Villagers are protected in a safe zone at the top.

### Layout
- **Player Spawn**: Bottom center (512, 700)
- **Layer 1**: First line of defense (closest to player)
- **Layer 2**: Middle defense
- **Layer 3**: Final defense before villager zone
- **Safe Zone**: Top area with villagers

### Enemies
- **Layer 1**: DireGrunts x2
- **Layer 2**: StationaryGuards x2
- **Layer 3**: StationaryGuards x2
- **Entrance Guards**: StationaryGuards x2
- **Center**: DirePriest x1 (converts villagers)
- **Total**: 9 enemies

### Villagers
- 6 villagers in safe zone (Mage, Priest, 2 Archers, 2 Neutrals)

### Clear Condition
Kill all enemies (standard)

### Special Features
- Horizontal walls create chokepoints
- Guards at villager entrance for final defense

---

## Variant 4: The Caravan Escort (`VillageCaravan`)

### Concept
Escort a moving caravan carrying villagers to safety. Enemies specifically target the caravan while others attack player units.

### Layout
- **Player Spawn**: Bottom center (512, 700)
- **Caravan Start**: Left side (100, 350)
- **Caravan Exit**: Right side (924, 350)
- **Buildings**: Along the route for cover
- **Spawn Zones**: 4 designated areas (not near start/end)

### Enemy System
**Continuous Spawns** with random offsets:
- **CaravanHunterMelee**: Every 15s (+0-2s delay) - Targets caravan only
- **CaravanHunterRanged**: Every 25s (+0-3s delay) - Targets caravan only  
- **DireGrunt (Melee)**: Every 14s (+0-2.5s delay) - Targets player units
- **DireGruntRanged**: Every 30s (+0-4s delay) - Targets player units

### Enemy Types
| Type | HP | Speed | Target | Special |
|------|----|-------|--------|---------|
| CaravanHunterMelee | 2 | 85 | Caravan | Melee only |
| CaravanHunterRanged | 1 | 40 | Caravan | Ranged attack |
| DireGrunt (Melee) | 1 | 40 | Player | Standard melee |
| DireGruntRanged | 1 | 40 | Player | Ranged attack |

### Caravan Mechanics
- **Villagers Onboard**: 6 villagers
- **HP per Villager**: 3 hits per villager
- **Movement**: 40 speed, automatic path following
- **Stun**: 1.5s when hit
- **Game Over**: All villagers die

### Clear Condition
**Caravan reaches exit** (NOT enemy kills)

### Rewards
- **Unit Rewards**: Each surviving villager = 1 random new unit
- **Unit Types**: Swordsman, Archer, Mage, Priest (random)
- **Immediate**: Units spawn ready-to-use at exit

### HUD Display
- **During Mission**: "Escort the Caravan" (gold text)
- **Success**: "CLEARED" (gold text)

### Strategy Tips
- Split forces: Some protect caravan, some fight grunts
- Caravan hunters ignore player units - focus them
- Use buildings for cover against ranged enemies
- Priority: Eliminate DirePriests first to prevent villager conversion

---

## Variant 5: The Sacrificial Altar (`VillageSacrifice`)

### Concept
Villagers are bound to altars with sacrifice timers. Players must defeat guards and rescue villagers before time runs out.

### Layout
- **Player Spawn**: Bottom center (512, 700)
- **Altar 1**: Top center (512, 200)
- **Altar 2**: Left (250, 400)
- **Altar 3**: Right (774, 400)
- **Damage Zone**: Center-bottom area (512, 480)

### Enemies
- **Per Altar**: 1 StationaryGuard (melee) + 1 RangedGuard (ranged)
- **Aggressive**: DireGrunts x2 (initial wave)
- **Total**: 8 enemies

### Guard Types
| Type | Color | Speed | Behavior |
|------|-------|-------|----------|
| StationaryGuard | Brown-red (#5a3a3a) | 80 | Melee, patrol 40px radius |
| RangedGuard | Purple (#4a3a5a) | 25 | Ranged attack, retreat if close |

### Villagers
- 3 villagers bound to altars (Priest, Mage, Mage)
- **Bound State**: Cannot move until rescued

### Sacrifice Mechanic
- **Timer**: 30 seconds per villager
- **Visual**: Red countdown above villager
- **Warning**: Timer turns bright red at <5 seconds
- **Death**: Villager dies when timer reaches 0

### Rescue Mechanic
- **Radius**: 50px from villager
- **Time**: 2 seconds of standing near
- **Visual**: Green progress bar below villager
- **Result**: Villager unbound and can move freely

### Clear Condition
Kill all enemies (standard)

### Strategy
- Balance between killing guards and rescuing villagers
- Prioritize villagers with lowest timers
- RangedGuards can harass from distance

---

## Enemy Reference

### StationaryGuard (Melee)
- **HP**: 2
- **Speed**: 80 (same as DireGrunt)
- **Damage**: 1
- **Aggro Radius**: 100px
- **Patrol Radius**: 40px
- **Behavior**: Patrol until player enters aggro range, then chase

### RangedGuard (Ranged)
- **HP**: 1
- **Speed**: 25
- **Damage**: 1 (projectile)
- **Aggro Radius**: 150px
- **Attack Range**: 140px
- **Attack Cooldown**: 2 seconds
- **Retreat Distance**: 80px (runs away if player too close)
- **Patrol Radius**: 30px
- **Projectile**: Purple, 150 speed

---

## NPC Behavior Notes

### Danger Zone Avoidance
- NPCs avoid walking into damage zones (lava)
- NPCs avoid walking through altars
- If spawned in danger zone, NPCs escape automatically
- Pathfinding weight for damage zones: 100 (very high)

### Bound Villagers
- Cannot move while `is_bound = true`
- Must be rescued to become mobile
- Still vulnerable to damage while bound

---

## Difficulty Scaling

Village rooms scale difficulty based on the current row in the run.

### Difficulty Tiers

| Tier | Rows | Extra Enemies | Extra Priests | Timer Reduction | Spawn Rate |
|------|------|---------------|---------------|-----------------|------------|
| **Early** | 1-2 | +0 | +0 | 0s | 1.0x |
| **Mid** | 3-5 | +2 | +1 | -5s | 0.85x (faster) |
| **Late** | 6+ | +4 | +1 | -8s | 0.7x (faster) |

### Scaling Effects per Variant

| Variant | Extra Enemies | Extra Priests | Timer | Spawn Rate |
|---------|---------------|---------------|-------|------------|
| **Divided** | ✓ StationaryGuards | ✓ DirePriests | - | - |
| **Contested** | ✓ StationaryGuards | ✓ DirePriests | - | - |
| **Gauntlet** | ✓ StationaryGuards | ✓ DirePriests | - | - |
| **Sacrifice** | ✓ StationaryGuards | - | ✓ Sacrifice timer reduced | - |
| **Caravan** | - | - | - | ✓ Enemies spawn faster |

---

## File Locations

| Variant | Script | Scene |
|---------|--------|-------|
| Divided | `VillageDivided.gd` | `VillageDivided.tscn` |
| Contested | `VillageContested.gd` | `VillageContested.tscn` |
| Gauntlet | `VillageGauntlet.gd` | `VillageGauntlet.tscn` |
| Caravan | `VillageCaravan.gd` | `VillageCaravan.tscn` |
| Sacrifice | `VillageSacrifice.gd` | `VillageSacrifice.tscn` |

All located in `scenes/dungeon/`
