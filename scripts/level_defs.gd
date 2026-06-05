## Shared constants used by both the editor and the game scene.
## Access via LevelDefs.CONSTANT or LevelDefs.write_terrain_pixel().
class_name LevelDefs

const TILE_PX    := 32
const MAP_SIZE   := 256
const MAP_ORIGIN := Vector2i(-128, -128)

const ENTITY_SOURCE_HOLE  := 0
const ENTITY_SOURCE_START := 1

## Maps the rotation dial (0–3) to the TileSetAtlasSource transform alt-ID.
## rot=1 and rot=3 use swapped TRANSPOSE flags — verified empirically against
## the Sprite2D cursor; do not change without re-testing all shaped tiles.
const ROT_ALT: Array[int] = [
	0,
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H,  # rot=1
	TileSetAtlasSource.TRANSFORM_FLIP_H    | TileSetAtlasSource.TRANSFORM_FLIP_V,  # rot=2
	TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V,  # rot=3
]

## Writes one cell into a terrain Image.  terrain_id 0 clears the cell (alpha 0).
## B channel: bits 0-1 = rot, bits 2-7 = bg terrain_id.
static func write_terrain_pixel(img: Image, cell: Vector2i,
		terrain_id: int, shape_id: int = 0, rot: int = 0, bg: int = 0) -> void:
	var px := cell - MAP_ORIGIN
	if px.x < 0 or px.y < 0 or px.x >= MAP_SIZE or px.y >= MAP_SIZE:
		return
	img.set_pixel(px.x, px.y,
			Color(float(terrain_id) / 255.0, float(shape_id) / 255.0,
				  float(rot | (bg << 2)) / 255.0, float(terrain_id > 0)))
