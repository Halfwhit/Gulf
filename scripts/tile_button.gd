extends TextureButton
class_name TileButton

var texture_coords
const TILE_BUTTON_GROUP = preload("uid://we1f0yrbgg53")

signal tile_selected(texture_coords)

func _init(normal_texture, pressed_texture, coords) -> void:
	toggle_mode = true
	texture_normal = normal_texture
	texture_pressed = pressed_texture
	texture_coords = coords
	button_group = TILE_BUTTON_GROUP
	connect("toggled", _on_toggled)

func _on_toggled(toggled_on: bool):
	if toggled_on:
		tile_selected.emit(texture_coords)
