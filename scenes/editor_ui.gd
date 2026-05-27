extends CanvasLayer

@onready var sidebar: PanelContainer = $Sidebar
@onready var tile_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Tiles/TileContainer
@onready var wall_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Walls/WallContainer
const FLOOR_SET = preload("res://resources/tileset_floor_32px.tres")
const WALL_SET  = preload("res://resources/tileset_walls_32px.tres")
const FLOOR_GROUP = preload("uid://we1f0yrbgg53")
const WALL_GROUP  = preload("uid://6bgai7xud4jid")
var _select_image: Image = preload("uid://cibhu1schuopa")

signal tile_selected(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal tile_cleared(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)

func _ready() -> void:
	_populate(FLOOR_SET, tile_container, FLOOR_GROUP, &"floor")
	_populate(WALL_SET,  wall_container, WALL_GROUP,  &"wall")

func _populate(tileset: TileSet, container: GridContainer, group: ButtonGroup, layer: StringName) -> void:
	for i in tileset.get_source_count():
		var source_id := tileset.get_source_id(i)
		var source: TileSetAtlasSource = tileset.get_source(source_id)
		var coords := source.get_tile_id(0)

		var img := source.texture.get_image().get_region(source.get_tile_texture_region(coords))
		var tile_texture := ImageTexture.create_from_image(img)

		var pressed_image := img.duplicate()
		pressed_image.blend_rect(_select_image, _select_image.get_used_rect(), Vector2i.ZERO)
		var pressed_texture := ImageTexture.create_from_image(pressed_image)

		var icon := TileButton.new(tile_texture, pressed_texture, source_id, coords, group)
		icon.tile_selected.connect(_on_tile_button_selected.bind(layer))
		icon.tile_cleared.connect(_on_tile_button_cleared.bind(layer))
		container.add_child(icon)

func _on_tile_button_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D, layer: StringName) -> void:
	tile_selected.emit(layer, source_id, atlas_coords, image)
	$Display.texture = image

func _on_tile_button_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D, layer: StringName) -> void:
	tile_cleared.emit(layer, source_id, atlas_coords, image)
	if not FLOOR_GROUP.get_pressed_button() and not WALL_GROUP.get_pressed_button():
		$Display.texture = null

func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
