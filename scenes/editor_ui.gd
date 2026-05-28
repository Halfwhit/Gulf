extends CanvasLayer

@onready var sidebar: PanelContainer = $Sidebar
@onready var tile_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Tiles/TileContainer
@onready var wall_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Walls/WallContainer
@onready var entity_container: GridContainer = $Sidebar/VBoxContainer/MarginContainer/VSplitContainer/TabContainer/Entities/EntityContainer
const FLOOR_SET    = preload("res://resources/tileset_floor.tres")
const WALL_SET     = preload("res://resources/tileset_walls.tres")
const ENTITY_SET   = preload("res://resources/tileset_entities.tres")
const WALL_GROUP   = preload("uid://6bgai7xud4jid")
const ENTITY_GROUP = preload("uid://bm4e9x7ckqvfn")
var _select_image: Image = preload("uid://cibhu1schuopa")
var _selected_image: Image = null
var _floor_group: ButtonGroup = ButtonGroup.new()

signal tile_selected(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal tile_cleared(layer: StringName, source_id: int, atlas_coords: Vector2i, image: Texture2D)
signal terrain_selected(layer: StringName, terrain_set: int, terrain: int, image: Texture2D)
signal terrain_cleared(layer: StringName)

func _ready() -> void:
	_populate_terrains(FLOOR_SET, tile_container, &"floor")
	_populate(WALL_SET, wall_container, WALL_GROUP, &"wall")
	_populate(ENTITY_SET, entity_container, ENTITY_GROUP, &"entity")

func _populate(tileset: TileSet, container: GridContainer, group: ButtonGroup, layer: StringName) -> void:
	for i in tileset.get_source_count():
		var source_id := tileset.get_source_id(i)
		var source: TileSetAtlasSource = tileset.get_source(source_id)
		var base_image := source.texture.get_image()

		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var img := base_image.get_region(source.get_tile_texture_region(coords))
			var tile_texture := ImageTexture.create_from_image(img)

			var pressed_image := img.duplicate()
			pressed_image.blend_rect(_select_image, _select_image.get_used_rect(), Vector2i.ZERO)
			var pressed_texture := ImageTexture.create_from_image(pressed_image)

			var icon := TileButton.new(tile_texture, pressed_texture, source_id, coords, group)
			icon.tile_selected.connect(_on_tile_button_selected.bind(layer))
			icon.tile_cleared.connect(_on_tile_button_cleared.bind(layer))
			container.add_child(icon)

func set_tile_rotation(steps: int) -> void:
	if _selected_image == null:
		return
	var img := _selected_image.duplicate()
	for _i in steps:
		img.rotate_90(false)
	$Display.texture = ImageTexture.create_from_image(img)

func _on_tile_button_selected(source_id: int, atlas_coords: Vector2i, image: Texture2D, layer: StringName) -> void:
	var img_tex := image as ImageTexture
	if img_tex:
		_selected_image = img_tex.get_image()
	$Display.texture = image
	tile_selected.emit(layer, source_id, atlas_coords, image)

const _PEERING_BITS := [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
]

func _get_full_tile_image(tileset: TileSet, terrain_set: int, terrain: int) -> Image:
	var fallback: Image = null
	for i in tileset.get_source_count():
		var source := tileset.get_source(tileset.get_source_id(i)) as TileSetAtlasSource
		if not source:
			continue
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var data := source.get_tile_data(coords, 0)
			if data.terrain_set != terrain_set or data.terrain != terrain:
				continue
			var img := source.texture.get_image().get_region(source.get_tile_texture_region(coords))
			if fallback == null:
				fallback = img
			if _PEERING_BITS.all(func(b: int) -> bool: return data.get_terrain_peering_bit(b) == terrain):
				return img
	return fallback

func _populate_terrains(tileset: TileSet, container: GridContainer, layer: StringName) -> void:
	for ts in tileset.get_terrain_sets_count():
		for t in tileset.get_terrains_count(ts):
			var img := _get_full_tile_image(tileset, ts, t)
			if img == null:
				img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
				img.fill(tileset.get_terrain_color(ts, t))
			var texture := ImageTexture.create_from_image(img)
			var pressed_img := img.duplicate()
			pressed_img.blend_rect(_select_image, _select_image.get_used_rect(), Vector2i.ZERO)
			var pressed_texture := ImageTexture.create_from_image(pressed_img)
			var btn := TextureButton.new()
			btn.toggle_mode = true
			btn.texture_normal = texture
			btn.texture_pressed = pressed_texture
			btn.button_group = _floor_group
			btn.toggled.connect(_on_terrain_btn_toggled.bind(layer, ts, t, texture, img))
			container.add_child(btn)

func _on_terrain_btn_toggled(on: bool, layer: StringName, terrain_set: int, terrain: int, texture: Texture2D, img: Image) -> void:
	if on:
		_selected_image = img
		terrain_selected.emit(layer, terrain_set, terrain, texture)
		$Display.texture = texture
	else:
		terrain_cleared.emit(layer)
		if not _floor_group.get_pressed_button() and not WALL_GROUP.get_pressed_button():
			$Display.texture = null
			_selected_image = null

func _on_tile_button_cleared(source_id: int, atlas_coords: Vector2i, image: Texture2D, layer: StringName) -> void:
	tile_cleared.emit(layer, source_id, atlas_coords, image)
	if not _floor_group.get_pressed_button() and not WALL_GROUP.get_pressed_button() and not ENTITY_GROUP.get_pressed_button():
		$Display.texture = null
		_selected_image = null

func _on_panel_button_toggled(toggled_on: bool) -> void:
	sidebar.visible = toggled_on
