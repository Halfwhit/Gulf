extends Node2D

@onready var cursor: Sprite2D = $Cursor
@onready var floor_map: TileMapLayer = $Level/FloorMap
@onready var wall_map: TileMapLayer  = $Level/WallMap
@onready var _editor_ui = $EditorUI
const SELECT = preload("uid://cibhu1schuopa")
var _select_texture: ImageTexture

var selected_source_id: int = -1
var selected_atlas_coords: Vector2i
var _active_map: TileMapLayer
var _rotation: int = 0
var _selected_terrain_set: int = -1
var _selected_terrain: int = -1
var _floor_terrain: Dictionary = {}  # Vector2i → int

const _NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i( 0, -1), Vector2i( 1, -1), Vector2i( 1,  0), Vector2i( 1,  1),
	Vector2i( 0,  1), Vector2i(-1,  1), Vector2i(-1,  0), Vector2i(-1, -1),
]
const _NEIGHBOR_BITS: Array[int] = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE,          TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,       TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,         TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
]

# Transform bit flags: TRANSPOSE=16384, FLIP_H=4096, FLIP_V=8192
const _ROT_ALT := [0, 20480, 12288, 24576]  # 0°, 90° CW, 180°, 270° CW

func _ready() -> void:
	_select_texture = ImageTexture.create_from_image(SELECT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotation = (_rotation + 1) % 4
		cursor.rotation_degrees = _rotation * 90.0
		_editor_ui.set_tile_rotation(_rotation)

	if event.is_action_pressed("touch_main"):
		if _selected_terrain != -1:
			var cell := floor_map.local_to_map(floor_map.get_local_mouse_position())
			_paint_terrain(cell, _selected_terrain)
		elif selected_source_id != -1 and _active_map != null:
			_active_map.set_cell(
				_active_map.local_to_map(_active_map.get_local_mouse_position()),
				selected_source_id, selected_atlas_coords, _ROT_ALT[_rotation]
			)

	if event is InputEventMouseMotion:
		cursor.position = floor_map.map_to_local(floor_map.local_to_map(floor_map.get_local_mouse_position()))

func _paint_terrain(cell: Vector2i, terrain: int) -> void:
	_floor_terrain[cell] = terrain
	_refresh_terrain_tile(cell)
	for offset in _NEIGHBOR_OFFSETS:
		var n := cell + offset
		if _floor_terrain.has(n):
			_refresh_terrain_tile(n)

func _refresh_terrain_tile(cell: Vector2i) -> void:
	var t: int = _floor_terrain.get(cell, -1)
	if t == -1:
		return
	var ts := floor_map.tile_set
	if not ts:
		return
	var neighbor_t: Array[int] = []
	for offset in _NEIGHBOR_OFFSETS:
		neighbor_t.append(_floor_terrain.get(cell + offset, -1))
	var best_src := -1
	var best_coords := Vector2i.ZERO
	var best_score := -9999
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if not src:
			continue
		for j in src.get_tiles_count():
			var coords := src.get_tile_id(j)
			var d := src.get_tile_data(coords, 0)
			if not d or d.terrain_set != 0 or d.terrain != t:
				continue
			var score := 0
			for k in 8:
				var required: int = neighbor_t[k]
				var tile_bit: int = d.get_terrain_peering_bit(_NEIGHBOR_BITS[k])
				if required == -1:
					if tile_bit == t:
						score += 1
				elif tile_bit == required:
					score += 1
				else:
					score -= 1
			if score > best_score:
				best_score = score
				best_src = sid
				best_coords = coords
	if best_src != -1:
		floor_map.set_cell(cell, best_src, best_coords)

func _on_editor_ui_terrain_selected(_layer: StringName, terrain_set: int, terrain: int, image: Texture2D) -> void:
	cursor.texture = image
	_selected_terrain_set = terrain_set
	_selected_terrain = terrain
	selected_source_id = -1

func _on_editor_ui_terrain_cleared(_layer: StringName) -> void:
	_selected_terrain = -1
	_selected_terrain_set = -1
	cursor.texture = _select_texture

func _on_editor_ui_tile_selected(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D) -> void:
	cursor.texture = image
	selected_source_id = source_id
	selected_atlas_coords = atlas_coords
	_active_map = wall_map
	_selected_terrain = -1
	_editor_ui.set_tile_rotation(_rotation)

func _on_editor_ui_tile_cleared(layer: StringName, source_id: int, atlas_coords: Vector2i, _image: Texture2D) -> void:
	var cleared_map := floor_map if layer == &"floor" else wall_map
	if cleared_map == _active_map and source_id == selected_source_id and atlas_coords == selected_atlas_coords:
		cursor.texture = _select_texture
		_active_map = null
		selected_source_id = -1
