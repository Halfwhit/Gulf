extends Node2D

@onready var cursor: Sprite2D        = $Cursor
@onready var floor_map: TileMapLayer  = $Level/FloorMap
@onready var wall_map: TileMapLayer   = $Level/WallMap
@onready var entity_map: TileMapLayer = $Level/EntityMap
@onready var _editor_ui               = $EditorUI

const SELECT = preload("uid://cibhu1schuopa")
const TERRAIN_SHADER = preload("res://shaders/terrain_blend.gdshader")

var _select_texture: ImageTexture

var selected_source_id: int    = -1
var selected_atlas_coords: Vector2i
var _active_map: TileMapLayer
var _rotation: int             = 0

var _painting: bool  = false
var _erasing: bool   = false
var _last_painted_cell: Vector2i = Vector2i(-32768, -32768)
var _last_erased_cell: Vector2i  = Vector2i(-32768, -32768)

# Transform bit flags for rotated wall/entity tiles
const _ROT_ALT := [0, 20480, 12288, 24576]  # 0°, 90° CW, 180°, 270° CW

# ── Terrain map ───────────────────────────────────────────────────────────────
# One pixel per cell; r-channel = terrain_id (source_id + 1), a = 1 if occupied.
const MAP_SIZE   := 256
const MAP_ORIGIN := Vector2i(-128, -128)  # cell coord of terrain_map pixel (0, 0)

var _terrain_image:   Image
var _terrain_texture: ImageTexture
var _terrain_dirty:   bool = false
var _shader_mat:      ShaderMaterial

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_select_texture = ImageTexture.create_from_image(SELECT)

	# Build the terrain map texture
	_terrain_image = Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	_terrain_texture = ImageTexture.create_from_image(_terrain_image)

	# Create and attach the shader material to FloorMap.
	# Use Vector2 (float) for map_origin/map_dims — vec2 uniforms, not ivec2.
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = TERRAIN_SHADER
	_shader_mat.set_shader_parameter("terrain_map", _terrain_texture)
	_shader_mat.set_shader_parameter("map_origin",  Vector2(MAP_ORIGIN))
	_shader_mat.set_shader_parameter("map_dims",    Vector2(MAP_SIZE, MAP_SIZE))
	_shader_mat.set_shader_parameter("tile_px",     float(floor_map.tile_set.tile_size.x))
	floor_map.material = _shader_mat

	# Populate the terrain map from any tiles already in the tilemap
	_rebuild_terrain_map()


func _process(_delta: float) -> void:
	if _terrain_dirty:
		_terrain_texture.update(_terrain_image)
		_terrain_dirty = false


# ── Input ─────────────────────────────────────────────────────────────────────

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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_erasing = true
			_last_erased_cell = Vector2i(-32768, -32768)
			_erase()
		else:
			_erasing = false

	if event is InputEventMouseMotion:
		var snap_map  := entity_map if _active_map == entity_map else floor_map
		var snap_pos  := snap_map.map_to_local(snap_map.local_to_map(snap_map.get_local_mouse_position()))
		cursor.global_position = snap_map.to_global(snap_pos)
		if _painting:
			_paint()
		elif _erasing:
			_erase()


# ── Paint / erase ─────────────────────────────────────────────────────────────

func _paint() -> void:
	if selected_source_id == -1 or _active_map == null:
		return

	# Resolve the cell position using the active map's coordinate space
	var map    := _active_map
	var pcell  := map.local_to_map(map.get_local_mouse_position())
	if pcell == _last_painted_cell:
		return
	_last_painted_cell = pcell

	# Floor tiles never rotate; wall and entity tiles respect the rotation dial.
	map.set_cell(pcell, selected_source_id, selected_atlas_coords,
			0 if map == floor_map else _ROT_ALT[_rotation])

	# For walls, auto-place Fairway floor underneath if empty
	if map == wall_map and floor_map.get_cell_source_id(pcell) == -1:
		_set_floor(pcell, 0)

	if map == floor_map:
		_set_floor(pcell, selected_source_id)


func _erase() -> void:
	if _active_map == entity_map:
		var ecell := entity_map.local_to_map(entity_map.get_local_mouse_position())
		if ecell == _last_erased_cell:
			return
		_last_erased_cell = ecell
		entity_map.erase_cell(ecell)
		return

	var cell := floor_map.local_to_map(floor_map.get_local_mouse_position())
	if cell == _last_erased_cell:
		return
	_last_erased_cell = cell

	if _active_map == floor_map:
		floor_map.erase_cell(cell)
		_clear_terrain_pixel(cell)
	elif _active_map != null:
		_active_map.erase_cell(cell)
	else:
		# No layer selected — erase everything at this cell
		floor_map.erase_cell(cell)
		wall_map.erase_cell(cell)
		entity_map.erase_cell(entity_map.local_to_map(entity_map.get_local_mouse_position()))
		_clear_terrain_pixel(cell)


# ── Terrain map helpers ───────────────────────────────────────────────────────

func _set_floor(cell: Vector2i, source_id: int) -> void:
	var terrain_id := source_id + 1  # terrain_id is 1-based (0 = empty)
	floor_map.set_cell(cell, source_id, Vector2i.ZERO)
	_write_terrain_pixel(cell, terrain_id)


func _write_terrain_pixel(cell: Vector2i, terrain_id: int) -> void:
	var px := cell - MAP_ORIGIN
	if px.x < 0 or px.y < 0 or px.x >= MAP_SIZE or px.y >= MAP_SIZE:
		return
	_terrain_image.set_pixel(px.x, px.y,
			Color(float(terrain_id) / 255.0, 0.0, 0.0, 1.0))
	_terrain_dirty = true


func _clear_terrain_pixel(cell: Vector2i) -> void:
	var px := cell - MAP_ORIGIN
	if px.x < 0 or px.y < 0 or px.x >= MAP_SIZE or px.y >= MAP_SIZE:
		return
	_terrain_image.set_pixel(px.x, px.y, Color(0.0, 0.0, 0.0, 0.0))
	_terrain_dirty = true


func _rebuild_terrain_map() -> void:
	_terrain_image.fill(Color(0, 0, 0, 0))
	for cell in floor_map.get_used_cells():
		var src := floor_map.get_cell_source_id(cell)
		if src >= 0:
			_write_terrain_pixel(cell, src + 1)
	_terrain_texture.update(_terrain_image)
	_terrain_dirty = false


# ── Editor UI signal handlers ─────────────────────────────────────────────────

func _on_editor_ui_tile_selected(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D) -> void:
	cursor.texture = image
	selected_source_id = source_id
	selected_atlas_coords = atlas_coords
	match layer:
		&"floor":   _active_map = floor_map
		&"wall":    _active_map = wall_map
		&"entity":  _active_map = entity_map
	if layer != &"entity":
		_editor_ui.set_tile_rotation(_rotation)


func _on_editor_ui_tile_cleared(_layer: StringName, source_id: int, atlas_coords: Vector2i, _image: Texture2D) -> void:
	if source_id == selected_source_id and atlas_coords == selected_atlas_coords:
		cursor.texture = _select_texture
		_active_map = null
		selected_source_id = -1
