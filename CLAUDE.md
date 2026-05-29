# Gulf — Developer Notes

## Project overview

Retro-inspired, top-down, turn-based multiplayer minigolf in Godot 4.
Viewport resolution 640×360, displayed at 1280×800 with integer-scaled
canvas_items.  2D physics runs on a separate thread; gravity is zero.

---

## Critical invariants — do not break these

### 1. Floor tile shape encoding

Each floor tile's atlas row encodes its shape (`atlas_coords.y`), stored
in the **G channel** of the terrain map alongside the terrain_id in R:

| atlas row | shape_id | Name | UV condition |
|-----------|----------|------|------|
| 0 | 0 | rect | always inside |
| 1 | 1 | diagonal | `UV.x + UV.y > 1` |
| 2 | 2 | curve | `(UV.x−1)² + (UV.y−1)² < 1` |
| 3 | 3 | curve_inv | complement of curve |

Shapes 1–3 share arc endpoints at the two opposite tile corners, so they
tile cleanly together. Godot's alternative_tile transform (TRANSPOSE /
FLIP flags) pre-rotates the UV before the fragment shader runs — the
shader formula works for all four orientations without any UV remapping.

`_write_terrain_pixel(cell, terrain_id, shape_id)` encodes:
- R = terrain_id / 255.0 (1–6 or 0=empty)
- G = shape_id  / 255.0 (0–3)
- A = 1.0 if occupied, 0.0 if empty

**Never store rotation in the G channel.** The tile's alternative_tile
already encodes it. `_rebuild_terrain_map()` reads `atlas_coords.y` for
the shape and ignores the alternative.

---

### 2. Terrain ID ordering

`terrain_id = source_id + 1`.  IDs are assigned in this exact order:

| source_id | terrain_id | Name     |
|-----------|-----------|----------|
| 0         | 1         | Fairway  |
| 1         | 2         | Green    |
| 2         | 3         | LightMud |
| 3         | 4         | DarkMud  |
| 4         | 5         | Water    |
| 5         | 6         | Acid     |

**Higher ID = higher visual priority.**  A tile draws its own border
(on itself) toward any lower-ID neighbour.  Fairway (1) never draws a
border.  `terrain_blend.gdshader` uses `me > nb` for all blend decisions.

If you add a terrain, append a new source at the **end** of
`tileset_floor.tres` so existing IDs are unchanged, and add the
corresponding `fill_N` / `outline_N` uniforms to the shader.

### 2. Tileset source ordering in tileset_floor.tres

Godot's TileSetAtlasSource editor caches a reference keyed by source_id.
**Never change the `sources/N` → `SubResource("srcN")` dictionary.**
Reordering sources must be done by swapping the *contents* (texture +
resource_name) inside the sub-resources, not by remapping the dictionary
keys — the engine will assert if the source object at a given key changes.

### 3. Terrain map texture uniforms must be vec2, not ivec2

Godot silently mis-converts a `Vector2i` passed to an `ivec2` uniform,
producing garbage cell coordinates.  `map_origin` and `map_dims` are
declared as `vec2` in the shader, and the GDScript side passes `Vector2`.

### 4. Physics layer assignments

Configured in `project.godot` → `[layer_names]`:

| Layer | Name   | Used for                        |
|-------|--------|---------------------------------|
| 1     | ball   | Player ball RigidBody2D         |
| 2     | solid  | Wall tiles (collide with balls) |
| 3     | hole   | Hole trigger area               |
| 4     | water  | Water terrain trigger           |
| 5     | acid   | Acid terrain trigger            |

Floor tile physics layers (for terrain effects) will be added per
TileSetAtlasSource; the terrain priority order above determines which
layer a tile belongs to.

### 5. Cell coordinate formula in the shader

`map_to_local()` returns the **centre** of a cell, so cell (cx, cy) spans
`(cx*32−16 … cx*32+16)` in world space.  The inverse used in the shader is:

```glsl
ivec2 cell = ivec2(floor(v_world / tile_px + 0.5));
```

This matches Godot's `local_to_map()`.  Do not change to
`floor(v_world / tile_px)` — that breaks on the left/top half of each
tile.

---

## File responsibilities

| File | Role |
|------|------|
| `scenes/main.gd` | Entry point; spawns TestLevel or LevelEditor |
| `scenes/level_editor.gd` | Level editor controller; owns terrain map, painting/erasing |
| `scenes/editor_ui.gd` | Sidebar tile palette; emits `tile_selected` / `tile_cleared` |
| `scripts/tile_button.gd` | `TileButton` class — toggleable texture button for tile palette |
| `scripts/player.gd` | Ball physics, hit-line aiming, `turn_taken` signal |
| `scenes/TurnController.gd` | Round-robins `play_turn()` across child Player nodes |
| `scenes/cursor.gd` | Cursor sprite that follows snapped grid position |
| `shaders/terrain_blend.gdshader` | All terrain transitions; reads 256×256 terrain_map texture |
| `resources/tileset_floor.tres` | 6-source floor tileset, one 32×32 tile per terrain |
| `resources/tileset_walls.tres` | Wall tile atlas (straight, curve, diagonal, inverted-curve) |
| `resources/tileset_entities.tres` | Entity tiles (hole, start, etc.) |

---

## Terrain shader — blend rule summary

1. Higher-ID tile draws toward lower-ID neighbour.
2. Cardinal band: 1 px of neighbour's fill + 1 px of own outline (2 px total).
3. Corner pixel: only filled when **both** adjacent cardinal edges are also
   drawing — prevents isolated floating pixels at diagonal-only adjacencies.
4. Void (id = −1): never draws, never receives a band.

---

## Level editor patterns

- `_NO_CELL = Vector2i(-32768, -32768)` is the sentinel for "no cell
  painted/erased this stroke".  Reset at the start of each mouse-down.
- `_ROT_ALT[steps]` maps the rotation dial (0–3) to the
  `TileSetAtlasSource.TRANSFORM_*` bitfield for wall/entity tiles.
  Floor tiles always use alternative 0 (no transform).
- `_write_terrain_pixel(cell, 0)` clears a pixel (alpha 0); any non-zero
  terrain_id sets alpha 1.  The shader uses `s.a > 0.5` to detect
  occupied cells.
- `_flush_terrain()` is the single place that calls
  `ImageTexture.update()` and resets `_terrain_dirty`.

---

## Physics notes

- `2d/default_gravity = 0` — top-down, no gravity.
- `2d/default_linear_damp = 1.0` — baseline rolling resistance.
- Player ball uses `move_and_collide` in `_physics_process`; per-frame
  friction is `velocity = velocity.lerp(ZERO, FRICTION * delta)`.
- Ball-to-ball collision halves both velocities and bounces off the
  contact normal.
