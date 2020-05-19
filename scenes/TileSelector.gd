extends PanelContainer

var tile_layer

var selected_tile_id

signal tile_selected(layer_id, id)

enum Layer {
	GROUND
	WALLS
	ENTITIES
	EMPTY
}


func ground_tile_selected(id) -> void:
	tile_layer = Layer.GROUND
	selected_tile_id = id
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_Walls_item_selected(index: int) -> void:
	tile_layer = Layer.WALLS
	selected_tile_id = index
	emit_signal("tile_selected", tile_layer, selected_tile_id)


func _on_Entities_item_selected(index: int) -> void:
	tile_layer = Layer.ENTITIES
	selected_tile_id = index
	emit_signal("tile_selected", tile_layer, selected_tile_id)
