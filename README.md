# Gulf

A retro-inspired, top-down, turn-based multiplayer minigolf game built in Godot 4.

---

## Overview

Gulf is a pixel-art minigolf game designed for local multiplayer.  Courses
are built on a square tile grid using the built-in level editor, and players
take turns aiming and hitting a ball toward the hole.  The visual style uses
a fixed 640×360 viewport rendered at 1280×800 with integer-scaled
canvas_items.

---

## Features

### Working
- **Ball physics** — RigidBody2D-based ball with a pull-back aiming line,
  bounce off walls, and friction-based deceleration
- **Ball-to-ball collision** — balls exchange momentum on impact
- **Turn-based multiplayer** — `TurnController` round-robins `play_turn()`
  across any number of players; the next player's turn begins when the
  previous ball comes to rest
- **Level editor** — in-game editor with a tile picker sidebar, cursor
  preview, rotation dial (R key cycles 0°/90°/180°/270°), and separate
  layer tabs for floor, walls, and entities
- **Terrain shader** — GPU-side terrain blending via a canvas_item GLSL
  shader; all transitions are computed at runtime from a 256×256
  terrain-map texture rather than pre-baked atlas tiles
- **Wall tiles** — straight, curved, diagonal, and inverted-curve shapes;
  walls rotate freely; Fairway floor is auto-placed underneath a wall
  when the cell is empty
- **Entity tiles** — start position and hole markers

### Planned
- Hole detection and scoring
- Lobby / player count selection
- Gulps game mode
- Physics-layer terrain effects (slow on mud, hazard on water/acid)
- Save / load levels

---

## Project structure

```
Gulf/
├── scenes/
│   ├── main.tscn / main.gd        — entry point; launches editor or test level
│   ├── level_editor.tscn / .gd    — in-game level editor
│   ├── editor_ui.tscn / .gd       — tile-palette sidebar
│   ├── TestLevel.tscn / .gd       — physics test scene
│   ├── player.tscn                — player ball node
│   ├── TurnController.gd          — round-robin turn management
│   └── cursor.gd                  — snapped grid cursor
├── scripts/
│   ├── player.gd                  — ball physics, aiming, turn signal
│   └── tile_button.gd             — TileButton class (toggleable palette button)
├── shaders/
│   └── terrain_blend.gdshader     — terrain transition shader
├── resources/
│   ├── tileset_floor.tres         — 6-source floor tileset (one tile per terrain)
│   ├── tileset_walls.tres         — wall tile atlas
│   └── tileset_entities.tres      — entity tile atlas
└── assets/
    ├── terrain_*.png              — solid-colour 32×32 terrain tiles
    ├── wall_*.png                 — wall tile sprites
    ├── ball.png / hole.png        — gameplay sprites
    └── palette.aseprite           — source art file
```

---

## Terrain system

Each floor terrain is a single 32×32 solid-colour tile.  All border and
transition rendering is handled entirely by `terrain_blend.gdshader`
applied to the `FloorMap` TileMapLayer.

### How it works

`level_editor.gd` maintains a 256×256 RGBA8 **terrain map** image:
one pixel per cell, where the red channel encodes the terrain ID (1–6)
and alpha indicates whether the cell is occupied.  The shader reads this
texture each frame to look up the 8 neighbours of each fragment's cell
and draws transition bands accordingly.

### Terrain priority (low → high)

| ID | Terrain  | Notes |
|----|----------|-------|
| 1  | Fairway  | Base terrain — never draws borders toward anything |
| 2  | Green    | Rough — draws border toward Fairway |
| 3  | LightMud | Soft hazard |
| 4  | DarkMud  | Heavy mud |
| 5  | Water    | Hazard — draws border toward everything below |
| 6  | Acid     | Highest-priority hazard |

A tile draws its own border (on itself, not on its neighbour) toward
tiles of **lower** priority only.  This gives exactly one transition
band per boundary.  Fairway (ID 1) never draws a border — it is the
background terrain.

**Border style:** 1 px of the lower terrain's fill colour + 1 px of own
outline = 2 px band tight against the tile edge.

---

## Physics layers

| Layer | Name   | Purpose |
|-------|--------|---------|
| 1     | ball   | Player ball RigidBody2D |
| 2     | solid  | Wall tile collision shapes |
| 3     | hole   | Hole trigger area |
| 4     | water  | Water terrain trigger (planned: hazard) |
| 5     | acid   | Acid terrain trigger (planned: damage) |

Physics runs on a separate thread.  Gravity is zero (top-down view);
default linear damp is 1.0.

---

## Controls

| Input | Action |
|-------|--------|
| Left click (in game) | Aim and shoot |
| Left click (in editor) | Paint tile |
| Right click (in editor) | Erase tile |
| R (in editor) | Rotate selected tile (wall/entity layers only) |

---

## Running the project

Open in **Godot 4.6+** and press F5.  The main menu offers:
- **Test physics** — loads a pre-built test level
- **Level editor** — opens the in-game tile editor on a blank canvas
