# Isles of the Blue Current — Game Direction

## Concept
An Okinawa-inspired 2D fishing adventure. Players captain a transforming vehicle
(boat / submarine / future aircraft) across island waters — sailing, diving,
harpooning fish, selling catches, and upgrading their rig.

## Core Loop
```
Hub Town → Sail Ocean → Dive Underwater → Catch Fish → Surface → Haul Summary → Sell/Keep → Upgrade → Repeat
```

## Pillars
1. **Exploration** — open-water sailing with discoverable dive spots
2. **Hunting** — real-time harpoon fishing with fish AI behaviors
3. **Progression** — 6 upgrade tracks that change gameplay feel
4. **Atmosphere** — Okinawan-inspired island world (art + audio TBD)

## Progression System
| Track | Effect | Levels |
|-------|--------|--------|
| Boat Speed | Surface/sub movement speed | 3 |
| Oxygen | Dive duration | 3 |
| Harpoon Range | Projectile distance | 3 |
| Durability | Hull hit points | 3 |
| Battery | Submersion time | 3 |
| Sonar | Detection range | 3 |

## Fish Roster (10 species)
| Fish | Rarity | Biome | Sushi-Grade |
|------|--------|-------|-------------|
| Sardine | common | coastal | No |
| Mackerel | common | coastal | No |
| Sea Bream | uncommon | coastal | Yes |
| Squid | common | deep | No |
| Octopus | uncommon | deep | No |
| Yellowtail | uncommon | open | Yes |
| Grouper | rare | deep | Yes |
| Bluefin Tuna | rare | open | Yes |
| Manta Ray | legendary | deep | No |
| Golden Koi | legendary | coastal | Yes |

## Vehicle Modes
- **Surface (boat)** — fast travel, discover dive spots, cast line
- **Submerged (sub)** — slower, battery-limited, sonar + harpoon + depth control
- **Air (future)** — not yet implemented, reserved for Phase 3+

## Phase Roadmap

### Phase 1 — Core Loop (COMPLETE)
- All 6 scenes functional
- Vehicle state machine with surface + submerged
- 10 fish species with FishAI
- Economy: sell/keep, gold, upgrades
- Placeholder SVG art with programmatic fallbacks

### Phase 2 — Polish & Content (NEXT)
- Audio system (music + SFX)
- Real art assets replacing SVG placeholders
- Harpoon miss feedback
- More fish species and biomes
- Save/load system
- Particle effects and juice

### Phase 3 — Expansion (FUTURE)
- Air vehicle mode
- New islands / regions
- Story / quest system
- Weather system
- Multiplayer considerations
