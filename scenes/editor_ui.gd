extends CanvasLayer

@onready var sidebar: PanelContainer = $Sidebar
const TILE_SET = preload("uid://cfiust4nsjpbw")
@onready var tile_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Tiles/TileContainer
var select_texture = preload("uid://c7b24ju1owk1o")

func _ready() -> void:
	var layer_source = TILE_SET.get_source(0)
	var texture_source: TileSetAtlasSource = layer_source
	for id in layer_source.get_tiles_count():
		var coords: Vector2i = layer_source.get_tile_id(id)
		var texture = texture_source.texture
		var texture_region = texture_source.get_tile_texture_region(coords)
		var img = texture_source.texture.get_image().get_region(texture_region)
		var tile_texture = ImageTexture.create_from_image(img)
		
		var pressed_image = img.duplicate()
		pressed_image.blend_rect(select_texture, pressed_image.get_used_rect(), Vector2i.ZERO)
		var pressed_texture = ImageTexture.create_from_image(pressed_image)
		
		var icon = TileButton.new(tile_texture, pressed_texture, coords)
		icon.connect("tile_selected", _select_tile)
		tile_container.add_child(icon)
		tile_container.sort_children.emit()

func _select_tile(atlas_coords: Vector2i):
	print(atlas_coords)

func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
