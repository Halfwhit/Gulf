# Gulf — Developer Notes

## Project overview

Retro-inspired, top-down, turn-based multiplayer minigolf in Godot 4.
Viewport resolution 640×360, displayed at 1280×800 with integer-scaled
canvas_items.  2D physics runs on a separate thread; gravity is zero.

---

## Critical invariants — do not break these

### 1. Floor tile shape encoding

Each floor tile's atlas row encodes its shape (`atlas_coords.y`), stored
in the **G channel** of the terrain map alongside the terrain_id in R.
All shapes are evaluated on `shape_uv` (rotation-adjusted UV).

| atlas row | shape_id | Name | UV condition (on shape_uv) |
|-----------|----------|------|------|
| 0 | 0 | rect | always inside |
| 1 | 1 | diagonal | `ux+uy > 1` |
| 2 | 2 | curve | `(ux−1)²+(uy−1)² < 1` |
| 3 | 3 | curve_inv | `(ux−1)²+(uy−1)² ≥ 1` |
| 4 | 4 | half | `uy > 0.5` |
| 5 | 5 | diamond | `\|ux−0.5\|+\|uy−0.5\| < 0.5` |
| 6 | 6 | circle | `(ux−0.5)²+(uy−0.5)² < 0.25` |
| 7 | 7 | half_diag | `ux+uy>1 AND uy>0.5` |
| 8 | 8 | half_curve | `(ux−1)²+(uy−1)²<1 AND uy>0.5` |
| 9 | 9 | half_cinv | `(ux−1)²+(uy−1)²≥1 AND uy>0.5` |
| 10 | 10 | petal | all 4 corner arcs intersected |
| 11 | 11 | quarter | `ux>0.5 AND uy>0.5` |
| 12 | 12 | opp_quarters | `(ux>0.5) != (uy>0.5)` |
| 13 | 13 | quarter_diag | `ux+uy>1 AND ux>0.5 AND uy>0.5` |
| 14 | 14 | quarter_curve | `(ux−1)²+(uy−1)²<1 AND ux>0.5 AND uy>0.5` |
| 15 | 15 | quarter_cinv | `(ux−1)²+(uy−1)²≥1 AND ux>0.5 AND uy>0.5` |

Petal (10): intersection of all four unit-radius arcs centred at the
tile corners — `(ux²+uy²)<1 AND ((ux-1)²+uy²)<1 AND (ux²+(uy-1)²)<1 AND ((ux-1)²+(uy-1)²)<1`.

Each source atlas must be 32×512 (16 rows of 32×32 tiles). The actual
pixel content doesn't matter — the terrain_blend shader overrides all
visual appearance. Rotation is stored in the TileMap alternative_tile
value (bits 0-1) and re-applied to shape_uv in the shader.

`_write_terrain_pixel(cell, terrain_id, shape_id, rot, bg)` encodes:
- R = terrain_id / 255.0          (1–6 or 0=empty)
- G = shape_id   / 255.0          (0–3)
- B = (rot | (bg << 2)) / 255.0   bits 0-1 = rotation (0-3), bits 2-7 = background terrain_id (0-6)
- A = 1.0 if occupied, 0.0 if empty

`bg` is the terrain_id of whatever tile was at this cell before a shaped tile
was painted on top. The shader renders `get_fill(bg)` for void pixels (the area
of the cell not covered by the shape). Workflow: paint Fairway rects first, then
paint shaped tiles on top — Fairway becomes the void fill automatically.
`bg = 0` means no background (void remains transparent/discarded).

The shader reads rotation from B to compute `shape_uv` (the UV in the
tile's local rotated space) used for `shape_inside` and the shape
boundary blend.  Edge distances (`d_l`/`d_r`/`d_t`/`d_b`) use the
unrotated `tile_uv` because they measure distance to the cell boundary
in world space, which is independent of the tile's rotation.

`_rebuild_terrain_map()` reads `atlas_coords.y` for shape and
`get_cell_alternative_tile` + `_ROT_ALT.find()` for rotation.

---

### 2. Terrain ID ordering and tilesheet layout

`terrain_id = atlas_coords.x + 1`.  The floor tileset now has a **single
TileSetAtlasSource** (source_id = 0) backed by `tileset_floor.png`
(224×512 = 7 columns × 16 rows, 32×32 per cell).

| atlas column | terrain_id | Name     |
|-------------|-----------|----------|
| 0           | 1         | Fairway  |
| 1           | 2         | Green    |
| 2           | 3         | LightMud |
| 3           | 4         | DarkMud  |
| 4           | 5         | Water    |
| 5           | 6         | Acid     |
| 6           | 7         | Wall     |

atlas row = shape_id (0–15), same as before.

`tileset_floor.png` is generated from two source assets:
- `terrain_colors.png` (224×32, 7 columns): terrain colour swatches
- `terrain_shapes.png` (32×512, 16 rows): shape masks (white/transparent)

**Higher ID = higher visual priority.**  Fairway (1) never draws a border.
Wall (7) draws borders toward everything.

Walls are **floor-layer terrain** — no separate WallMap.

`set_cell` always uses `source_id=0` and `atlas_coords = (fg_source_id, shape)`.
`_rebuild_terrain_map` reads `terrain_id = atlas_coords.x + 1`.

If you add a terrain: add a column to `tileset_floor.png`, update
`terrain_colors.png`, `TERRAIN_NAMES`/`TERRAIN_COLORS` in editor_ui.gd,
`fill_N`/`outline_N` in the shader, and re-register `N:row/0 = 0` entries
in `tileset_floor.tres`.

### 2. Tileset source ordering in tileset_floor.tres

Godot's TileSetAtlasSource editor caches a reference keyed by source_id.
**Never change the `sources/N` → `SubResource("srcN")` dictionary.**
Reordering sources must be done by swapping the *contents* (texture +
resource_name) inside the sub-resources, not by remapping the dictionary
keys — the engine will assert if the source object at a given key changes.

### 3. Per-tile UV must be derived from world position, not the UV built-in

Godot's `UV` in a `canvas_item` shader is **atlas-space** (0→1 over the full
atlas texture height), not per-tile.  For a 32×512 atlas (16 tile rows), `UV.y`
for a tile at row 1 spans 0.0625→0.125, not 0→1.  Shape-clipping and edge-blend
formulas all require per-tile [0,1] UV.

The shader derives it from the world-position varying instead:

```glsl
vec2 tile_uv = fract(v_world / tile_px + 0.5);
```

### 6. Use MODEL_MATRIX to get world position from VERTEX

Godot 4's `TileMapLayer` batches tiles into **rendering quadrant** canvas items.
Each quadrant canvas item has its own local transform (offset to the quadrant's
world-space origin).  `VERTEX` in a `canvas_item` shader is in the canvas item's
**local space**, not world space.

For tile (-3, -1) in quadrant (-1, -1) (world origin (-512, -512)), `VERTEX`
is ≈ (416, 480) (local within the quadrant), not the world position (-96, -32).
Using `v_world = VERTEX` would make the terrain-map cell lookup compute
cell (13, 15) instead of (-3, -1) — the cell is empty → `discard` → tile
appears invisible.

Fix: multiply by `MODEL_MATRIX` in the vertex shader:

```glsl
void vertex() {
    v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
```

`MODEL_MATRIX` is the canvas item's world transform; multiplying converts
local → world space, giving the correct world position for terrain_map lookup.

### 4. Terrain map texture uniforms must be vec2, not ivec2

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

Godot's `local_to_map` uses **top-left convention**: `floor(world / tile_px)`.
Cell (cx, cy) spans `(cx*32 … cx*32+32)` in world space; the tile top-left is
at `(cx*32, cy*32)`.

The shader mirrors this exactly — **no +0.5**:

```glsl
ivec2 cell    = ivec2(floor(v_world / tile_px));
vec2  tile_uv = fract(v_world / tile_px);
```

Adding +0.5 to either formula shifts the UV origin to the tile centre (0.5),
making the right and bottom halves of every tile look up the wrong (empty)
terrain_map pixel and discard — rendering only a quarter of each tile.

The +0.5 in `me_uv` and `lookup`'s `uv` is different: it's **texel-centre
sampling** inside the 256×256 terrain_map and must stay.

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
2. **Rect tiles (shape 0)**: 1 px cardinal cell-edge blend + corner pixel logic.
   No fill drawn; outline colour only at `d < 1.0` from the cell boundary.
3. **Shaped tiles (shape 1–3)**: two kinds of border —
   - **Void side of geometric edge**: 1 px of own outline along the arc/diagonal,
     drawn in the void branch (before shape_inside check).
   - **Fill-side cell edges**: same 1 px cell-edge rule as rect tiles (blend_edge
     toward any lower-ID neighbour at d < 1.0).  Safe because the fill never
     reaches the void-facing cell edges for any shape/rotation, so those calls
     are harmless no-ops.
   - shape 1 (diagonal): `d_shape = (shape_uv.x + shape_uv.y − 1) × tile_px × 0.7071`;
     void threshold `d_shape > −0.5` picks exactly the boundary pixel per step.
   - shape 2 (curve): `d_shape = (1 − r) × tile_px` (negative in void, r > 1);
     threshold `d_shape > −1.0` covers the 1-px ring just outside the arc.
   - shape 3 (curve_inv): same `d_shape` formula but void is the **inner** corner (r < 1),
     so `d_shape > 0` everywhere in the void.  Threshold `d_shape < 1.0` (within 1px
     of the arc from inside) — NOT `> −1.0` which would flood the entire corner.
4. Void (id = −1): never draws, never receives a band.

---

## Level editor patterns

- `_NO_CELL = Vector2i(-32768, -32768)` is the sentinel for "no cell
  painted/erased this stroke".  Reset at the start of each mouse-down.
- `_ROT_ALT[steps]` maps the rotation dial (0–3) to the
  `TileSetAtlasSource.TRANSFORM_*` bitfield for wall/entity/shaped-floor
  tiles.  Plain rect floor tiles always use alternative 0 (no transform).
  Mapping matches Godot's clockwise rotation convention (Y-down):
  - 0 → 0 (no transform)
  - 1 → TRANSPOSE|FLIP_V  (90° CW:  bottom-right → lower-left)
  - 2 → FLIP_H|FLIP_V     (180°:    bottom-right → upper-left)
  - 3 → TRANSPOSE|FLIP_H  (270° CW: bottom-right → upper-right)
  Note: TRANSPOSE|FLIP_H and TRANSPOSE|FLIP_V are swapped from what
  you might expect — verified empirically against the Sprite2D cursor.
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
