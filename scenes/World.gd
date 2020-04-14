extends Node2D

#var Player = preload("res://Scenes/Assets/Player.tscn")
#var HoleSpawn = preload("res://Scenes/Assets/Hole.tscn")
#var WaterSpawn = preload("res://Scenes/Assets/Water.tscn")
#var YellowSpawn = preload("res://Scenes/Assets/Yellow.tscn")

#var player_count
#var current_player_index = 0 #Start with player 1

#signal level_loaded

func _ready():	
	var tileMap = get_node("TileMap")
	var size_x = tileMap.get_cell_size().x
	var size_y = tileMap.get_cell_size().y
	var tileSet = tileMap.get_tileset()
	var usedCells = tileMap.get_used_cells()

	#Setup tilemap
	for pos in usedCells :
		var id = tileMap.get_cell(pos.x, pos.y)
		var name = tileSet.tile_get_name(id)

		if name == "Start":
			print("Spawning SpawnPoint")
			var spawn_point = Node2D.new()
			spawn_point.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			spawn_point.set_name("SpawnPoint")
			add_child(spawn_point)

		if name == "Hole":
			print("Spawning Hole")
			#var hole = HoleSpawn.instance()
			#hole.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			#add_child(hole)

		if name == "Water":
			print("Spawning Water")
			#var water = WaterSpawn.instance()
			#water.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			#add_child(water)

		if name == "Yellow":
			print("Spawning Yellow")
			#var yellow = YellowSpawn.instance()
			#yellow.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			#add_child(yellow)
			
	emit_signal("level_loaded")

#func level_start():
#	player_count = get_node("/root/players").get_child_count()
#
#remotesync func turn_taken(pid):
#	current_player_index += 1
#
#	var node_name = String(pid)
#	print(node_name + " just took a turn")
#	get_node("/root/players").get_node(node_name).rset("turn", false)
#	$GUI/GameUI.rpc_id(1, "update_score")
#
#	if current_player_index < player_count:
#		get_node("/root/players").get_child(current_player_index).rset("turn", true)
#	else:
#		current_player_index = 0
#		get_node("/root/players").get_child(current_player_index).rset("turn", true)
