extends PanelContainer

var tile_layer
var base_tile
var selected_tile_id

signal tile_selected(layer_id, id)

enum Layer {
	GROUND
	WALLS
	ENTITIES
	EMPTY
}

func _on_BaseTile_item_selected(index: int) -> void:
	tile_layer = Layer.GROUND
	base_tile = index
	selected_tile_id = base_tile * 4
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_TileVariant_item_selected(index: int) -> void:
	tile_layer = Layer.GROUND
	selected_tile_id = 16 + (base_tile * 8) + index
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_TileVariant_nothing_selected() -> void:
	selected_tile_id = base_tile * 4
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_Walls_item_selected(index: int) -> void:
	tile_layer = Layer.WALLS
	selected_tile_id = index
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_Entities_item_selected(index: int) -> void:
	tile_layer = Layer.ENTITIES
	selected_tile_id = index
	emit_signal("tile_selected", tile_layer, selected_tile_id)
