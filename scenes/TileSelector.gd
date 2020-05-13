extends PanelContainer

var tile_sheet
var base_tile
var variant_selected: bool = false
var selected_tile_id

signal tile_selected(id)

func _on_BaseTile_item_selected(index: int) -> void:
	tile_sheet = "ground"
	base_tile = index
	selected_tile_id = base_tile * 4
	emit_signal("tile_selected", selected_tile_id)


func _on_TileVariant_item_selected(index: int) -> void:
	tile_sheet = "ground"
	selected_tile_id = 16 + (base_tile * 8) + index
	emit_signal("tile_selected", selected_tile_id)


func _on_TileVariant_nothing_selected() -> void:
	variant_selected = false
	selected_tile_id = base_tile * 4
	emit_signal("tile_selected", selected_tile_id)
