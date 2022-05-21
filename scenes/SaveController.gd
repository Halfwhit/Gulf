extends Node

export var save_location: String = "user://editor.level"

func save_scene():
	var save_scene = File.new()
	save_scene.open(save_location, File.WRITE)
	var save_nodes = get_tree().get_nodes_in_group("save")
	for node in save_nodes:
		# Check the node has a save function
		if !node.has_method("save"):
			print("persistent node '%s' is missing a save() function, skipped" % node.name)
			continue
		# Call the node's save function
		var node_data = node.call("save")
		# Store the save dictionary as a new line in the save file
		save_scene.store_line(to_json(node_data))
	print("Saved at: " + save_scene.get_path_absolute())
	save_scene.close()

func load_scene():
	var save_scene = File.new()
	# Check for file
	if not save_scene.file_exists(save_location):
		print("no save file to load ya dingus!")
		return # Abort, else:
	save_scene.open(save_location, File.READ)
	while save_scene.get_position() < save_scene.get_len():
		var node_data = parse_json(save_scene.get_line())
		# Read ground data
		if node_data.has("ground_cells_used"):
			var ground_map = get_parent().get_node("Level/Ground")
			# Clear tilemap
			for tile in ground_map.get_used_cells():
				ground_map.set_cellv(tile, -1)
			# Setup ground
			for ground in range(node_data.get("ground_cells_used").size()):
				var location_string = node_data.get("ground_cells_used")[ground]
				location_string = location_string.substr(1, location_string.length()-2)
				var string_to_vec = location_string.split(",", false)
				var location_vector = Vector2(string_to_vec[0].to_int(), string_to_vec[1].to_int())
				var cell_id: int = node_data.get("ground_cells_ids")[ground]
				var transpose : bool = node_data.get("ground_cells_rotation")[ground][0]
				var y_flip : bool = node_data.get("ground_cells_rotation")[ground][1]
				var x_flip : bool = node_data.get("ground_cells_rotation")[ground][2]
				ground_map.set_cellv(location_vector, cell_id, x_flip, y_flip, transpose)
		# Read wall data
		if node_data.has("wall_cells_used"):
			var wall_map = get_parent().get_node("Level/Walls")
			# Clear tilemap
			for tile in wall_map.get_used_cells():
				wall_map.set_cellv(tile, -1)
			# Setup walls
			for wall in range(node_data.get("wall_cells_used").size()):
				var location_string = node_data.get("wall_cells_used")[wall]
				location_string = location_string.substr(1, location_string.length()-2)
				var string_to_vec = location_string.split(",", false)
				var location_vector = Vector2(string_to_vec[0].to_int(), string_to_vec[1].to_int())
				var cell_id: int = node_data.get("wall_cells_ids")[wall]
				var transpose : bool = node_data.get("wall_cells_rotation")[wall][0]
				var y_flip : bool = node_data.get("wall_cells_rotation")[wall][1]
				var x_flip : bool = node_data.get("wall_cells_rotation")[wall][2]
				wall_map.set_cellv(location_vector, cell_id, x_flip, y_flip, transpose)
				wall_map.update_bitmask_area(location_vector)
		# Read entity data
		if node_data.has("entity_cells_used"):
			var entity_map = get_parent().get_node("Level/Entities")
			# Clear tilemap
			for tile in entity_map.get_used_cells():
				entity_map.set_cellv(tile, -1)
			# Setup entity
			for entity in range(node_data.get("entity_cells_used").size()):
				var location_string = node_data.get("entity_cells_used")[entity]
				location_string = location_string.substr(1, location_string.length()-2)
				var string_to_vec = location_string.split(",", false)
				var location_vector = Vector2(string_to_vec[0].to_int(), string_to_vec[1].to_int())
				var cell_id: int = node_data.get("entity_cells_ids")[entity]
				var transpose : bool = node_data.get("entity_cells_rotation")[entity][0]
				var y_flip : bool = node_data.get("entity_cells_rotation")[entity][1]
				var x_flip : bool = node_data.get("entity_cells_rotation")[entity][2]
				entity_map.set_cellv(location_vector, cell_id, x_flip, y_flip, transpose)
	
	save_scene.close()
