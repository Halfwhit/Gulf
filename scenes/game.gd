extends Node2D

const PLAYER_SCENE   = preload("res://scenes/player.tscn")
const TERRAIN_SHADER = preload("res://shaders/terrain_blend.gdshader")
const FLOOR_TILESET  = preload("res://resources/tileset_floor.tres")
const HOLE_TEXTURE   = preload("res://assets/hole.png")

var _floor_map:       TileMapLayer
var _terrain_image:   Image
var _terrain_texture: ImageTexture
var _camera:          Camera2D
var _player:          RigidBody2D
var _hole_pos:        Vector2
var _shots_label:     Label
var _status_label:    Label
var _shots:           int  = 0
var _level_complete:  bool = false
var _ball_in_hole:    bool = false   # true while ball overlaps the hole area


func _ready() -> void:
	_build_floor_map()
	_build_ui()
	_load_level()


# ── Scene construction ────────────────────────────────────────────────────────

func _build_floor_map() -> void:
	_terrain_image   = Image.create(LevelDefs.MAP_SIZE, LevelDefs.MAP_SIZE, false, Image.FORMAT_RGBA8)
	_terrain_texture = ImageTexture.create_from_image(_terrain_image)

	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("terrain_map", _terrain_texture)
	mat.set_shader_parameter("map_origin",  Vector2(LevelDefs.MAP_ORIGIN))
	mat.set_shader_parameter("map_dims",    Vector2(LevelDefs.MAP_SIZE, LevelDefs.MAP_SIZE))
	mat.set_shader_parameter("tile_px",     float(LevelDefs.TILE_PX))
	mat.set_shader_parameter("pixel_size",  1.0)

	_floor_map = TileMapLayer.new()
	_floor_map.tile_set = FLOOR_TILESET
	_floor_map.material = mat
	add_child(_floor_map)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_left",   8)
	margin.add_theme_constant_override("margin_right",  8)
	margin.add_theme_constant_override("margin_bottom", 8)
	ui.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)

	var back_btn := Button.new()
	back_btn.text = "◀ Back to Editor"
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

	_shots_label = Label.new()
	_shots_label.text = "Shots: 0"
	vbox.add_child(_shots_label)

	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)


# ── Level loading ─────────────────────────────────────────────────────────────

func _load_level() -> void:
	var file := FileAccess.open("user://temp_level.json", FileAccess.READ)
	if file == null:
		push_error("Game: could not open temp level")
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		push_error("Game: invalid level data")
		return

	_terrain_image.fill(Color(0, 0, 0, 0))
	for e in data.get("floor", []):
		var cell       := Vector2i(int(e[0]), int(e[1]))
		var terrain_id := int(e[2])
		var shape_id   := int(e[3])
		var rot        := int(e[4])
		var bg         := int(e[5])
		_floor_map.set_cell(cell, 0, Vector2i(terrain_id - 1, shape_id), LevelDefs.ROT_ALT[rot])
		LevelDefs.write_terrain_pixel(_terrain_image, cell, terrain_id, shape_id, rot, bg)
	_terrain_texture.update(_terrain_image)

	# Entities stored as [world_x, world_y, source_id].
	var start_world := Vector2.ZERO
	_hole_pos = Vector2.ZERO
	for e in data.get("entities", []):
		var world_pos := Vector2(float(e[0]), float(e[1]))
		if   int(e[2]) == LevelDefs.ENTITY_SOURCE_START: start_world = world_pos
		elif int(e[2]) == LevelDefs.ENTITY_SOURCE_HOLE:  _hole_pos   = world_pos

	_spawn_player(start_world)
	_spawn_hole(_hole_pos)


func _spawn_player(world_pos: Vector2) -> void:
	_player = PLAYER_SCENE.instantiate()
	add_child(_player)
	_player.position = world_pos

	_camera = Camera2D.new()
	_camera.zoom = Vector2.ONE
	_player.add_child(_camera)

	# play_turn() sets line_visible, enables collision, and awaits turn_taken.
	# _on_turn_taken re-calls it each time the ball stops, keeping the loop going.
	_player.z_index = 2
	_player.turn_taken.connect(_on_turn_taken)
	_player.play_turn()


func _spawn_hole(world_pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.position = world_pos
	sprite.texture  = HOLE_TEXTURE
	sprite.z_index  = 1
	add_child(sprite)

	# Detection area — layer 4, detects player on layer 2.
	var area := Area2D.new()
	area.collision_layer = 4
	area.collision_mask  = 2
	area.position = world_pos
	add_child(area)
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 4.0
	col.shape = circ
	area.add_child(col)
	area.body_entered.connect(_on_hole_body_entered)
	area.body_exited.connect(_on_hole_body_exited)


# ── Turn cycle ────────────────────────────────────────────────────────────────

func _on_turn_taken() -> void:
	_shots += 1
	_shots_label.text = "Shots: %d" % _shots
	# Check holed AFTER the ball stops — ball must come to rest inside the area.
	if _ball_in_hole:
		_level_complete    = true
		_status_label.text = "Hole in %d shot%s! 🎉" % \
				[_shots, "" if _shots == 1 else "s"]
		return
	_player.play_turn()


# ── Hole detection ────────────────────────────────────────────────────────────

func _on_hole_body_entered(body: Node) -> void:
	if body != _player:
		return
	_ball_in_hole = true
	# If the ball rolls slowly into the hole, stop it so it registers as holed
	# when turn_taken fires.  Fast balls that clip the area continue rolling.
	if _player.ball_vector.length() <= 50.0:
		_player.ball_vector = Vector2.ZERO


func _on_hole_body_exited(body: Node) -> void:
	if body == _player:
		_ball_in_hole = false


# ── Back button ───────────────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")
