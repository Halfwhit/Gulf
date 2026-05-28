extends Node2D

@onready var cursor: Sprite2D = $Cursor
@onready var floor_map: TileMapLayer   = $Level/FloorMap
@onready var wall_map: TileMapLayer    = $Level/WallMap
@onready var entity_map: TileMapLayer  = $Level/EntityMap
@onready var _editor_ui = $EditorUI
const SELECT = preload("uid://cibhu1schuopa")
var _select_texture: ImageTexture

var selected_source_id: int = -1
var selected_atlas_coords: Vector2i
var _active_map: TileMapLayer
var _rotation: int = 0
var _selected_terrain_set: int = -1
var _selected_terrain: int = -1
var _painting: bool = false
var _last_painted_cell: Vector2i = Vector2i(-32768, -32768)

# Transform bit flags: TRANSPOSE=16384, FLIP_H=4096, FLIP_V=8192
const _ROT_ALT := [0, 20480, 12288, 24576]  # 0°, 90° CW, 180°, 270° CW

const _NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i( 1,  0), Vector2i( 1,  1), Vector2i( 0,  1), Vector2i(-1,  1),
	Vector2i(-1,  0), Vector2i(-1, -1), Vector2i( 0, -1), Vector2i( 1, -1),
]
const _PEERING_BITS: Array[int] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,        TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,       TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,         TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,          TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
]

func _ready() -> void:
	_select_texture = ImageTexture.create_from_image(SELECT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotation = (_rotation + 1) % 4
		cursor.rotation_degrees = _rotation * 90.0
		_editor_ui.set_tile_rotation(_rotation)

	if event.is_action_pressed("touch_main"):
		_painting = true
		_last_painted_cell = Vector2i(-32768, -32768)
		_paint()
	elif event.is_action_released("touch_main"):
		_painting = false

	if event is InputEventMouseMotion:
		cursor.position = floor_map.map_to_local(floor_map.local_to_map(floor_map.get_local_mouse_position()))
		if _painting:
			_paint()

func _paint() -> void:
	if _selected_terrain != -1:
		var cell := floor_map.local_to_map(floor_map.get_local_mouse_position())
		if cell == _last_painted_cell:
			return
		_last_painted_cell = cell

		# Ghost-fill empty neighbours with the solid interior tile so Godot's
		# terrain algorithm treats them as "solid fairway" context.
		var ghosts: Array[Vector2i] = []
		for off in _NEIGHBOUR_OFFSETS:
			var n := cell + off
			if floor_map.get_cell_source_id(n) == -1:
				_place_solid_terrain(n, _selected_terrain)
				ghosts.append(n)

		var cells: Array[Vector2i] = [cell]
		floor_map.set_cells_terrain_connect(cells, _selected_terrain_set, _selected_terrain)

		for n in ghosts:
			floor_map.erase_cell(n)

		if floor_map.get_cell_source_id(cell) == -1:
			_place_solid_terrain(cell, _selected_terrain)
	elif selected_source_id != -1 and _active_map != null:
		var cell := _active_map.local_to_map(_active_map.get_local_mouse_position())
		if cell == _last_painted_cell:
			return
		_last_painted_cell = cell
		_active_map.set_cell(cell, selected_source_id, selected_atlas_coords, _ROT_ALT[_rotation])
		if _active_map == wall_map and floor_map.get_cell_source_id(cell) == -1:
			_place_solid_terrain(cell, 0)

func _place_solid_terrain(cell: Vector2i, terrain: int) -> void:
	# Find the tile with the most peering bits == 1 (solid-fairway interior tile).
	var ts := floor_map.tile_set
	if not ts:
		return
	var best_sid := -1
	var best_coords := Vector2i.ZERO
	var best_score := -1
	for i in ts.get_source_count():
		var sid := ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if not src:
			continue
		for j in src.get_tiles_count():
			var coords := src.get_tile_id(j)
			var d := src.get_tile_data(coords, 0)
			if not d or d.terrain_set != 0 or d.terrain != terrain:
				continue
			var score := 0
			for bit in _PEERING_BITS:
				if d.get_terrain_peering_bit(bit) == 1:
					score += 1
			if score > best_score:
				best_score = score
				best_sid = sid
				best_coords = coords
	if best_sid != -1:
		floor_map.set_cell(cell, best_sid, best_coords)

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
	_active_map = entity_map if layer == &"entity" else wall_map
	_selected_terrain = -1
	_editor_ui.set_tile_rotation(_rotation)

func _on_editor_ui_tile_cleared(layer: StringName, source_id: int, atlas_coords: Vector2i, _image: Texture2D) -> void:
	var cleared_map: TileMapLayer
	match layer:
		&"wall":   cleared_map = wall_map
		&"entity": cleared_map = entity_map
		_:         return
	if cleared_map == _active_map and source_id == selected_source_id and atlas_coords == selected_atlas_coords:
		cursor.texture = _select_texture
		_active_map = null
		selected_source_id = -1
