extends Control

onready var mouse = $Mouse
var mouse_rot: float = 0
var mouse_editor: bool = false

onready var tile_selector = $CanvasLayer/TileSelector

onready var ground = $Level/Ground
onready var walls = $Level/Walls
onready var entities = $Level/Entities
var selected_tile = 0
var selected_layer = 0
var current_tilemap

enum Layer {
	GROUND
	WALLS
	ENTITIES
	EMPTY
}

func _ready() -> void:
	mouse.texture = ground.tile_set.tile_get_texture(selected_tile)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("rotate_right"):
		if mouse_rot < (1.5 * PI):
			mouse_rot += PI/2
		else:
			mouse_rot = 0
		mouse.rotation = mouse_rot
	if Input.is_action_just_pressed("rotate_left"):
		if is_equal_approx(mouse_rot, 0.0):
			mouse_rot = PI * 1.5
		else:
			mouse_rot -= PI/2
		mouse.rotation = mouse_rot

func _gui_input(event: InputEvent) -> void:
	if Input.is_action_pressed("left_click"):
		match selected_layer:
			Layer.GROUND:
				place_ground()
			Layer.WALLS:
				place_walls()
			Layer.ENTITIES:
				place_entities()
	if Input.is_action_pressed("right_click"):
		match selected_layer:
			Layer.GROUND:
				remove_ground()
			Layer.WALLS:
				remove_walls()
			Layer.ENTITIES:
				remove_entities()
	if event is InputEventMouseMotion:
		if selected_layer != Layer.ENTITIES:
			var mouse_pos = ground.get_local_mouse_position()
			var cell_pos = ground.world_to_map(mouse_pos)
			mouse.position.x = cell_pos.x * ground.cell_size.x + ground.cell_size.x/2
			mouse.position.y = cell_pos.y * ground.cell_size.y + ground.cell_size.y/2
			var sprite_pos = mouse.position
			sprite_pos.snapped(Vector2(16, 16))
		else:
			var mouse_pos = entities.get_local_mouse_position()
			var cell_pos = entities.world_to_map(mouse_pos)
			mouse.position.x = cell_pos.x * entities.cell_size.x + entities.cell_size.x
			mouse.position.y = cell_pos.y * entities.cell_size.y + entities.cell_size.y
			var sprite_pos = mouse.position
			sprite_pos.snapped(Vector2(8, 8))

func place_ground():
	var mouse_pos = ground.get_local_mouse_position()
	var cell_pos = ground.world_to_map(mouse_pos)
	# Set tile rotation based on mouse widget rotation
	if is_equal_approx(0, mouse_rot):
		ground.set_cellv(cell_pos, selected_tile, false, false, false) # 0 degrees / 0 radians
	elif is_equal_approx(PI * 0.5, mouse_rot):
		ground.set_cellv(cell_pos, selected_tile, true, false, true) # 90 degrees / 0.5 radians 
	elif is_equal_approx(PI * 1.0, mouse_rot):
		ground.set_cellv(cell_pos, selected_tile, true, true, false) # 180 degrees / 1 radian
	elif is_equal_approx(PI * 1.5, mouse_rot):
		ground.set_cellv(cell_pos, selected_tile, false, true, true) # 270 degrees / 1.5 radians
func place_walls():
	var mouse_pos = walls.get_local_mouse_position()
	var cell_pos = walls.world_to_map(mouse_pos)
	# Set tile rotation based on mouse widget rotation
	if is_equal_approx(0, mouse_rot):
		walls.set_cellv(cell_pos, selected_tile, false, false, false) # 0 degrees / 0 radians
	elif is_equal_approx(PI * 0.5, mouse_rot):
		walls.set_cellv(cell_pos, selected_tile, true, false, true) # 90 degrees / 0.5 radians 
	elif is_equal_approx(PI * 1.0, mouse_rot):
		walls.set_cellv(cell_pos, selected_tile, true, true, false) # 180 degrees / 1 radian
	elif is_equal_approx(PI * 1.5, mouse_rot):
		walls.set_cellv(cell_pos, selected_tile, false, true, true) # 270 degrees / 1.5 radians
func place_entities():
	var mouse_pos = entities.get_local_mouse_position()
	var cell_pos = entities.world_to_map(mouse_pos)
	# Set tile rotation based on mouse widget rotation
	if is_equal_approx(0, mouse_rot):
		entities.set_cellv(cell_pos, selected_tile, false, false, false) # 0 degrees / 0 radians
	elif is_equal_approx(PI * 0.5, mouse_rot):
		entities.set_cellv(cell_pos, selected_tile, true, false, true) # 90 degrees / 0.5 radians 
	elif is_equal_approx(PI * 1.0, mouse_rot):
		entities.set_cellv(cell_pos, selected_tile, true, true, false) # 180 degrees / 1 radian
	elif is_equal_approx(PI * 1.5, mouse_rot):
		entities.set_cellv(cell_pos, selected_tile, false, true, true) # 270 degrees / 1.5 radians
func remove_ground():
	var mouse_pos = ground.get_local_mouse_position()
	var cell_pos = ground.world_to_map(mouse_pos)
	ground.set_cellv(cell_pos, -1)
func remove_walls():
	var mouse_pos = walls.get_local_mouse_position()
	var cell_pos = walls.world_to_map(mouse_pos)
	walls.set_cellv(cell_pos, -1)
func remove_entities():
	var mouse_pos = entities.get_local_mouse_position()
	var cell_pos = entities.world_to_map(mouse_pos)
	entities.set_cellv(cell_pos, -1)

func _on_TileSelector_tile_selected(layer, id: int) -> void:
	selected_tile = id
	selected_layer = layer
	match layer:
		Layer.GROUND:
			mouse.texture = ground.tile_set.tile_get_texture(id)
		Layer.WALLS:
			mouse.texture = walls.tile_set.tile_get_texture(id)
		Layer.ENTITIES:
			mouse.texture = entities.tile_set.tile_get_texture(id)

func _on_TabContainer_tab_changed(tab: int) -> void:
	selected_layer = tab
