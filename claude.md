# GLOBAL RULES (AMATRIS)

This project inherits the AMATRIS studio rules.

Non-negotiable:
- Claude must run the implementation-verification skill before declaring completion.
- Claude must provide verification proof output.
- Claude must confirm the working directory before modifying files.
- If a Godot scene changes, Claude must print the node tree and key node positions.
- Claude may not claim completion without verification output.

If there is any conflict between local rules and global rules, **global rules win**.

---

# Mandatory Verification Protocol

Claude must run the **implementation-verification skill** before declaring completion of any task involving:

- code changes
- scene changes
- UI changes
- system modifications
- gameplay systems
- signals or input systems

Claude **may not report completion** until verification output is printed.

### Required Proof

Verification output must include:

• scene node tree  
• scripts attached to nodes  
• signal connections  
• interaction confirmation  

If a **Godot scene is modified**, Claude must print the node tree using:

- Godot CLI inspection  
- scene structure inspection  

Completion **without verification output is invalid**.

---

# Implementation Protocol

Before implementing any feature Claude must:

1. Explain the architecture change
2. List files that will be modified
3. Implement the change
4. Run verification
5. Print verification output

Claude must **not silently modify large systems without explanation**.

---

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

- `project_status.json` is the **single source of truth**
- `CLAUDE.md` defines **structure and checkpoints only**
- Dashboard reads **JSON only**
- Do **NOT duplicate completion percentages** here
- All major systems **must be testable**
- Debug flags **default false**
- Never delete checklist items — mark **N/A** if unused

---

# Launcher Contract

Launcher integration must remain valid.

- `game.config.json` must remain valid
- `testCommand` must execute without manual steps
- ISO8601 **minute precision timestamps**

---

# Godot Execution Contract (MANDATORY)

Godot installed at: Z:/godot  
Claude MUST use: Z:/godot/godot.exe

Rules:

- Never assume PATH
- Never use local Downloads path
- Never reinstall the engine

---

## Headless Boot

Z:/godot/godot.exe --path . --headless --quit-after 1

---

## Headless Test Runner

Z:/godot/godot.exe --path . --headless --scene res://tests/test_runner.tscn

---

## Script Registration

If adding new `class_name` scripts:

Z:/godot/godot.exe --path . --headless --import

---

# Project Overview

Okinawa-inspired 2D fishing adventure.

---

## Core Gameplay Loop

Hub Town  
→ Sail Ocean  
→ Dive  
→ Catch Fish  
→ Surface  
→ Haul Summary  
→ Sell / Keep Catch  
→ Upgrade Equipment  
→ Repeat

---

## Core Pillars

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
AudioManager (wired — awaiting audio assets)  
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
- [x] 6. Air mode implemented
- [x] 7. Inventory gold system
- [x] 8. UpgradeSystem implemented
- [x] 9. Version visible in UI
- [x] 10. Logging standardization

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
- [x] 20. Harpoon miss feedback

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
- [x] 45. sonar_pulse hook

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

- [x] 56. AudioManager implemented
- [ ] 57. Surface music (play_music wired in OceanSurface — needs .ogg asset)
- [ ] 58. Dive ambience (play_music wired in DiveScene — needs .ogg asset)
- [x] 59. Catch SFX (play_sfx wired in DiveScene — needs .ogg asset)
- [x] 60. Upgrade SFX (play_sfx wired in UpgradeUI — needs .ogg asset)
- [x] 61. Sonar pulse SFX (play_sfx wired in OceanSurface — needs .ogg asset)
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

Current Goal: Phase 6 — Audio & Atmosphere  
Current Task: Wire AudioManager SFX calls into gameplay scenes  
Work Mode: Feature Development  
Next Milestone: Phase 6 complete

---

# Known Gaps

- Audio .ogg assets not yet supplied (all play_sfx/play_music calls wired, silently no-op until files exist)
- Harpoon miss feedback missing

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