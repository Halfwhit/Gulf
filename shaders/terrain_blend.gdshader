shader_type canvas_item;

// ── Terrain map ───────────────────────────────────────────────────────────────
// 256×256 RGBA8 texture, one pixel per cell.
// R = terrain_id (1-7), G = shape_id (0-15), B = rot|(bg<<2), A = occupied.
// terrain_id = atlas_coords.x + 1  (column in tileset_floor.png)
// shape_id   = atlas_coords.y      (row    in tileset_floor.png)
// Empty / out-of-bounds cells return -1 (no border drawn towards void).
//
// Terrain IDs: 1=Fairway  2=Green  3=LightMud  4=DarkMud  5=Water  6=Acid  7=Wall
//
// Shape IDs:
//  0=rect         1=diagonal     2=curve        3=curve_inv
//  4=half         5=diamond      6=circle       7=half_diag
//  8=half_curve   9=half_cinv   10=petal       11=quarter
// 12=opp_quarters 13=quarter_diag 14=quarter_curve 15=quarter_cinv
uniform sampler2D terrain_map : filter_nearest, repeat_disable;
uniform vec2  map_origin = vec2(-128.0, -128.0);
uniform vec2  map_dims   = vec2(256.0, 256.0);
uniform float tile_px    = 32.0;
// World units per canvas pixel = 1/camera_zoom.  Must be kept in sync by
// level_editor.gd so borders land on exact canvas-pixel boundaries.
// Default 2.0 matches the editor's initial zoom of 0.5 (32-px tiles at 16 px).
uniform float pixel_size = 2.0;

// ── Fill / outline colours (1-based) ─────────────────────────────────────────
uniform vec3 fill_1    = vec3(0.220, 0.718, 0.392);   // Fairway
uniform vec3 fill_2    = vec3(0.655, 0.941, 0.439);   // Green
uniform vec3 fill_3    = vec3(0.706, 0.549, 0.314);   // LightMud
uniform vec3 fill_4    = vec3(0.471, 0.353, 0.196);   // DarkMud
uniform vec3 fill_5    = vec3(0.439, 0.702, 0.941);   // Water
uniform vec3 fill_6    = vec3(0.941, 0.922, 0.439);   // Acid
uniform vec3 fill_7    = vec3(0.353, 0.333, 0.314);   // Wall

uniform vec3 outline_1 = vec3(0.145, 0.443, 0.475);   // Fairway
uniform vec3 outline_2 = vec3(0.145, 0.443, 0.475);   // Green  (intentionally same as Fairway)
uniform vec3 outline_3 = vec3(0.310, 0.235, 0.118);   // LightMud
uniform vec3 outline_4 = vec3(0.200, 0.157, 0.078);   // DarkMud
uniform vec3 outline_5 = vec3(0.145, 0.318, 0.475);   // Water
uniform vec3 outline_6 = vec3(0.475, 0.463, 0.145);   // Acid
uniform vec3 outline_7 = vec3(0.118, 0.110, 0.102);   // Wall

// ── World-position varying ────────────────────────────────────────────────────
// TileMapLayer batches tiles into quadrant canvas items.  Each quadrant
// canvas item has its own local transform (offset to the quadrant's world
// origin), so VERTEX is in quadrant-local space, NOT world space.
// MODEL_MATRIX is the canvas item's world transform, so multiplying gives
// the true world position needed for the terrain_map cell lookup.
varying vec2 v_world;

void vertex() {
    v_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

vec3 get_fill(int id) {
    if (id == 1) return fill_1;
    if (id == 2) return fill_2;
    if (id == 3) return fill_3;
    if (id == 4) return fill_4;
    if (id == 5) return fill_5;
    if (id == 6) return fill_6;
    if (id == 7) return fill_7;
    return fill_1;
}

vec3 get_outline(int id) {
    if (id == 1) return outline_1;
    if (id == 2) return outline_2;
    if (id == 3) return outline_3;
    if (id == 4) return outline_4;
    if (id == 5) return outline_5;
    if (id == 6) return outline_6;
    if (id == 7) return outline_7;
    return outline_1;
}

// Applies tile rotation to a UV in [0,1]².
// Must stay in sync with _rotated_uv() in editor_ui.gd.
vec2 rotate_uv(vec2 uv, int rot) {
    if (rot == 1) return vec2(uv.y,       1.0 - uv.x);
    if (rot == 2) return vec2(1.0 - uv.x, 1.0 - uv.y);
    if (rot == 3) return vec2(1.0 - uv.y, uv.x);
    return uv;
}

// ── Shape clipping ────────────────────────────────────────────────────────────
// All shapes evaluated on shape_uv (rotation-adjusted UV, [0,1] per tile).
// Corner-arc helpers use the bottom-right corner (1,1) as origin — shapes 0-3.
// Compound shapes clip simple shapes with axis-aligned half-planes.
//
//  0 rect          always
//  1 diagonal      ux+uy > 1
//  2 curve         (ux-1)²+(uy-1)² < 1
//  3 curve_inv     (ux-1)²+(uy-1)² >= 1
//  4 half          uy > 0.5
//  5 diamond       |ux-0.5|+|uy-0.5| < 0.5
//  6 circle        (ux-0.5)²+(uy-0.5)² < 0.25
//  7 half_diag     diag AND half
//  8 half_curve    curve AND half
//  9 half_cinv     cinv AND half
// 10 petal         all 4 corner arcs (radius 1 each) intersected
// 11 quarter       ux>0.5 AND uy>0.5
// 12 opp_quarters  (ux>0.5) != (uy>0.5)
// 13 quarter_diag  diag AND quarter
// 14 quarter_curve curve AND quarter
// 15 quarter_cinv  cinv AND quarter
// Must stay in sync with _shape_inside() in editor_ui.gd.
bool shape_inside(vec2 uv, int shape) {
    if (shape == 0) return true;
    float cx = uv.x - 1.0;
    float cy = uv.y - 1.0;
    float d2 = cx * cx + cy * cy;
    if (shape == 1)  return uv.x + uv.y >= 1.0;
    if (shape == 2)  return d2 < 1.0;
    if (shape == 3)  return d2 >= 1.0;
    if (shape == 4)  return uv.y > 0.5;
    if (shape == 5)  return abs(uv.x - 0.5) + abs(uv.y - 0.5) <= 0.5;
    float mx = uv.x - 0.5; float my = uv.y - 0.5;
    if (shape == 6)  return mx * mx + my * my < 0.25;
    if (shape == 7)  return uv.x + uv.y >= 1.0 && uv.y > 0.5;
    if (shape == 8)  return d2 < 1.0 && uv.y > 0.5;
    if (shape == 9)  return d2 >= 1.0 && uv.y > 0.5;
    if (shape == 10) {
        float a = uv.x * uv.x + uv.y * uv.y;
        float b = cx * cx + uv.y * uv.y;
        float c = uv.x * uv.x + cy * cy;
        return a < 1.0 && b < 1.0 && c < 1.0 && d2 < 1.0;
    }
    if (shape == 11) return uv.x > 0.5 && uv.y > 0.5;
    if (shape == 12) return (uv.x > 0.5) != (uv.y > 0.5);
    if (shape == 13) return uv.x + uv.y >= 1.0 && uv.x > 0.5 && uv.y > 0.5;
    if (shape == 14) return d2 < 1.0 && uv.x > 0.5 && uv.y > 0.5;
    if (shape == 15) return d2 >= 1.0 && uv.x > 0.5 && uv.y > 0.5;
    return true;
}

// Returns the raw fg terrain ID of cell c (ignores shape / bg).
int cell_raw(ivec2 c) {
    vec2 tc = vec2(c) - map_origin;
    if (tc.x < 0.0 || tc.y < 0.0 || tc.x >= map_dims.x || tc.y >= map_dims.y) return -1;
    vec4 s = texture(terrain_map, (tc + 0.5) / map_dims);
    if (s.a <= 0.5) return -1;
    return int(round(s.r * 255.0));
}

// ── Neighbour lookup ──────────────────────────────────────────────────────────
// Returns the VISUAL terrain at position edge_uv of cell c.
// For rect cells this is simply the fg terrain.  For shaped cells it returns fg
// or bg depending on whether edge_uv lands inside the fill or void region,
// accounting for the cell's rotation.  Returns -1 for empty / out-of-bounds.
int edge_terrain(ivec2 c, vec2 edge_uv) {
    vec2 tc = vec2(c) - map_origin;
    if (tc.x < 0.0 || tc.y < 0.0 || tc.x >= map_dims.x || tc.y >= map_dims.y)
        return -1;
    vec4 s = texture(terrain_map, (tc + 0.5) / map_dims);
    if (s.a <= 0.5) return -1;
    int raw   = int(round(s.r * 255.0));
    int shape = int(round(s.g * 255.0));
    if (shape == 0) return raw;
    int b_raw = int(round(s.b * 255.0));
    int bg    = b_raw >> 2;
    if (bg == raw) return raw;   // same fg/bg, no boundary
    int rot   = b_raw & 3;
    return shape_inside(rotate_uv(edge_uv, rot), shape) ? raw : (bg > 0 ? bg : -1);
}

// ── Fragment ──────────────────────────────────────────────────────────────────

void fragment() {
    vec2  cell_f  = v_world / tile_px;
    ivec2 cell    = ivec2(floor(cell_f));
    vec2  tile_uv = fract(cell_f);

    vec2  me_uv  = (vec2(cell) - map_origin + 0.5) / map_dims;
    vec4  me_raw = texture(terrain_map, me_uv);
    int   me     = (me_raw.a > 0.5) ? int(round(me_raw.r * 255.0)) : 0;
    if (me <= 0) { discard; }

    int shape = int(round(me_raw.g * 255.0));
    int b_raw = int(round(me_raw.b * 255.0));
    int rot   = b_raw & 3;
    int bg_me = b_raw >> 2;
    if (bg_me == me) shape = 0;  // same fg/bg → no internal boundary

    vec2 shape_uv = rotate_uv(tile_uv, rot);

    // Border width in world units: fixed fraction of tile size so it scales
    // proportionally as you zoom in.  tile_px/16 = 2 wu = 1/16 of a 32-px tile.
    // The max() keeps at least 1 canvas pixel at very small zoom levels.
    float bw = max(tile_px / 16.0, pixel_size);

    // Snap shape_uv to its canvas-pixel centre before the fill/void test.
    // All fragments in the same canvas pixel then agree on fill vs void,
    // so boundary pixels are fully filled rather than cut at the shape edge.
    float ps  = bw / tile_px;
    vec2  sn  = (floor(shape_uv / ps) + 0.5) * ps;
    bool is_fill = shape_inside(sn, shape);

    // Cache per-fragment colour lookups used in multiple branches.
    vec3 fill_me    = get_fill(me);
    vec3 outline_me = get_outline(me);

    // Distances to each cell edge in world units — used for border width tests.
    float d_l = tile_uv.x         * tile_px;
    float d_r = (1.0 - tile_uv.x) * tile_px;
    float d_t = tile_uv.y         * tile_px;
    float d_b = (1.0 - tile_uv.y) * tile_px;

    int my_terrain = is_fill ? me : (bg_me > 0 ? bg_me : -1);

    // Sample each neighbour half a canvas-pixel inward from the shared edge so
    // the lookup lands on the rendered pixel centre, not the mathematical boundary.
    // This prevents circles (whose arc touches x=0/1 at y=0.5) from returning
    // "void" when the actual snapped pixel is clearly inside the fill region.
    // Guards skip the texture fetch entirely for fragments far from each edge.
    float hps = ps * 0.5;
    int n_l = (d_l < bw) ? edge_terrain(cell + ivec2(-1,  0), vec2(1.0 - hps, tile_uv.y)) : -1;
    int n_r = (d_r < bw) ? edge_terrain(cell + ivec2( 1,  0), vec2(hps,        tile_uv.y)) : -1;
    int n_t = (d_t < bw) ? edge_terrain(cell + ivec2( 0, -1), vec2(tile_uv.x,  1.0 - hps)) : -1;
    int n_b = (d_b < bw) ? edge_terrain(cell + ivec2( 0,  1), vec2(tile_uv.x,  hps      )) : -1;

    // ── Pixel colour ──────────────────────────────────────────────────────────
    vec3 col;
    if (is_fill) {
        col = fill_me;
        // Shape boundary outline drawn from the fill side: a fill canvas pixel that
        // has a void neighbour within the same tile is at the shape edge → outline.
        // Drawing only from the fill side means each boundary position is covered
        // exactly once, eliminating double outlines when two same-type tiles meet.
        // Cross-tile neighbours (sn ± ps outside [0,1]) are skipped; the cell-edge
        // border below handles those transitions.
        if (shape != 0 && bg_me > 0) {
            bool near_void =
                (sn.x + ps <= 1.0 && !shape_inside(sn + vec2(ps,  0.0), shape)) ||
                (sn.x - ps >= 0.0 && !shape_inside(sn - vec2(ps,  0.0), shape)) ||
                (sn.y + ps <= 1.0 && !shape_inside(sn + vec2(0.0,  ps), shape)) ||
                (sn.y - ps >= 0.0 && !shape_inside(sn - vec2(0.0,  ps), shape));
            if (near_void) col = outline_me;
        }
    } else if (bg_me > 0) {
        col = get_fill(bg_me);
    } else {
        discard;
    }

    // ── Cell-edge border (runs last — overrides shape boundary outline) ───────
    if (my_terrain >= 0) {
        vec3 ol = get_outline(my_terrain);
        if (n_l >= 0 && n_l < my_terrain && d_l < bw && cell_raw(cell + ivec2(-1,  0)) != me) col = ol;
        if (n_r >= 0 && n_r < my_terrain && d_r < bw && cell_raw(cell + ivec2( 1,  0)) != me) col = ol;
        if (n_t >= 0 && n_t < my_terrain && d_t < bw && cell_raw(cell + ivec2( 0, -1)) != me) col = ol;
        if (n_b >= 0 && n_b < my_terrain && d_b < bw && cell_raw(cell + ivec2( 0,  1)) != me) col = ol;
    }

    COLOR = vec4(col, 1.0);
}
