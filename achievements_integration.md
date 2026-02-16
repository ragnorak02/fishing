# Achievement System — Integration Contract

## Overview

This document defines how the achievement system integrates with the game.
It is a **contract only** — engine-specific implementation is left to gameplay code.

---

## Data Source

- **File:** `achievements.json` (project root)
- **Format:** JSON, schema defined below
- **Runtime access:** Load at startup, write back on change
- **Godot path:** `res://achievements.json` (use `FileAccess` for read/write)

## Achievement Schema

```json
{
  "id": "string_id",
  "name": "Human Readable Name",
  "description": "Short description of unlock condition",
  "points": 10,
  "icon": "relative/path/to/icon.svg",
  "unlocked": false,
  "unlockedAt": null
}
```

- `id` — unique snake_case identifier, never reused
- `points` — positive integer, immutable after creation
- `unlocked` — boolean, only ever transitions `false → true`
- `unlockedAt` — ISO 8601 timestamp when unlocked, or `null`

---

## Menu Integration

### Recommended Menu Tab

| Property | Value |
|----------|-------|
| Label | **Achievements** |
| Location | Main Menu, alongside Start / Settings |
| Shortcut | Also accessible via HubTown NPC or pause menu |

### Menu Panel Behavior

1. Load `achievements.json` on open
2. Display all achievements in a scrollable list
3. Each row shows: icon, name, description, points, lock/unlock state
4. Unlocked achievements display the unlock date
5. Locked achievements show grayed-out icon and "???" or description
6. Header shows: total points earned / total points possible, progress bar
7. Sort order: unlocked first (most recent at top), then locked by point value ascending

### Recommended Godot Implementation Notes

- Create an `AchievementManager` autoload (singleton)
- On `_ready()`: load `achievements.json` via `FileAccess`
- Expose `unlock(id: String)` method that:
  - Finds achievement by id
  - Sets `unlocked = true`, `unlockedAt = ISO timestamp`
  - Updates `meta.totalPointsEarned`
  - Updates `meta.lastUpdated`
  - Emits signal `achievement_unlocked(achievement_data)`
  - Writes file back to disk
- Expose `is_unlocked(id: String) -> bool` for gameplay checks
- Expose `get_all() -> Array` for menu display

---

## Unlock Flow

```
Gameplay event occurs (e.g., fish caught)
    │
    ▼
Game logic calls AchievementManager.unlock("first_catch")
    │
    ▼
AchievementManager checks: already unlocked?
    │
    ├── Yes → no-op, return
    │
    └── No → set unlocked=true, unlockedAt=now
              update meta.totalPointsEarned
              emit achievement_unlocked signal
              save achievements.json to disk
              │
              ▼
        Toast overlay displays notification
```

### Trigger Points (suggested, not implemented)

| Achievement | Trigger Location |
|-------------|-----------------|
| `first_catch` | `DiveScene` — on fish caught signal |
| `catch_10`, `catch_50` | `DiveScene` — check cumulative count after catch |
| `sushi_grade` | `DiveScene` — check `FishSpecies.sushi_grade` on catch |
| `catch_legendary` | `DiveScene` — check `FishSpecies.rarity == "legendary"` |
| `all_species` | `HaulSummary` or `Inventory` — check species set completeness |
| `first_sale` | `HaulSummary` — on sell action |
| `earn_500_gold`, `earn_2000_gold` | `Inventory` — check cumulative gold earned |
| `first_upgrade` | `UpgradeSystem` — on purchase |
| `max_upgrade_track` | `UpgradeSystem` — check if any track == max level |
| `all_upgrades_max` | `UpgradeSystem` — check all 6 tracks == max level |
| `first_dive` | `DiveScene._ready()` — on first entry |
| `first_transform` | `VehicleStateMachine` — on first `mode_changed` signal |
| `sonar_pulse` | `SonarSystem` — on first pulse fired |

---

## Overlay Toast Specification

When an achievement unlocks, the game must display a transient notification.

### Visual Layout

```
┌──────────────────────────────────┐
│  [icon]  Achievement Unlocked!   │
│          First Bite              │
│          +10 pts                 │
└──────────────────────────────────┘
```

### Properties

| Property | Value |
|----------|-------|
| Position | Top-center of screen, offset ~80px from top edge |
| Width | 320px (scales on mobile) |
| Background | Semi-transparent dark panel (`Color(0.1, 0.15, 0.2, 0.92)`) |
| Border | 1px accent color (`#00d2ff`) with 8px border radius |
| Icon size | 48x48, left-aligned |
| Title line | "Achievement Unlocked!" — small, dim, uppercase |
| Name line | Achievement name — bold, white |
| Points line | "+{points} pts" — accent color |
| Animation | Slide in from top (0.3s ease-out), hold 3s, fade out (0.5s) |
| Layer | CanvasLayer with high z-index (above all game UI) |
| Queue | If multiple unlock simultaneously, show sequentially (0.5s gap) |
| Audio | Play unlock SFX via AudioManager (when implemented) |

### Godot Implementation Notes

- Use a `CanvasLayer` (z_index = 100) with a `PanelContainer`
- Connect to `AchievementManager.achievement_unlocked` signal
- Tween-based animation: `create_tween()` for slide + fade
- Auto-dismiss via `get_tree().create_timer(3.0)`
- Queue system: Array of pending toasts, process one at a time

---

## Safe Update Rules

These rules apply whenever achievements are modified (by developers or tools):

1. **Only append** new achievements — never remove or reorder existing ones
2. **Never reset** `unlocked` from `true` back to `false`
3. **Never clear** `unlockedAt` timestamps
4. **Never change** `id` of an existing achievement
5. **Never change** `points` of an existing achievement (affects earned totals)
6. **Always recalculate** `meta.totalPointsEarned` from actual unlocked achievements
7. **Always update** `meta.totalPointsPossible` when adding new achievements
8. **Always update** `meta.lastUpdated` to current ISO timestamp
9. **Validate** unique `id` values before writing — reject duplicates
