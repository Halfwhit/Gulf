@tool
extends EditorScript

# ── add_tile_physics.gd ───────────────────────────────────────────────────────
# Run once from the Godot editor via File → Run Script.
# Adds a physics layer to tileset_floor.tres and sets convex collision polygons
# on every tile whose atlas Y coord maps to a recognised shape (0-6).
# Also creates rotation alternatives (using the same transform flags as LevelDefs.ROT_ALT
# as entity tiles) so that Godot automatically applies the correct flip/
# transpose transform to the collision shapes at runtime.
#
# Shape IDs (atlas row = shape_id):
#   0  rect        full square
#   1  diagonal    lower-right triangle  (fill where ux+uy > 1)
#   2  curve       large arc region near bottom-right corner
#   3  curve_inv   complement of curve (two convex pieces)
#   4  half        bottom half
#   5  diamond     rotated square (|ux-0.5|+|uy-0.5| ≤ 0.5)
#   6  circle      inscribed circle (8-point polygon)
#
# All coordinates are in tile-local space with (0,0) at the tile centre.
# For 32-px tiles, corners are at ±16.
# ─────────────────────────────────────────────────────────────────────────────

const TILESET_PATH := "res://resources/tileset_floor.tres"

const H   := 16.0      # half tile size
const R   := 0.707107  # cos/sin 45° = 1/√2
const ARC := -7.0      # arc midpoint offset (circle of r=32 centred at corner)

# Same alt-IDs as LevelDefs.ROT_ALT[1..3] (kept local — @tool EditorScript context).
# Godot applies the corresponding flip/transpose transform to all TileData
# properties (including physics polygons) when the tile is placed in the world.
const ROT_ALTS := [
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,  # rot=1
	TileSetAtlasSource.TRANSFORM_FLIP_H    | TileSetAtlasSource.TRANSFORM_FLIP_V,  # rot=2
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,  # rot=3
]

func _run() -> void:
	var ts: TileSet = load(TILESET_PATH)
	if ts == null:
		push_error("Could not load " + TILESET_PATH)
		return

	var source: TileSetAtlasSource = ts.get_source(ts.get_source_id(0))
	if source == null:
		push_error("No atlas source found in tileset")
		return

	# ── Copy alt-0 physics into rotation alternatives ─────────────────────────
	# Alt 0 contains your hand-refined shapes — this script never touches them.
	# It only creates alts 1-3 (if missing) and mirrors the alt-0 polygons into
	# each one.  Godot then applies the alt's flip/transpose transform to those
	# polygons at runtime, giving correctly-rotated collision shapes for free.

	var applied := 0
	for i in source.get_tiles_count():
		var coords: Vector2i = source.get_tile_id(i)

		var base_td: TileData = source.get_tile_data(coords, 0)
		if base_td == null:
			continue

		var poly_count := base_td.get_collision_polygons_count(0)
		if poly_count == 0:
			continue   # no physics on this tile — nothing to propagate

		for alt_id in ROT_ALTS:
			if not source.has_alternative_tile(coords, alt_id):
				source.create_alternative_tile(coords, alt_id)
			var alt_td: TileData = source.get_tile_data(coords, alt_id)
			if alt_td == null:
				continue
			alt_td.set_collision_polygons_count(0, poly_count)
			for pi in poly_count:
				alt_td.set_collision_polygon_points(
					0, pi, base_td.get_collision_polygon_points(0, pi))

		applied += 1

	# ── Save ──────────────────────────────────────────────────────────────────
	var err := ResourceSaver.save(ts, TILESET_PATH)
	if err != OK:
		push_error("Failed to save tileset: error %d" % err)
	else:
		print("✓ Rotation alts created/updated for %d tiles → %s" % [applied, TILESET_PATH])
