extends Control

onready var ground = $Level/Ground
onready var walls = $Level/Walls
onready var entities = $Level/Entities
onready var mouse = $Mouse
onready var tile_selector = $CanvasLayer/TileSelector

var selected_tile = 0
var mouse_rot: float = 0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				# Get which tile is under the mouse
				var mouse_pos = ground.get_local_mouse_position()
				var cell_pos = ground.world_to_map(mouse_pos)
				if is_equal_approx(0, mouse_rot):
					ground.set_cellv(cell_pos, selected_tile, false, false, false)
				elif is_equal_approx(PI * 0.5, mouse_rot):
					ground.set_cellv(cell_pos, selected_tile, true, false, true)
				elif is_equal_approx(PI * 1.0, mouse_rot):
					ground.set_cellv(cell_pos, selected_tile, true, true, false)
				elif is_equal_approx(PI * 1.5, mouse_rot):
					ground.set_cellv(cell_pos, selected_tile, false, true, true)
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				# Get which tile is under the mouse
				var mouse_pos = ground.get_local_mouse_position()
				var cell_pos = ground.world_to_map(mouse_pos)
				ground.set_cellv(cell_pos, -1)
	if event is InputEventMouseMotion:
		var mouse_pos = ground.get_local_mouse_position()
		var cell_pos = ground.world_to_map(mouse_pos)
		mouse.position.x = cell_pos.x * ground.cell_size.x + ground.cell_size.x/2
		mouse.position.y = cell_pos.y * ground.cell_size.y + ground.cell_size.y/2
		var sprite_pos = mouse.position
		sprite_pos.snapped(Vector2(16, 16))
	if event.is_action_pressed("rotate_right"):
		if mouse_rot < (1.5 * PI):
			mouse_rot += PI/2
		else:
			mouse_rot = 0
		mouse.rotation = mouse_rot
	if event.is_action_pressed("rotate_left"):
		if is_equal_approx(mouse_rot, 0.0):
			mouse_rot = PI * 1.5
		else:
			mouse_rot -= PI/2
		mouse.rotation = mouse_rot
			

func _on_TileSelector_tile_selected(id) -> void:
	selected_tile = id
	mouse.texture = ground.tile_set.tile_get_texture(id)
