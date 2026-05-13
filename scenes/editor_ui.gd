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
		
		var icon = TextureButton.new()
		icon.texture_normal = tile_texture
		icon.texture_focused = select_texture
		icon.focus_mode = Control.FOCUS_ALL
		icon.connect("pressed", _debug)
		tile_container.add_child(icon)

func _debug():
	print("Debugging")

func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
