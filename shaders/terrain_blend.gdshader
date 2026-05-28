shader_type canvas_item;

// ── Terrain map ───────────────────────────────────────────────────────────────
// 256×256 RGBA8 texture, one pixel per cell.
// r = terrain_id (1-based, 1-6). a > 0.5 means tile exists.
// Empty / out-of-bounds cells return -1 (no border drawn towards void).
//
// Terrain IDs: 1=Fairway  2=Green  3=LightMud  4=DarkMud  5=Water  6=Acid
uniform sampler2D terrain_map : filter_nearest, repeat_disable;
uniform vec2  map_origin = vec2(-128.0, -128.0);
uniform vec2  map_dims   = vec2(256.0, 256.0);
uniform float tile_px    = 32.0;

// ── Fill / outline colours (1-based) ─────────────────────────────────────────
uniform vec3 fill_1    = vec3(0.220, 0.718, 0.392);   // Fairway
uniform vec3 fill_2    = vec3(0.655, 0.941, 0.439);   // Green
uniform vec3 fill_3    = vec3(0.706, 0.549, 0.314);   // LightMud
uniform vec3 fill_4    = vec3(0.471, 0.353, 0.196);   // DarkMud
uniform vec3 fill_5    = vec3(0.439, 0.702, 0.941);   // Water
uniform vec3 fill_6    = vec3(0.941, 0.922, 0.439);   // Acid

uniform vec3 outline_1 = vec3(0.145, 0.443, 0.475);   // Fairway
uniform vec3 outline_2 = vec3(0.145, 0.443, 0.475);   // Green
uniform vec3 outline_3 = vec3(0.310, 0.235, 0.118);   // LightMud
uniform vec3 outline_4 = vec3(0.200, 0.157, 0.078);   // DarkMud
uniform vec3 outline_5 = vec3(0.145, 0.318, 0.475);   // Water
uniform vec3 outline_6 = vec3(0.475, 0.463, 0.145);   // Acid

// ── World-position varying ────────────────────────────────────────────────────
// Passed directly as VERTEX (local/world space for a TileMapLayer at origin).
// floor(v_world / tile_px + 0.5) gives the integer cell coord, matching
// Godot's map_to_local() centre convention.
varying vec2 v_world;

void vertex() {
    v_world = VERTEX;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

vec3 get_fill(int id) {
    if (id == 1) return fill_1;
    if (id == 2) return fill_2;
    if (id == 3) return fill_3;
    if (id == 4) return fill_4;
    if (id == 5) return fill_5;
    if (id == 6) return fill_6;
    return fill_1;
}

vec3 get_outline(int id) {
    if (id == 1) return outline_1;
    if (id == 2) return outline_2;
    if (id == 3) return outline_3;
    if (id == 4) return outline_4;
    if (id == 5) return outline_5;
    if (id == 6) return outline_6;
    return outline_1;
}

// Returns terrain_id (1-6) or -1 if empty / out of bounds.
int lookup(ivec2 cell) {
    vec2 tc = vec2(cell) - map_origin;
    if (tc.x < 0.0 || tc.y < 0.0 || tc.x >= map_dims.x || tc.y >= map_dims.y)
        return -1;
    vec2 uv = (tc + 0.5) / map_dims;
    vec4 s = texture(terrain_map, uv);
    int raw = int(round(s.r * 255.0));
    return (s.a > 0.5 && raw > 0) ? raw : -1;
}

// ── Edge blending rule ────────────────────────────────────────────────────────
// Only the HIGHER-ID terrain draws a transition band toward its lower-ID
// neighbour.  Fairway (ID 1) is the base terrain and never draws borders;
// all other terrains draw their border on themselves.
//
//   void  (id = -1) → never draws, never receives a band
//   me > nb          → draw nb's fill (1 px) + my outline (1 px) near that edge
//   me <= nb         → nothing (the other tile handles it, or same terrain)
void blend_edge(inout vec3 col, float d, int nb, int me, vec3 my_outline) {
    if (nb < 0 || nb >= me || d >= 2.0) return;
    col = (d < 1.0) ? get_fill(nb) : my_outline;
}

// ── Fragment ──────────────────────────────────────────────────────────────────

void fragment() {
    // Godot 4 TileMapLayer: map_to_local returns the CENTRE of each cell,
    // so cell (cx,cy) spans (cx*tile-half, cy*tile-half) to (cx*tile+half, ...).
    // The matching inverse is floor(v_world/tile + 0.5) — same as local_to_map.
    ivec2 cell = ivec2(floor(v_world / tile_px + 0.5));

    int me = lookup(cell);
    if (me <= 0) { discard; }

    float d_l = UV.x * tile_px;
    float d_r = (1.0 - UV.x) * tile_px;
    float d_t = UV.y * tile_px;
    float d_b = (1.0 - UV.y) * tile_px;

    int n_l  = lookup(cell + ivec2(-1,  0));
    int n_r  = lookup(cell + ivec2( 1,  0));
    int n_t  = lookup(cell + ivec2( 0, -1));
    int n_b  = lookup(cell + ivec2( 0,  1));
    int n_tl = lookup(cell + ivec2(-1, -1));
    int n_tr = lookup(cell + ivec2( 1, -1));
    int n_bl = lookup(cell + ivec2(-1,  1));
    int n_br = lookup(cell + ivec2( 1,  1));

    vec3 my_outline = get_outline(me);
    vec3 col        = get_fill(me);

    // ── Cardinal edges ────────────────────────────────────────────────────────
    // Apply all four in order; then re-apply the closest eligible edge so it
    // wins at pixels where two edges overlap (e.g. corner pixels).
    blend_edge(col, d_r, n_r, me, my_outline);
    blend_edge(col, d_l, n_l, me, my_outline);
    blend_edge(col, d_b, n_b, me, my_outline);
    blend_edge(col, d_t, n_t, me, my_outline);

    float min_d  = 999.0;
    int   min_nb = -1;
    if (n_r >= 1 && n_r < me && d_r < min_d) { min_d = d_r; min_nb = n_r; }
    if (n_l >= 1 && n_l < me && d_l < min_d) { min_d = d_l; min_nb = n_l; }
    if (n_b >= 1 && n_b < me && d_b < min_d) { min_d = d_b; min_nb = n_b; }
    if (n_t >= 1 && n_t < me && d_t < min_d) { min_d = d_t; min_nb = n_t; }
    if (min_nb >= 1) blend_edge(col, min_d, min_nb, me, my_outline);

    // ── Diagonal corners ──────────────────────────────────────────────────────
    // Fill the 1×1 corner pixel only when BOTH adjacent cardinals are also
    // drawing (both are lower-ID tiles).  This completes the outline at true
    // convex corners and prevents isolated corner pixels in all other cases.
    if (d_r < 1.0 && d_t < 1.0 && n_tr >= 1 && n_tr < me
            && (n_r >= 1 && n_r < me) && (n_t >= 1 && n_t < me)) col = get_fill(n_tr);
    if (d_l < 1.0 && d_t < 1.0 && n_tl >= 1 && n_tl < me
            && (n_l >= 1 && n_l < me) && (n_t >= 1 && n_t < me)) col = get_fill(n_tl);
    if (d_r < 1.0 && d_b < 1.0 && n_br >= 1 && n_br < me
            && (n_r >= 1 && n_r < me) && (n_b >= 1 && n_b < me)) col = get_fill(n_br);
    if (d_l < 1.0 && d_b < 1.0 && n_bl >= 1 && n_bl < me
            && (n_l >= 1 && n_l < me) && (n_b >= 1 && n_b < me)) col = get_fill(n_bl);

    COLOR = vec4(col, 1.0);
}
