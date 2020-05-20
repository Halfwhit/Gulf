extends Node2D

var Player = preload("res://assets/Player.tscn")
var PlayerClient = preload("res://assets/PlayerClient.tscn")
var HoleSpawn = preload("res://assets/Hole.tscn")
var WaterSpawn = preload("res://assets/Water.tscn")
var YellowSpawn = preload("res://assets/Yellow.tscn")

var ready_for_turn = false
var player_count
var current_player_index = 0

signal level_loaded

func _ready():
# warning-ignore:return_value_discarded
	connect("level_loaded", self, "spawn_players")
	# Setup entity tilemap
	var tileMap = get_node("Entities")
	var size_x = tileMap.get_cell_size().x
	var size_y = tileMap.get_cell_size().y
	var tileSet = tileMap.get_tileset()
	var usedCells = tileMap.get_used_cells()
	for pos in usedCells:
		var id = tileMap.get_cell(pos.x, pos.y)
		var name = tileSet.tile_get_name(id)
		if name == "water_square":
			var water = WaterSpawn.instance()
			water.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(water)
			tileMap.set_cell(pos.x, pos.y, -1)
		if name == "acid_square":
			var yellow = YellowSpawn.instance()
			yellow.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(yellow)
			tileMap.set_cell(pos.x, pos.y, -1)
		if name == "mud_square":
			tileMap.set_cell(pos.x, pos.y, -1)
		if name == "deep_mud_square":
			tileMap.set_cell(pos.x, pos.y, -1)
	
	# Setup ground tilemap
	tileMap = get_node("Ground")
	size_x = tileMap.get_cell_size().x
	size_y = tileMap.get_cell_size().y
	tileSet = tileMap.get_tileset()
	usedCells = tileMap.get_used_cells()
	for pos in usedCells:
		var id = tileMap.get_cell(pos.x, pos.y)
		var name = tileSet.tile_get_name(id)
		if name == "start":
			var spawn_point = Node2D.new()
			spawn_point.position = Vector2( pos.x * size_x + (0.5 * size_x), pos.y * size_y + (0.5 * size_y))
			spawn_point.set_name("SpawnPoint")
			add_child(spawn_point)
		if name == "hole":
			print("Spawning Hole")
			var hole = HoleSpawn.instance()
			hole.position = Vector2( pos.x * size_x + (0.5 * size_x), pos.y * size_y + (0.5 * size_y))
			add_child(hole)
	
	emit_signal("level_loaded")

func _process(_delta: float) -> void:
	if ready_for_turn and is_everyone_still():
		ready_for_turn = false
		turn_taken()
	

func spawn_players():
	var lobby = get_tree().get_root().get_node("Main/GUI/Lobby")
	player_count = lobby.LOBBY_MEMBERS.size()
	var spawn_pos = get_node("SpawnPoint").position
	for member in lobby.LOBBY_MEMBERS:
		var member_name = str(member.get("steam_id"))
		#if Gamestate.is_host:
		host_spawn(member_name, spawn_pos)
		#else:
		#	client_spawn(member_name, spawn_pos)
	get_node("Players").get_child(current_player_index).turn = true

func client_spawn(member_name, pos):
	var player = PlayerClient.instance()
	player.position = pos
	player.name = member_name
	get_node("Players").add_child(player)

func host_spawn(member_name, pos):
	var player = Player.instance()
	player.position = pos
	player.name = member_name
	get_node("Players").add_child(player)

func turn_taken():
	get_node("Players").get_child(current_player_index).turn = false
	current_player_index += 1
	if current_player_index < player_count:
		get_node("Players").get_child(current_player_index).turn = true
	else:
		current_player_index = 0
		get_node("Players").get_child(current_player_index).turn = true

func is_everyone_still():
	var return_boolean = true
	for ball in get_node("Players").get_children():
		if ball.ball_vector.length() != 0:
			return_boolean = false
	return return_boolean
