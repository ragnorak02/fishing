# Isles of the Blue Current — Project Intelligence

## Project Overview
- **Engine:** Godot 4.6 (GL Compatibility renderer)
- **Genre:** 2D fishing adventure, Okinawa-inspired
- **Viewport:** 1280x720, stretch mode `canvas_items`
- **Godot path:** `Z:/Godot/Godot_v4.6-stable_win64.exe`

## Architecture

### Scene-per-Mode Pattern
| Scene | Path | Purpose |
|-------|------|---------|
| MainMenu | `scenes/main_menu/MainMenu.tscn` | Title screen with wave animation |
| HubTown | `scenes/hub_town/HubTown.tscn` | Harbor: NPCs, sell, upgrade |
| OceanSurface | `scenes/ocean_surface/OceanSurface.tscn` | Open-sea vehicle gameplay + dive spots |
| DiveScene | `scenes/dive_scene/DiveScene.tscn` | Underwater: fish, harpoon, O2 |
| HaulSummary | `scenes/haul_summary/HaulSummary.tscn` | Catch review, sell/keep UI |
| SceneTransition | `scenes/transitions/SceneTransition.tscn` | Fade overlay (autoload) |

### Autoloads (project.godot singletons)
- **GameManager** — state machine, vehicle mode, upgrade multipliers, scene transitions
- **Inventory** — gold, haul array, sell/keep logic
- **AudioManager** — **STUB** (Phase 1 placeholder, no audio yet)
- **SceneTransition** — fade-in/out animation
- **ControlsOverlay** — context-sensitive input hints

### Static Classes (class_name, NOT autoloads)
- **FishDatabase** — lazy-loads 10 .tres fish species, weighted random by biome
- **FishSpecies** — custom Resource (weight, rarity, sushi-grade, biome, value)
- **EconomySystem** — fish value calculation with bonuses
- **UpgradeSystem** — 6 tracks x 3 levels, costs, static getters/setters

### Vehicle System (`scripts/vehicle/`)
- **VehicleController** — CharacterBody2D, owns all subsystems
- **VehicleStateMachine** — Mode enum (SURFACE, SUBMERGED, AIR), animated transforms
- **States:** SurfaceState (complete), SubmergedState (complete), AirState (stub)
- **Systems:** BatterySystem, DepthSystem, DurabilitySystem, SonarSystem, MountedHarpoon

### Key Conventions
- All collision shapes are set up programmatically in `_ready()` (not in .tscn)
- Placeholder visuals created programmatically when no texture is assigned
- NPC interaction: body_entered signal → parent HubTown methods
- Scene transitions: `GameManager.transition_to()` with debounce flag
- Fish spawning: FishSpawner creates CharacterBody2D with FishAI + metadata
- UI: CanvasLayer for screen-space, world-space Labels for in-game markers

### Physics Layers
| Layer | Name |
|-------|------|
| 1 | environment |
| 2 | player |
| 3 | fish |
| 4 | harpoon |
| 5 | interaction |

### Input Actions
`move_up/down/left/right` (WASD + arrows + gamepad), `interact` (E), `boost` (Shift),
`fire_harpoon` (LMB), `transform_vehicle` (R), `cast_line` (F), `ascend` (E),
`descend` (Q), `sonar_pulse` (Space), `pause` (Esc)

## Current Repo State (Auto-Detected)

- **Phase 1 core loop complete:** Hub → Sail → Dive → Catch → Haul → Sell → Upgrade → Repeat
- **AudioManager is a stub** — 3 empty methods, marked "Phase 1 stub" (no .ogg/.wav/.mp3 files exist)
- **AirState is a stub** — pushes warning and falls back to SurfaceState immediately
- **All 23 SVG assets are placeholders** — every sprite has a programmatic ColorRect fallback
- **No test files exist** — no `tests/` directory, no `*test*.gd`, no CI/CD
- **No README.md** — only CREDITS.md exists (fonts and audio marked TBD)
- **Zero TODO/FIXME comments** in codebase — clean code discipline
- **DiveScene._on_harpoon_missed()** is a `pass` stub (comment: "Could add miss feedback")
- **No secrets or credentials found** — clean security posture
- **75 tracked files:** 36 .gd, 6 .tscn, 10 .tres, 23 .svg, 2 .gdshader, 2 config, 1 .md
- **Achievement system:** 15 achievements defined in `achievements.json` (infrastructure only, no unlock logic yet)

## Achievement System
- **Data:** `achievements.json` — 15 achievements, 490 total points
- **Contract:** `achievements_integration.md` — menu tab, unlock flow, toast spec
- **Dashboard:** `status.html` loads achievements.json and renders progress + recent unlocks
- **Safe update rules:** append-only, never reset unlocked, always recalculate meta totals
- **Implementation:** No `AchievementManager` autoload exists yet — contract only

## Workflow Commands
- **"Where are we?"** → Read `status.html` for visual dashboard, or check this section
- **"Please commit everything"** → Triggers hardened checkpoint (secret scan → stage → commit → push)
- See `git_workflow.md` for full checkpoint protocol
