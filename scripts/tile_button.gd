extends TextureButton
class_name TileButton

var source_id: int
var atlas_coords: Vector2i
const TILE_BUTTON_GROUP = preload("uid://we1f0yrbgg53")

signal tile_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal tile_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D)

func _init(normal_texture: Texture2D, pressed_texture: Texture2D, _source_id: int, _atlas_coords: Vector2i) -> void:
	toggle_mode = true
	texture_normal = normal_texture
	texture_pressed = pressed_texture
	source_id = _source_id
	atlas_coords = _atlas_coords
	button_group = TILE_BUTTON_GROUP
	connect("toggled", _on_toggled)

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		tile_selected.emit(source_id, atlas_coords, texture_normal)
	else:
		tile_cleared.emit(source_id, atlas_coords, texture_normal)
