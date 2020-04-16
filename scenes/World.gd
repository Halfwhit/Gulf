extends Node2D

var Player = preload("res://assets/Player.tscn")
var HoleSpawn = preload("res://assets/Hole.tscn")
var WaterSpawn = preload("res://assets/Water.tscn")
var YellowSpawn = preload("res://assets/Yellow.tscn")

var player_count
var current_player_index = 0

signal level_loaded

func _ready():
	connect("level_loaded", self, "spawn_player")
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
			spawn_point.name = "SpawnPoint"
			add_child(spawn_point)
		if name == "Hole":
			print("Spawning Hole")
			var hole = HoleSpawn.instance()
			hole.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(hole)
		if name == "Water":
			print("Spawning Water")
			var water = WaterSpawn.instance()
			water.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(water)
		if name == "Yellow":
			print("Spawning Yellow")
			var yellow = YellowSpawn.instance()
			yellow.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(yellow)
	emit_signal("level_loaded")

func spawn_player():
	var lobby = get_tree().get_root().get_node("Main/GUI/Lobby")
	player_count = lobby.LOBBY_MEMBERS.size()
	for member in lobby.LOBBY_MEMBERS:
		var player = Player.instance()
		player.position = get_node("SpawnPoint").position
		player.name = str(member.get("steam_id"))
		get_node("Players").add_child(player)
	get_node("Players").get_child(current_player_index).turn = true

func turn_taken(steam_id):
	current_player_index += 1
	get_node("Players").get_node(steam_id).turn = false
	if current_player_index < player_count:
		get_node("Players").get_child(current_player_index).turn = true
	else:
		current_player_index = 0
		get_node("Players").get_child(current_player_index).turn = true
