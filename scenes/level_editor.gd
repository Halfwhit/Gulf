extends Node2D

@onready var cursor: Sprite2D         = $Cursor
@onready var floor_map: TileMapLayer  = $Level/FloorMap
@onready var entity_map: TileMapLayer = $Level/EntityMap
@onready var _editor_ui: EditorUI     = $EditorUI

const SELECT         = preload("uid://cibhu1schuopa")
const TERRAIN_SHADER = preload("res://shaders/terrain_blend.gdshader")

var _select_texture: ImageTexture
var _camera: Camera2D

# Sentinel for "no cell touched yet this stroke" — outside any valid map.
const _NO_CELL := Vector2i(-32768, -32768)
var _last_painted_cell: Vector2i = _NO_CELL
var _last_erased_cell: Vector2i  = _NO_CELL

var _painting: bool = false
var _erasing:  bool = false

# Fill-rect tool state.
var _fill_start: Vector2i = _NO_CELL
var _fill_active: bool    = false

# Middle-mouse pan state.
var _panning: bool          = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_cam: Vector2   = Vector2.ZERO

# Discrete zoom levels — all exact power-of-two fractions so pixel_size = 1/zoom
# is always a clean value and tile edges land on exact canvas-pixel boundaries.
const _ZOOM_STEPS: Array[float] = [0.25, 0.5, 1.0, 2.0]
var _zoom_idx: int = 1  # default 0.5

# ── Terrain map ───────────────────────────────────────────────────────────────

var _terrain_image:   Image
var _terrain_texture: ImageTexture
var _terrain_dirty:   bool = false
var _shader_mat:      ShaderMaterial

# ── Save / Load / Play ───────────────────────────────────────────────────────
const TEMP_LEVEL_PATH := "user://temp_level.json"

# Persists across scene changes so the editor reloads the right file on return.
static var _pending_load: String = ""

var _current_path: String    = ""
var _save_dialog:  FileDialog = null
var _load_dialog:  FileDialog = null

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_select_texture = ImageTexture.create_from_image(SELECT)

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE * _ZOOM_STEPS[_zoom_idx]
	add_child(_camera)

	_terrain_image   = Image.create(LevelDefs.MAP_SIZE, LevelDefs.MAP_SIZE, false, Image.FORMAT_RGBA8)
	_terrain_texture = ImageTexture.create_from_image(_terrain_image)

	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = TERRAIN_SHADER
	_shader_mat.set_shader_parameter("terrain_map", _terrain_texture)
	_shader_mat.set_shader_parameter("map_origin",  Vector2(LevelDefs.MAP_ORIGIN))
	_shader_mat.set_shader_parameter("map_dims",    Vector2(LevelDefs.MAP_SIZE, LevelDefs.MAP_SIZE))
	_shader_mat.set_shader_parameter("tile_px",     float(floor_map.tile_set.tile_size.x))
	floor_map.material = _shader_mat

	_rebuild_terrain_map()
	_snap_camera()
	_refresh_cursor()

	# File dialogs — created here so they're parented to the scene root.
	_save_dialog = _make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save Level", _do_save)
	_load_dialog = _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Load Level", _do_load)

	_editor_ui.save_requested.connect(_open_save_dialog)
	_editor_ui.load_requested.connect(func(): _load_dialog.popup_centered_ratio(0.6))
	_editor_ui.play_requested.connect(_on_play_pressed)

	# Reload level when returning from the game scene.
	if not _pending_load.is_empty():
		# Don't treat the temp file as a save target — keep _current_path empty
		# so the Save dialog still opens for levels that were never saved to a file.
		_do_load(_pending_load, _pending_load != TEMP_LEVEL_PATH)
		_pending_load = ""


func _process(_delta: float) -> void:
	if _terrain_dirty:
		_flush_terrain()


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _editor_ui == null or _camera == null:
		return

	# Ctrl+S → save (to current path or dialog); Ctrl+O → open load dialog.
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				_open_save_dialog()
				get_viewport().set_input_as_handled()
			KEY_O:
				_load_dialog.popup_centered_ratio(0.6)
				get_viewport().set_input_as_handled()
			KEY_P:
				_on_play_pressed()
				get_viewport().set_input_as_handled()

	# Scroll-wheel zoom.
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _apply_zoom(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _apply_zoom(-1)
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					_panning = true
					_pan_start_mouse = get_viewport().get_mouse_position()
					_pan_start_cam   = _camera.global_position
				else:
					_panning = false
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if _panning:
			var delta_screen := get_viewport().get_mouse_position() - _pan_start_mouse
			var ideal        := _pan_start_cam - delta_screen / _camera.zoom
			var ps           := 1.0 / _camera.zoom.x
			_camera.global_position = (ideal / ps).round() * ps
			get_viewport().set_input_as_handled()

		# Cursor snapping — use entity_map grid when entity layer is active.
		var snap_map: TileMapLayer = entity_map if _editor_ui.active_layer == EditorUI.LAYER_ENTITY else floor_map
		var current_cell := snap_map.local_to_map(snap_map.get_local_mouse_position())
		cursor.global_position = snap_map.to_global(snap_map.map_to_local(current_cell))

		if _painting:
			if _editor_ui.active_tool == EditorUI.TOOL_BRUSH:
				# Reuse the cell already computed for cursor snapping — avoids a
				# redundant local_to_map call on every mouse-move while painting.
				if current_cell != _last_painted_cell:
					_last_painted_cell = current_cell
					_paint_cell(current_cell)
		elif _erasing:
			_erase()

	# Left mouse — brush / fill-rect / erase start/stop.
	var tool: int = _editor_ui.active_tool
	if event.is_action_pressed("touch_main"):
		if tool == EditorUI.TOOL_BRUSH:
			_painting = true
			_last_painted_cell = _NO_CELL
			_paint()
		elif tool == EditorUI.TOOL_ERASE:
			_erasing = true
			_last_erased_cell = _NO_CELL
			_erase()
		elif tool == EditorUI.TOOL_FILL_RECT:
			var map := _active_map_for_layer()
			if map != null:
				_fill_start  = map.local_to_map(map.get_local_mouse_position())
				_fill_active = true

	elif event.is_action_released("touch_main"):
		if tool == EditorUI.TOOL_BRUSH:
			_painting = false
		elif tool == EditorUI.TOOL_ERASE:
			_erasing = false
		elif tool == EditorUI.TOOL_FILL_RECT:
			if _fill_active:
				_fill_active = false
				var map := _active_map_for_layer()
				if map != null:
					var end_cell := map.local_to_map(map.get_local_mouse_position())
					_do_fill_rect(_fill_start, end_cell)

	# Right-mouse erases regardless of active tool.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_erasing = true
			_last_erased_cell = _NO_CELL
			_erase()
		else:
			_erasing = false


# ── Camera helpers ────────────────────────────────────────────────────────────

# Snap camera position to the canvas-pixel grid (pixel_size = 1/zoom world units)
# so tile quad edges always land on exact canvas-pixel boundaries, eliminating
# sub-pixel rendering artifacts on borders at all zoom levels.
func _snap_camera() -> void:
	var ps := 1.0 / _camera.zoom.x
	_camera.global_position = (_camera.global_position / ps).round() * ps
	_shader_mat.set_shader_parameter("pixel_size", ps)


func _apply_zoom(delta: int) -> void:
	_zoom_idx = clampi(_zoom_idx + delta, 0, _ZOOM_STEPS.size() - 1)
	_camera.zoom = Vector2.ONE * _ZOOM_STEPS[_zoom_idx]
	_snap_camera()
	get_viewport().set_input_as_handled()


# ── Active map helper ─────────────────────────────────────────────────────────

func _active_map_for_layer() -> TileMapLayer:
	match _editor_ui.active_layer:
		EditorUI.LAYER_FLOOR:  return floor_map
		EditorUI.LAYER_ENTITY: return entity_map
	return null


# ── Paint ─────────────────────────────────────────────────────────────────────

func _paint() -> void:
	var map := _active_map_for_layer()
	if map == null:
		return
	var pcell := map.local_to_map(map.get_local_mouse_position())
	if pcell == _last_painted_cell:
		return
	_last_painted_cell = pcell
	_paint_cell(pcell)


func _paint_cell(pcell: Vector2i) -> void:
	var layer: StringName = _editor_ui.active_layer

	if layer == EditorUI.LAYER_FLOOR:
		var shape: int = _editor_ui.selected_shape
		var rot:   int = _editor_ui.tile_rotation if shape > 0 else 0
		var bg:    int = (_editor_ui.bg_source_id + 1) if shape > 0 else 0
		# atlas_coords: x = terrain column (fg_source_id), y = shape row.
		# Use LevelDefs.ROT_ALT[rot] as the alternative tile so Godot applies the correct
		# flip/transpose transform to the collision shapes at runtime.
		floor_map.set_cell(pcell, 0, Vector2i(_editor_ui.fg_source_id, shape), LevelDefs.ROT_ALT[rot])
		_write_terrain_pixel(pcell, _editor_ui.fg_source_id + 1, shape, rot, bg)
		return

	if layer == EditorUI.LAYER_ENTITY:
		if _editor_ui.entity_source_id == -1:
			return
		var rot: int = _editor_ui.tile_rotation
		entity_map.set_cell(pcell, _editor_ui.entity_source_id,
				_editor_ui.entity_atlas_coords, LevelDefs.ROT_ALT[rot])


# ── Erase ─────────────────────────────────────────────────────────────────────

func _erase() -> void:
	var layer: StringName = _editor_ui.active_layer

	if layer == EditorUI.LAYER_ENTITY:
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

	floor_map.erase_cell(cell)
	_write_terrain_pixel(cell, 0)


# ── Fill rect ─────────────────────────────────────────────────────────────────

func _do_fill_rect(start: Vector2i, end_cell: Vector2i) -> void:
	var x0 := mini(start.x, end_cell.x)
	var x1 := maxi(start.x, end_cell.x)
	var y0 := mini(start.y, end_cell.y)
	var y1 := maxi(start.y, end_cell.y)
	for ry in range(y0, y1 + 1):
		for rx in range(x0, x1 + 1):
			_paint_cell(Vector2i(rx, ry))


# ── Terrain map helpers ───────────────────────────────────────────────────────

func _write_terrain_pixel(cell: Vector2i, terrain_id: int, shape_id: int = 0, rot: int = 0, bg: int = 0) -> void:
	LevelDefs.write_terrain_pixel(_terrain_image, cell, terrain_id, shape_id, rot, bg)
	_terrain_dirty = true


func _flush_terrain() -> void:
	_terrain_texture.update(_terrain_image)
	_terrain_dirty = false


func _rebuild_terrain_map() -> void:
	# Rebuilds the terrain image from TileMapLayer atlas coords on initial scene
	# load (when there are no placed tiles yet).  rot and bg come from the JSON
	# save file via _do_load → _write_terrain_pixel when loading a saved level.
	_terrain_image.fill(Color(0, 0, 0, 0))
	for cell in floor_map.get_used_cells():
		var coords := floor_map.get_cell_atlas_coords(cell)
		if coords.x >= 0:
			var terrain_id: int = coords.x + 1
			var shape:      int = coords.y
			var alt:        int = floor_map.get_cell_alternative_tile(cell)
			var rot:        int = LevelDefs.ROT_ALT.find(alt)
			if rot == -1: rot = 0
			_write_terrain_pixel(cell, terrain_id, shape, rot, 0)
	_flush_terrain()


# ── Cursor refresh ────────────────────────────────────────────────────────────

func _refresh_cursor() -> void:
	if _editor_ui.active_layer == EditorUI.LAYER_FLOOR:
		cursor.texture = _editor_ui.make_preview_texture()
		cursor.rotation_degrees = 0.0
	else:
		cursor.texture = _select_texture
		cursor.rotation_degrees = _editor_ui.tile_rotation * 90.0


# ── EditorUI signal handler ───────────────────────────────────────────────────

func _on_selection_changed() -> void:
	_refresh_cursor()


# ── Save / Load ───────────────────────────────────────────────────────────────

func _make_file_dialog(mode: FileDialog.FileMode, title: String,
		callback: Callable) -> FileDialog:
	var dlg := FileDialog.new()
	dlg.file_mode = mode
	dlg.access    = FileDialog.ACCESS_FILESYSTEM
	dlg.filters   = PackedStringArray(["*.json ; Gulf Level Files"])
	dlg.title     = title
	dlg.file_selected.connect(callback)
	add_child(dlg)
	return dlg


func _open_save_dialog() -> void:
	# Re-save immediately if we already have a path; otherwise prompt.
	if not _current_path.is_empty():
		_do_save(_current_path)
	else:
		_save_dialog.popup_centered_ratio(0.6)


func _do_save(path: String) -> void:
	var floor_entries: Array = []
	for cell in floor_map.get_used_cells():
		var px := cell - LevelDefs.MAP_ORIGIN
		if px.x < 0 or px.y < 0 or px.x >= LevelDefs.MAP_SIZE or px.y >= LevelDefs.MAP_SIZE:
			continue
		var c          := _terrain_image.get_pixel(px.x, px.y)
		if c.a <= 0.5:
			continue
		var terrain_id := int(round(c.r * 255.0))
		var shape_id   := int(round(c.g * 255.0))
		var b_raw      := int(round(c.b * 255.0))
		# [cx, cy, terrain_id, shape_id, rotation, bg_terrain_id]
		floor_entries.append([cell.x, cell.y, terrain_id, shape_id, b_raw & 3, b_raw >> 2])

	var entity_entries: Array = []
	for cell in entity_map.get_used_cells():
		# Save world position — entity_map is 16-px tiles, floor_map is 32-px,
		# so cell coords are not interchangeable between the two maps.
		# Entities don't rotate, so only [world_x, world_y, source_id] is needed.
		var world := entity_map.to_global(entity_map.map_to_local(cell))
		entity_entries.append([world.x, world.y, entity_map.get_cell_source_id(cell)])

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Save failed (%s): %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify({"version": 1,
			"floor": floor_entries, "entities": entity_entries}, "\t"))
	file.close()

	_current_path = path
	get_window().title = "Gulf — " + path.get_file()


func _validate_for_play() -> String:
	var starts := 0
	var holes  := 0
	for cell in entity_map.get_used_cells():
		match entity_map.get_cell_source_id(cell):
			LevelDefs.ENTITY_SOURCE_START: starts += 1
			LevelDefs.ENTITY_SOURCE_HOLE:  holes  += 1
	if starts == 0: return "No start tile placed."
	if starts  > 1: return "Too many start tiles (%d). Place exactly one." % starts
	if holes  == 0: return "No hole tile placed."
	if holes   > 1: return "Too many hole tiles (%d). Place exactly one." % holes
	return ""


func _on_play_pressed() -> void:
	var err := _validate_for_play()
	if err != "":
		OS.alert(err, "Can't play level")
		return
	# Capture before _do_save overwrites it — temp write must not redirect future saves.
	var original_path := _current_path
	_do_save(TEMP_LEVEL_PATH)
	_current_path = original_path
	_pending_load = original_path if not original_path.is_empty() else TEMP_LEVEL_PATH
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _do_load(path: String, set_current: bool = true) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Load failed (%s): %s" % [path, error_string(FileAccess.get_open_error())])
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if not data is Dictionary or not data.has("version"):
		push_error("Load failed: not a valid Gulf level file")
		return

	floor_map.clear()
	entity_map.clear()
	_terrain_image.fill(Color(0, 0, 0, 0))

	for e in data.get("floor", []):
		var cell := Vector2i(int(e[0]), int(e[1]))
		var rot  := int(e[4])
		floor_map.set_cell(cell, 0, Vector2i(int(e[2]) - 1, int(e[3])), LevelDefs.ROT_ALT[rot])
		_write_terrain_pixel(cell, int(e[2]), int(e[3]), rot, int(e[5]))

	for e in data.get("entities", []):
		# e = [world_x, world_y, source_id]
		var world_pos := Vector2(float(e[0]), float(e[1]))
		var cell      := entity_map.local_to_map(entity_map.to_local(world_pos))
		entity_map.set_cell(cell, int(e[2]), Vector2i(0, 0), 0)

	_flush_terrain()
	if set_current:
		_current_path = path
		get_window().title = "Gulf — " + path.get_file()
