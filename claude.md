# ISLES OF THE BLUE CURRENT
AMARIS Development Specification

Engine: Godot 4.6  
Platform: PC  
Renderer: 2D (GL Compatibility)  
Genre: Fishing Adventure  
Studio: AMARIS  
Controller Required: Yes (Xbox + Keyboard)

---

# AMARIS Studio Rules (Non-Negotiable)

- project_status.json is the single source of truth.
- CLAUDE.md defines structure and checkpoints only.
- Dashboard reads JSON only.
- Do NOT duplicate completion percentages here.
- All major systems must be testable.
- Debug flags default false.
- Never delete checklist items — mark N/A if unused.

Launcher Contract:
- game.config.json must remain valid.
- testCommand must execute without manual steps.
- ISO8601 minute precision timestamps.

---

# Godot Execution Contract (MANDATORY)

Godot installed at:

Z:/godot

Claude MUST use:

Z:/godot/godot.exe

Never assume PATH.
Never use local Downloads path.
Never reinstall engine.

Headless boot:
Z:/godot/godot.exe --path . --headless --quit-after 1

Headless test runner:
Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn

If adding new class_name scripts:
Z:/godot/godot.exe --path . --headless --import

---

# Project Overview

Okinawa-inspired 2D fishing adventure.

Core Loop:

Hub Town  
→ Sail Ocean  
→ Dive  
→ Catch  
→ Surface  
→ Haul Summary  
→ Sell / Keep  
→ Upgrade  
→ Repeat  

Core Pillars:
- Exploration
- Real-time fish hunting
- Upgrade-driven progression
- Transforming vehicle modes

---

# Architecture Summary

Scene-per-mode pattern:

MainMenu  
HubTown  
OceanSurface  
DiveScene  
HaulSummary  

Autoloads:
GameManager  
Inventory  
AudioManager (stub)  
SceneTransition  
ControlsOverlay  

Static Systems:
FishDatabase  
EconomySystem  
UpgradeSystem  

Vehicle Modes:
Surface (complete)  
Submerged (complete)  
Air (stub)

---

# Structured Development Checklist
AMARIS STANDARD — 85 Checkpoints

---

## Macro Phase 1 — Foundation (1–10)

- [x] 1. Repo standardized
- [x] 2. Scene-per-mode architecture
- [x] 3. VehicleStateMachine implemented
- [x] 4. Surface mode functional
- [x] 5. Submerged mode functional
- [ ] 6. Air mode implemented
- [x] 7. Inventory gold system
- [x] 8. UpgradeSystem implemented
- [ ] 9. Version visible in UI
- [ ] 10. Logging standardization

---

## Macro Phase 2 — Core Gameplay Loop (11–20)

- [x] 11. Hub → Ocean transition
- [x] 12. Dive spot detection
- [x] 13. FishSpawner system
- [x] 14. FishAI behavior
- [x] 15. Harpoon firing system
- [x] 16. Catch logic
- [x] 17. Haul summary screen
- [x] 18. Sell / Keep logic
- [x] 19. Upgrade purchase logic
- [ ] 20. Harpoon miss feedback

---

## Macro Phase 3 — Fish & Economy Systems (21–30)

- [x] 21. 10 fish species loaded
- [x] 22. Biome-weighted spawning
- [x] 23. Sushi-grade tagging
- [x] 24. Legendary rarity tier
- [x] 25. EconomySystem value calculation
- [x] 26. Species discovery tracking
- [x] 27. Fish encyclopedia UI
- [x] 28. Dynamic fish scaling
- [x] 29. Market fluctuation system
- [x] 30. Special event fish

---

## Macro Phase 4 — Achievements (31–45)

Source: achievements.json

IDs:
first_catch  
catch_10  
catch_50  
sushi_grade  
catch_legendary  
all_species  
first_sale  
earn_500_gold  
earn_2000_gold  
first_upgrade  
max_upgrade_track  
all_upgrades_max  
first_dive  
first_transform  
sonar_pulse  

- [x] 31. first_catch hook
- [x] 32. catch_10 tracking
- [x] 33. catch_50 tracking
- [x] 34. sushi_grade hook
- [x] 35. catch_legendary hook
- [x] 36. all_species tracking
- [x] 37. first_sale hook
- [x] 38. earn_500_gold tracking
- [x] 39. earn_2000_gold tracking
- [x] 40. first_upgrade hook
- [x] 41. max_upgrade_track hook
- [x] 42. all_upgrades_max hook
- [x] 43. first_dive hook
- [x] 44. first_transform hook
- [ ] 45. sonar_pulse hook

Toast queue required.
Never reset unlocked flags.

---

## Macro Phase 5 — Save & Persistence (46–55)

- [x] 46. Save system implemented
- [x] 47. Continue menu condition
- [x] 48. Gold persistence
- [x] 49. Upgrade persistence
- [x] 50. Species caught persistence
- [x] 51. Achievement persistence
- [x] 52. Save migration support
- [x] 53. Auto-save after haul
- [x] 54. Load validation test
- [x] 55. Save corruption handling

---

## Macro Phase 6 — Audio & Atmosphere (56–65)

- [ ] 56. AudioManager implemented
- [ ] 57. Surface music
- [ ] 58. Dive ambience
- [ ] 59. Catch SFX
- [ ] 60. Upgrade SFX
- [ ] 61. Sonar pulse SFX
- [ ] 62. Weather ambience
- [ ] 63. Particle polish pass
- [ ] 64. Real art asset swap
- [ ] 65. Final VFX polish

---

## Macro Phase 7 — Expansion Systems (66–75)

- [ ] 66. Air vehicle mode
- [ ] 67. New islands
- [ ] 68. Weather system
- [ ] 69. Quest system
- [ ] 70. Story NPCs
- [ ] 71. Multiplayer architecture draft
- [ ] 72. Deep-sea biome
- [ ] 73. Rare event system
- [ ] 74. Time-of-day cycle
- [ ] 75. Boss fish encounter

---

## Macro Phase 8 — Testing & Automation (76–85)

- [x] 76. Test runner implemented
- [x] 77. test_results.json contract
- [x] 78. Catch logic regression tests
- [x] 79. Economy regression tests
- [x] 80. Upgrade regression tests
- [ ] 81. Achievement regression tests
- [ ] 82. Save/load regression tests
- [ ] 83. Performance baseline
- [ ] 84. Launcher compliance verified
- [ ] 85. Release candidate checklist

---

# Debug Flags

Must exist:

- DEBUG_VEHICLE
- DEBUG_FISH
- DEBUG_ECONOMY
- DEBUG_UPGRADES
- DEBUG_ACHIEVEMENTS

All default false.

---

# Automation Contract

After major updates:

1. Update project_status.json:
   - macroPhase
   - subphaseIndex
   - completionPercent
   - timestamps
   - testStatus

2. Run headless boot:
Z:/godot/godot.exe --path . --headless --quit-after 1

3. Run test suite (when implemented).
4. Commit.
5. Push.

Launcher depends on this.

---

# Current Focus

Current Goal:
Current Task:
Work Mode:
Next Milestone:

---

# Known Gaps

- AchievementManager not implemented
- No Save system
- AudioManager stub
- Air vehicle mode stub
- Harpoon miss feedback missing
- Debug flags (DEBUG_VEHICLE, etc.) not defined in codebase
- No version display in game UI
- Species discovery tracking not implemented
- Fish encyclopedia UI not implemented

---

# Long-Term Vision

Isles of the Blue Current should evolve into:

- Multi-region ocean world
- Rare dynamic weather
- Legendary boss fish hunts
- Fully atmospheric Okinawa-inspired audio/visual experience
- Expedition system
- Upgrade mastery progression

---

END OF FILE