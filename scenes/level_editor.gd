extends Node2D

@onready var cursor: Sprite2D = $Cursor
@onready var tile_map: TileMapLayer = $Level/TileMap
const SELECT = preload("uid://c7b24ju1owk1o")

var selected_source_id
var selected_atlas_coords

func _input(event: InputEvent) -> void:
	if selected_source_id != null:
		if selected_atlas_coords != null:
			if event.is_action_pressed("touch_main"):
				var mouse_pos = tile_map.get_local_mouse_position()
				var cell_pos = tile_map.local_to_map(mouse_pos)
				if cell_pos != null:
					print(cell_pos)
					tile_map.set_cell(cell_pos, selected_source_id, selected_atlas_coords)
		
	if event is InputEventMouseMotion:
		var mouse_pos = tile_map.get_local_mouse_position()
		var cell_pos = tile_map.local_to_map(mouse_pos)
		@warning_ignore("integer_division")
		cursor.position.x = cell_pos.x * tile_map.tile_set.tile_size.x + tile_map.tile_set.tile_size.x/2
		@warning_ignore("integer_division")
		cursor.position.y = cell_pos.y * tile_map.tile_set.tile_size.y + tile_map.tile_set.tile_size.y/2

func _on_editor_ui_tile_selected(source_id: Variant, atlas_coords: Variant, image: Variant) -> void:
	cursor.texture = image
	selected_source_id = source_id
	selected_atlas_coords = atlas_coords


func _on_editor_ui_tile_cleared(source_id: Variant, atlas_coords: Variant, _image: Variant) -> void:
	if source_id == selected_source_id:
		if atlas_coords == selected_atlas_coords:
			cursor.texture = ImageTexture.create_from_image(SELECT)
