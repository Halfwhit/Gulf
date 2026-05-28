extends CanvasLayer

@onready var sidebar: PanelContainer = $Sidebar
@onready var tile_container: GridContainer   = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Tiles/TileContainer
@onready var wall_container: GridContainer   = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Walls/WallContainer
@onready var entity_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Entities/EntityContainer

const FLOOR_SET    = preload("res://resources/tileset_floor.tres")
const WALL_SET     = preload("res://resources/tileset_walls.tres")
const ENTITY_SET   = preload("res://resources/tileset_entities.tres")
const WALL_GROUP   = preload("uid://6bgai7xud4jid")
const ENTITY_GROUP = preload("uid://bm4e9x7ckqvfn")

var _selected_image: Image  = null
var _floor_group: ButtonGroup = ButtonGroup.new()

signal tile_selected(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal tile_cleared(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)


func _ready() -> void:
	_populate(FLOOR_SET,   tile_container,   _floor_group, &"floor")
	_populate(WALL_SET,    wall_container,   WALL_GROUP,   &"wall")
	_populate(ENTITY_SET,  entity_container, ENTITY_GROUP, &"entity")


static func _make_select_overlay(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	const ARM := 2
	for i in ARM:
		img.set_pixel(i, 0, Color.WHITE)
		img.set_pixel(0, i, Color.WHITE)
		img.set_pixel(width - 1 - i, 0, Color.WHITE)
		img.set_pixel(width - 1, i, Color.WHITE)
		img.set_pixel(i, height - 1, Color.WHITE)
		img.set_pixel(0, height - 1 - i, Color.WHITE)
		img.set_pixel(width - 1 - i, height - 1, Color.WHITE)
		img.set_pixel(width - 1, height - 1 - i, Color.WHITE)
	return img


func _populate(tileset: TileSet, container: GridContainer, group: ButtonGroup, tile_layer: StringName) -> void:
	for i in tileset.get_source_count():
		var source_id := tileset.get_source_id(i)
		var source := tileset.get_source(source_id) as TileSetAtlasSource
		if not source:
			continue
		var base_image := source.texture.get_image()

		for j in source.get_tiles_count():
			var coords  := source.get_tile_id(j)
			var img     := base_image.get_region(source.get_tile_texture_region(coords))
			img.convert(Image.FORMAT_RGBA8)
			var texture := ImageTexture.create_from_image(img)

			var overlay      := _make_select_overlay(img.get_width(), img.get_height())
			var pressed_img  := img.duplicate()
			pressed_img.blend_rect(overlay, overlay.get_used_rect(), Vector2i.ZERO)
			var pressed_tex  := ImageTexture.create_from_image(pressed_img)

			var btn := TileButton.new(texture, pressed_tex, source_id, coords, group)
			btn.tile_selected.connect(_on_tile_button_selected.bind(tile_layer))
			btn.tile_cleared.connect(_on_tile_button_cleared.bind(tile_layer))
			container.add_child(btn)


func set_tile_rotation(steps: int) -> void:
	if _selected_image == null:
		return
	var img := _selected_image.duplicate()
	for _i in steps:
		img.rotate_90(false)
	$Display.texture = ImageTexture.create_from_image(img)


func _on_tile_button_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D, tile_layer: StringName) -> void:
	var img_tex := image as ImageTexture
	if img_tex:
		_selected_image = img_tex.get_image()
	$Display.texture = image
	tile_selected.emit(tile_layer, source_id, atlas_coords, image)


func _on_tile_button_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D, tile_layer: StringName) -> void:
	tile_cleared.emit(tile_layer, source_id, atlas_coords, image)
	if (not _floor_group.get_pressed_button()
			and not WALL_GROUP.get_pressed_button()
			and not ENTITY_GROUP.get_pressed_button()):
		$Display.texture = null
		_selected_image  = null


func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
