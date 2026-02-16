# Isles of the Blue Current — Test Plan

## Current Status
**No automated tests exist yet.** This document defines the testing strategy
to be implemented incrementally alongside feature work.

## Testing Approach
Godot 4.6 does not ship a built-in test framework. Recommended options:
- **GdUnit4** — GDScript unit/integration test framework (most mature)
- **Manual smoke tests** — checklist below for pre-commit validation

---

## Manual Smoke Test Checklist

Run through this before major commits:

### Scene Flow
- [ ] MainMenu → "Start" → HubTown loads
- [ ] HubTown: walk to dock NPC → dialogue appears
- [ ] HubTown: walk to fishmonger → sell UI works (with fish in inventory)
- [ ] HubTown: walk to upgrade NPC → upgrade panel opens, purchase works
- [ ] HubTown: walk to dock → OceanSurface loads

### Ocean Surface
- [ ] Vehicle spawns, WASD movement works
- [ ] Boost (Shift) increases speed
- [ ] Dive spots visible, interact (E) near one → DiveScene loads
- [ ] Transform (R) → vehicle submerges with animation
- [ ] Submerged: battery drains, depth control (Q/E) works
- [ ] Submerged: sonar pulse (Space) fires, costs battery
- [ ] Submerged: harpoon (LMB) fires
- [ ] Surface when battery empty or press R again
- [ ] Durability: collision reduces hull HP
- [ ] Return to hub (sail to edge or designated exit)

### Dive Scene
- [ ] Diver spawns, O2 bar visible and draining
- [ ] Fish spawn and exhibit AI behavior (swim patterns)
- [ ] Harpoon fires on LMB, hits fish → catch registered
- [ ] O2 depletes → forced surface, HaulSummary loads
- [ ] Manual surface (move to top) → HaulSummary loads

### Haul Summary
- [ ] Caught fish displayed with names, weights, values
- [ ] Sell/Keep buttons work per fish
- [ ] "Sell All" / "Continue" work
- [ ] Gold updates in Inventory
- [ ] Returns to HubTown

### Upgrades
- [ ] Each of 6 tracks shows current level and cost
- [ ] Purchase deducts gold, level increments
- [ ] Max level (3) disables purchase button
- [ ] Multipliers apply in gameplay (e.g., faster boat after speed upgrade)

### Edge Cases
- [ ] Rapid scene transitions don't crash (debounce works)
- [ ] Pause (Esc) pauses game, unpause resumes
- [ ] No errors in Godot console during full loop

---

## Automated Test Plan (Future)

### Unit Tests (GdUnit4)
| Module | Tests |
|--------|-------|
| EconomySystem | fish value calc, sushi-grade bonus, weight scaling |
| FishDatabase | all 10 species load, weighted random distribution |
| UpgradeSystem | level progression, cost lookup, max level cap |
| Inventory | add/remove fish, gold math, haul clear |
| BatterySystem | drain rate, sonar cost, recharge, empty signal |
| DepthSystem | ascend/descend bounds, buoyancy drift |
| DurabilitySystem | damage calc, destroy signal at 0 HP |
| OxygenSystem | drain rate, refill, depleted signal |

### Integration Tests
| Flow | Validates |
|------|-----------|
| Full game loop | Hub → Ocean → Dive → Haul → Hub without crash |
| Upgrade application | Purchasing upgrade changes gameplay multiplier |
| Vehicle transform | Surface ↔ Submerged state transitions |
| Economy round-trip | Catch fish → sell → gold increases correctly |

### Performance Tests
- Fish spawning with 20+ fish on screen
- Scene transitions under 500ms
- No memory leaks across 10 full loops
