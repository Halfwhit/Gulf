class_name EditorUI
extends CanvasLayer

# ── Public state read by level_editor ─────────────────────────────────────────
var active_tool: int         = 0   # TOOL_BRUSH / TOOL_ERASE / TOOL_FILL_RECT
var active_layer: StringName = LAYER_FLOOR
var fg_source_id: int        = 0   # 0–6  (column in tileset_floor.png)
var selected_shape: int      = 0   # 0–15
var tile_rotation: int       = 0   # 0–3
var bg_source_id: int        = 0   # 0–6

var entity_source_id: int        = -1
var entity_atlas_coords: Vector2i = Vector2i.ZERO

signal selection_changed()
signal save_requested()
signal load_requested()
signal play_requested()

# ── Constants ─────────────────────────────────────────────────────────────────
const TOOL_BRUSH     := 0
const TOOL_ERASE     := 1
const TOOL_FILL_RECT := 2

const LAYER_FLOOR:  StringName = &"floor"
const LAYER_ENTITY: StringName = &"entity"

const _MASK_SZ := 32   # resolution of precomputed shape bitmasks

const TERRAIN_NAMES: Array[String] = [
	"Fairway", "Green", "LightMud", "DarkMud", "Water", "Acid", "Wall"
]
const TERRAIN_COLORS: Array[Color] = [
	Color(0.220, 0.718, 0.392),
	Color(0.655, 0.941, 0.439),
	Color(0.706, 0.549, 0.314),
	Color(0.471, 0.353, 0.196),
	Color(0.439, 0.702, 0.941),
	Color(0.941, 0.922, 0.439),
	Color(0.353, 0.333, 0.314),
]
const SHAPE_NAMES: Array[String] = [
	"Rect", "Diagonal", "Curve", "Curve Inv",
	"Half", "Diamond", "Circle",
]

const ENTITY_SET   = preload("res://resources/tileset_entities.tres")
const ENTITY_GROUP = preload("uid://bm4e9x7ckqvfn")

# ── Scene nodes ───────────────────────────────────────────────────────────────
@onready var _main_row:  HBoxContainer = $TopBar/VBox/MainRow
@onready var _bg_row:    HBoxContainer = $TopBar/VBox/BgRow
@onready var _shape_row: HBoxContainer = $BottomBar/ShapeRow

# ── Internal button arrays ────────────────────────────────────────────────────
var _tool_buttons:   Array[Button] = []
var _fg_buttons:     Array[Button] = []
var _shape_buttons:  Array[Button] = []
var _bg_buttons:     Array[Button] = []
var _rot_button:     Button        = null

# Precomputed shape bitmasks: 16 shapes × 4 rotations → PackedByteArray[_MASK_SZ²]
# Index as [shape * 4 + rot]. Eliminates per-pixel _shape_inside calls in make_preview_texture.
var _shape_masks: Array[PackedByteArray] = []

# Cached preview image and texture — reused across make_preview_texture() calls
# to avoid allocating a new Image + ImageTexture on every selection change.
var _preview_image:   Image        = null
var _preview_texture: ImageTexture = null


func _ready() -> void:
	_build_ui()


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Precompute shape bitmasks at all 4 rotations so make_preview_texture avoids
	# calling _shape_inside 1024 times on every selection change.
	_shape_masks.resize(SHAPE_NAMES.size() * 4)
	for si in SHAPE_NAMES.size():
		for ri in 4:
			var mask := PackedByteArray()
			mask.resize(_MASK_SZ * _MASK_SZ)
			for py in _MASK_SZ:
				for px in _MASK_SZ:
					var uv := _rotated_uv(
						Vector2(float(px) / (_MASK_SZ - 1.0), float(py) / (_MASK_SZ - 1.0)), ri)
					mask[py * _MASK_SZ + px] = 1 if _shape_inside(uv, si) else 0
			_shape_masks[si * 4 + ri] = mask

	# ── Top bar: tools | separator | terrain swatches | rot | [bg label+swatches] ──

	# Tool buttons: B E F
	for i in 3:
		var btn := _make_tool_btn(i)
		_main_row.add_child(btn)
		_tool_buttons.append(btn)
	_tool_buttons[0].set_pressed_no_signal(true)

	_add_vsep(_main_row)

	# Terrain swatches (fg)
	for i in TERRAIN_COLORS.size():
		var btn := _make_swatch(i)
		btn.toggled.connect(func(on: bool) -> void: _on_fg_toggled(i, on))
		_main_row.add_child(btn)
		_fg_buttons.append(btn)
	_fg_buttons[0].set_pressed_no_signal(true)

	_add_vsep(_main_row)

	# Rotation button
	_rot_button = Button.new()
	_rot_button.text = "0°"
	_rot_button.custom_minimum_size = Vector2(36, 0)
	_rot_button.tooltip_text = "Rotate tile (R)"
	_rot_button.pressed.connect(_on_rot_pressed)
	_main_row.add_child(_rot_button)

	# Entity section
	_add_vsep(_main_row)
	var ent_lbl := Label.new()
	ent_lbl.text = "Entities:"
	ent_lbl.add_theme_font_size_override("font_size", 11)
	_main_row.add_child(ent_lbl)
	_populate_entity_buttons(_main_row)

	# Save / Load buttons
	_add_vsep(_main_row)
	for pair in [["Save", "Save level (Ctrl+S)", func(): save_requested.emit()],
				 ["Load", "Load level (Ctrl+O)", func(): load_requested.emit()],
				 ["▶ Play", "Play level (Ctrl+P)", func(): play_requested.emit()]]:
		var btn := Button.new()
		btn.text         = pair[0]
		btn.tooltip_text = pair[1]
		btn.pressed.connect(pair[2])
		_main_row.add_child(btn)

	# ── BG row (shown only when shape ≠ 0) ───────────────────────────────────
	var bg_lbl := Label.new()
	bg_lbl.text = "BG:"
	bg_lbl.add_theme_font_size_override("font_size", 11)
	_bg_row.add_child(bg_lbl)

	for i in TERRAIN_COLORS.size():
		var btn := _make_swatch(i)
		btn.toggled.connect(func(on: bool) -> void: _on_bg_toggled(i, on))
		_bg_row.add_child(btn)
		_bg_buttons.append(btn)
	_bg_buttons[0].set_pressed_no_signal(true)

	# ── Bottom bar: shape buttons (shapes 7-15 removed until fixed) ─────────────
	for i in SHAPE_NAMES.size():
		var btn := _make_shape_btn(i)
		_shape_row.add_child(btn)
		_shape_buttons.append(btn)
	_shape_buttons[0].set_pressed_no_signal(true)


# ── Widget helpers ────────────────────────────────────────────────────────────

func _make_tool_btn(idx: int) -> Button:
	var names := ["B", "E", "F"]
	var tips  := ["Brush", "Erase", "Fill Rect"]
	var btn := Button.new()
	btn.text = names[idx]
	btn.tooltip_text = tips[idx]
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(28, 0)
	btn.toggled.connect(func(on: bool) -> void: _on_tool_toggled(idx, on))
	return btn


func _make_swatch(src_idx: int) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(24, 24)
	btn.tooltip_text = TERRAIN_NAMES[src_idx]
	var style := StyleBoxFlat.new()
	style.bg_color = TERRAIN_COLORS[src_idx]
	style.set_border_width_all(1)
	style.border_color = Color(0, 0, 0, 0.5)
	btn.add_theme_stylebox_override("normal", style)
	var pressed_style := style.duplicate()
	pressed_style.border_color = Color.WHITE
	pressed_style.set_border_width_all(2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	return btn


func _make_shape_btn(shape_idx: int) -> Button:
	const sz    := _MASK_SZ
	const fill_c  := Color(0.9, 0.9, 0.9, 1.0)
	const empty_c := Color(0.2, 0.2, 0.2, 1.0)
	var img  := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var mask := _shape_masks[shape_idx * 4]  # rotation 0
	for py in sz:
		for px in sz:
			img.set_pixel(px, py, fill_c if mask[py * sz + px] != 0 else empty_c)
	var tex := ImageTexture.create_from_image(img)
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(28, 28)
	btn.icon = tex
	btn.expand_icon = true
	btn.tooltip_text = SHAPE_NAMES[shape_idx]
	btn.toggled.connect(func(on: bool) -> void: _on_shape_toggled(shape_idx, on))
	return btn


static func _add_vsep(parent: HBoxContainer) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	parent.add_child(sep)


# ── Entity palette ────────────────────────────────────────────────────────────

func _populate_entity_buttons(parent: HBoxContainer) -> void:
	for i in ENTITY_SET.get_source_count():
		var source_id := ENTITY_SET.get_source_id(i)
		var source := ENTITY_SET.get_source(source_id) as TileSetAtlasSource
		if not source:
			continue
		var base_image := source.texture.get_image()
		for j in source.get_tiles_count():
			var coords := source.get_tile_id(j)
			var region  := source.get_tile_texture_region(coords)
			var img     := base_image.get_region(region)
			img.convert(Image.FORMAT_RGBA8)
			var small := img.duplicate()
			small.resize(24, 24, Image.INTERPOLATE_NEAREST)
			var tex         := ImageTexture.create_from_image(small)
			var pressed_img := small.duplicate()
			_apply_select_overlay(pressed_img)
			var pressed_tex := ImageTexture.create_from_image(pressed_img)
			var btn := TileButton.new(tex, pressed_tex, source_id, coords, ENTITY_GROUP)
			btn.tile_selected.connect(_on_entity_selected.bind(&"entity"))
			btn.tile_cleared.connect(_on_entity_cleared.bind(&"entity"))
			btn.custom_minimum_size = Vector2(28, 28)
			parent.add_child(btn)


static func _apply_select_overlay(img: Image) -> void:
	const ARM := 2
	var w := img.get_width(); var h := img.get_height()
	for i in ARM:
		img.set_pixel(i, 0, Color.WHITE); img.set_pixel(0, i, Color.WHITE)
		img.set_pixel(w-1-i, 0, Color.WHITE); img.set_pixel(w-1, i, Color.WHITE)
		img.set_pixel(i, h-1, Color.WHITE); img.set_pixel(0, h-1-i, Color.WHITE)
		img.set_pixel(w-1-i, h-1, Color.WHITE); img.set_pixel(w-1, h-1-i, Color.WHITE)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _deselect_others(buttons: Array[Button], idx: int) -> void:
	for i in buttons.size():
		if i != idx: buttons[i].set_pressed_no_signal(false)


func _on_tool_toggled(idx: int, on: bool) -> void:
	if not on: return
	_deselect_others(_tool_buttons, idx)
	active_tool = idx
	selection_changed.emit()


func _on_fg_toggled(idx: int, on: bool) -> void:
	if not on: return
	_deselect_others(_fg_buttons, idx)
	fg_source_id = idx
	active_layer = LAYER_FLOOR
	# Depress any active entity button so the two groups stay in sync.
	var pressed := ENTITY_GROUP.get_pressed_button()
	if pressed: pressed.set_pressed_no_signal(false)
	entity_source_id = -1
	selection_changed.emit()


func _on_shape_toggled(idx: int, on: bool) -> void:
	if not on: return
	_deselect_others(_shape_buttons, idx)
	selected_shape = idx
	var shaped := (idx != 0)
	_bg_row.visible = shaped
	if not shaped:
		tile_rotation = 0
		_rot_button.text = "0°"
	selection_changed.emit()


func _on_rot_pressed() -> void:
	tile_rotation = (tile_rotation + 1) % 4
	const LABELS := ["0°", "90°", "180°", "270°"]
	_rot_button.text = LABELS[tile_rotation]
	selection_changed.emit()


func _on_bg_toggled(idx: int, on: bool) -> void:
	if not on: return
	_deselect_others(_bg_buttons, idx)
	bg_source_id = idx
	selection_changed.emit()


func _on_entity_selected(source_id: int, atlas_coords: Vector2i,
		_image: Texture2D, _layer: StringName) -> void:
	active_layer = LAYER_ENTITY
	entity_source_id    = source_id
	entity_atlas_coords = atlas_coords
	selection_changed.emit()


func _on_entity_cleared(_source_id: int, _atlas_coords: Vector2i,
		_image: Texture2D, _layer: StringName) -> void:
	entity_source_id = -1
	active_layer = LAYER_FLOOR
	selection_changed.emit()


# ── R key: cycle rotation ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if selected_shape > 0 or active_layer == LAYER_ENTITY:
			_on_rot_pressed()
			get_viewport().set_input_as_handled()


# ── Preview texture (cursor) ──────────────────────────────────────────────────

func make_preview_texture() -> ImageTexture:
	const sz   := _MASK_SZ
	if _preview_image == null:
		_preview_image   = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		_preview_texture = ImageTexture.create_from_image(_preview_image)
	var fg     := TERRAIN_COLORS[fg_source_id]
	var bg     := TERRAIN_COLORS[bg_source_id]
	var rot    := tile_rotation if selected_shape > 0 else 0
	var mask   := _shape_masks[selected_shape * 4 + rot]
	var transp := Color(0, 0, 0, 0)
	var shaped := selected_shape > 0
	for py in sz:
		for px in sz:
			_preview_image.set_pixel(px, py, fg if mask[py * sz + px] != 0 else (bg if shaped else transp))
	_preview_texture.update(_preview_image)
	return _preview_texture


static func _rotated_uv(uv: Vector2, rot: int) -> Vector2:
	match rot:
		1: return Vector2(uv.y, 1.0 - uv.x)
		2: return Vector2(1.0 - uv.x, 1.0 - uv.y)
		3: return Vector2(1.0 - uv.y, uv.x)
	return uv


static func _shape_inside(uv: Vector2, shape: int) -> bool:
	# Fast paths — no arc distance needed.
	if shape == 0:  return true
	if shape == 1:  return uv.x + uv.y >= 1.0
	if shape == 4:  return uv.y > 0.5
	if shape == 5:  return abs(uv.x - 0.5) + abs(uv.y - 0.5) <= 0.5
	if shape == 6:
		var mx := uv.x - 0.5
		var my := uv.y - 0.5
		return mx * mx + my * my < 0.25
	if shape == 7:  return uv.x + uv.y >= 1.0 and uv.y > 0.5
	if shape == 11: return uv.x > 0.5 and uv.y > 0.5
	if shape == 12: return (uv.x > 0.5) != (uv.y > 0.5)
	if shape == 13: return uv.x + uv.y >= 1.0 and uv.x > 0.5 and uv.y > 0.5
	# Remaining shapes use the bottom-right corner arc: (cx, cy) = uv - (1, 1).
	var cx := uv.x - 1.0
	var cy := uv.y - 1.0
	var d2 := cx * cx + cy * cy
	if shape == 2:  return d2 < 1.0
	if shape == 3:  return d2 >= 1.0
	if shape == 8:  return d2 < 1.0 and uv.y > 0.5
	if shape == 9:  return d2 >= 1.0 and uv.y > 0.5
	if shape == 10:
		return (uv.x * uv.x + uv.y * uv.y) < 1.0 \
			and (cx * cx + uv.y * uv.y) < 1.0 \
			and (uv.x * uv.x + cy * cy) < 1.0 \
			and d2 < 1.0
	if shape == 14: return d2 < 1.0 and uv.x > 0.5 and uv.y > 0.5
	if shape == 15: return d2 >= 1.0 and uv.x > 0.5 and uv.y > 0.5
	return true
