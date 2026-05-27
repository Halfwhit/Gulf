extends CanvasLayer

@onready var sidebar: PanelContainer = $Sidebar
const TILE_SET = preload("res://resources/tileset_32px.tres")
@onready var tile_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Tiles/TileContainer
var _select_image: Image = preload("uid://cibhu1schuopa")
const TILE_BUTTON_GROUP = preload("uid://we1f0yrbgg53")

signal tile_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal tile_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D)

func _ready() -> void:
	for i in TILE_SET.get_source_count():
		var source_id := TILE_SET.get_source_id(i)
		var source: TileSetAtlasSource = TILE_SET.get_source(source_id)
		var base_texture := source.texture
		var coords := source.get_tile_id(0)

		var texture_region := source.get_tile_texture_region(coords)
		var img := base_texture.get_image().get_region(texture_region)
		var tile_texture := ImageTexture.create_from_image(img)

		var pressed_image := img.duplicate()
		pressed_image.blend_rect(_select_image, _select_image.get_used_rect(), Vector2i.ZERO)
		var pressed_texture := ImageTexture.create_from_image(pressed_image)

		var icon := TileButton.new(tile_texture, pressed_texture, source_id, coords)
		icon.tile_selected.connect(_select_tile)
		icon.tile_cleared.connect(_tile_cleared)
		tile_container.add_child(icon)

func _select_tile(source_id: int, atlas_coords: Vector2i, image: Texture2D) -> void:
	tile_selected.emit(source_id, atlas_coords, image)
	$Display.texture = image

func _tile_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D) -> void:
	tile_cleared.emit(source_id, atlas_coords, image)
	if not TILE_BUTTON_GROUP.get_pressed_button():
		$Display.texture = null

func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
