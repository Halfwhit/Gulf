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
var _painting: bool = false
var _last_painted_cell: Vector2i = Vector2i(-32768, -32768)

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
		var cells: Array[Vector2i] = [cell]
		floor_map.set_cells_terrain_connect(cells, _selected_terrain_set, _selected_terrain)
		if floor_map.get_cell_source_id(cell) == -1:
			_place_fallback_terrain(cell, _selected_terrain)
	elif selected_source_id != -1 and _active_map != null:
		var cell := _active_map.local_to_map(_active_map.get_local_mouse_position())
		if cell == _last_painted_cell:
			return
		_last_painted_cell = cell
		_active_map.set_cell(cell, selected_source_id, selected_atlas_coords, _ROT_ALT[_rotation])

func _place_fallback_terrain(cell: Vector2i, terrain: int) -> void:
	# Godot can't place a tile when all 8 neighbours are empty — find the solid
	# interior tile (all peering bits == terrain, or no peering bits for terrain=1)
	var ts := floor_map.tile_set
	if not ts:
		return
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
			floor_map.set_cell(cell, sid, coords)
			return

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
