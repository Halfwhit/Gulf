extends Node2D

@onready var cursor: Sprite2D = $Cursor
@onready var tile_map: TileMapLayer = $Level/TileMap
const SELECT = preload("uid://cibhu1schuopa")
var _select_texture: ImageTexture

var selected_source_id: int = -1
var selected_atlas_coords: Vector2i
var _rotation: int = 0

# Transform bit flags: TRANSPOSE=16384, FLIP_H=4096, FLIP_V=8192
const _ROT_ALT := [0, 20480, 12288, 24576]  # 0°, 90° CW, 180°, 270° CW

func _ready() -> void:
	_select_texture = ImageTexture.create_from_image(SELECT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_rotation = (_rotation + 1) % 4
		cursor.rotation_degrees = _rotation * 90.0

	if selected_source_id != -1 and event.is_action_pressed("touch_main"):
		tile_map.set_cell(
			tile_map.local_to_map(tile_map.get_local_mouse_position()),
			selected_source_id, selected_atlas_coords, _ROT_ALT[_rotation]
		)

	if event is InputEventMouseMotion:
		cursor.position = tile_map.map_to_local(tile_map.local_to_map(tile_map.get_local_mouse_position()))

func _on_editor_ui_tile_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D) -> void:
	cursor.texture = image
	selected_source_id = source_id
	selected_atlas_coords = atlas_coords

func _on_editor_ui_tile_cleared(source_id: int, atlas_coords: Vector2i, _image: Texture2D) -> void:
	if source_id == selected_source_id and atlas_coords == selected_atlas_coords:
		cursor.texture = _select_texture
