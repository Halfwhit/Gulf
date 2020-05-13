extends Control

onready var ground = $Level/Ground
onready var walls = $Level/Walls
onready var entities = $Level/Entities

var selected_tile_name = "grass" # Defaukl
var selected_tile
var tile_id
var tile_name

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				# Get which tile is under the mouse
				var mouse_pos = ground.get_local_mouse_position()
				var cell_pos = ground.world_to_map(mouse_pos)
				tile_id = ground.get_cellv(cell_pos)
				tile_name = ground.tile_set.tile_get_name(tile_id)
				# Do stuff according to the above
				if tile_name != selected_tile_name:
					# For example, turn the tile into a wall tile when clicked
					var selected_tile_id = ground.tile_set.find_tile_by_name(selected_tile_name)
					ground.set_cellv(cell_pos, selected_tile_id)
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				# Get which tile is under the mouse
				var mouse_pos = ground.get_local_mouse_position()
				var cell_pos = ground.world_to_map(mouse_pos)
				tile_id = ground.get_cellv(cell_pos)
				if tile_id != -1:
					ground.set_cellv(cell_pos, -1)


func _on_TileVariant_tile_selected(tile) -> void:
	selected_tile = ground.tile_set.find_tile_by_name(tile)
