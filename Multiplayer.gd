extends Node

# Game port and ip
const DEFAULT_PORT = 44444  # Default game port
const MAX_PEERS = 4        # Max number of players
var players = {}           # Names for players in id:name format
var player_colours = {}    # id:color format
var players_ready = []
var my_name = "Player 1"
var my_colour = Color("aaaaaa")
signal player_list_updated
signal level_start

func _ready():
	#warning-ignore:return_value_discarded
	get_tree().connect("connected_to_server", self, "player_connected")
	#warning-ignore:return_value_discarded
	get_tree().connect("network_peer_disconnected", self, "player_disconnected")
	#warning-ignore:return_value_discarded
	get_tree().connect("server_disconnected", self, "server_disconnected")

func host_server():
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)
	players[1] = my_name
	player_colours[1] = my_colour
	emit_signal("player_list_updated")

func connect_to_server(ip):
	# First, make sure Multiplayer script variables are cleared for the new player
	players.clear()
	player_colours.clear()
	players_ready.clear()
	# Set up peer and add to the servers scenetree
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)

func player_connected():
	# Tell everyone about me when I join
	rpc("register_player", get_tree().get_network_unique_id(), my_name, my_colour)
	var joined_message = my_name + " has joined the lobby."
	get_node("/root/Lobby").rpc("send_message", joined_message)

func player_disconnected(p_id):
	var disconnect_message = my_name + " has disconnected from the lobby."
	get_node("/root/Lobby").rpc("send_message", disconnect_message)
	players.erase(p_id)
	players_ready.erase(p_id)
	emit_signal("player_list_updated")

func server_disconnected():
	var server_disconnect_message = "Server has shutdown. Disconnecting from host."
	get_node("/root/Lobby").rpc("send_message", server_disconnect_message)
	players.clear()
	players_ready.clear()

# warning-ignore:shadowed_variable
remote func register_player(id, player_name, my_colour):
	players[id] = player_name
	player_colours[id] = my_colour
	
	if get_tree().is_network_server():
		# Send the new player information about everyone else
		for p_id in players:
			print("Sending data for: " + players.get(p_id))
			rpc_id(id, "register_player", p_id, players.get(p_id), player_colours.get(p_id))
		print("Sent all data to new player")
		players_ready.clear()
		emit_signal("player_list_updated")

sync func player_ready(p_id):
	if players_ready.has(p_id):
		players_ready.erase(p_id)
	else:
		players_ready.append(p_id)
	emit_signal("player_list_updated")

remotesync func preconfigure():
	# Load world
	print("Setting up world with " + str(players.size()) + " players.")
	var world = load("res://Scenes/Levels/TestLevel.tscn").instance()
	var players_node = Node2D.new()
	players_node.set_name("players")
	get_tree().get_root().add_child(players_node)
	get_tree().get_root().add_child(world)
	get_tree().get_root().get_node("Lobby").hide()
	var player_scene = preload("res://Scenes/Assets/Player.tscn")
	# Load players
	for p in Multiplayer.players:
		var player = player_scene.instance()
		player.set_name(str(p))
		player.get_node("Sprite").self_modulate = player_colours.get(p)
		player.set_player_name(players[p])
		player.position = world.get_node("SpawnPoint").position
		player.set_network_master(p)
		player.connect("turn_taken", self, "turn_taken")
		print("Adding " + player.player_name + " to the world")
		get_node("/root/players").add_child(player)
		
	rpc_id(1, "done_preconfiguring", get_tree().get_network_unique_id())

var players_loaded = []
remotesync func done_preconfiguring(p_id):
	if get_tree().is_network_server():
		players_loaded.append(p_id)
		if players_loaded.size() == Multiplayer.players.size():
			rpc("post_configure_game")

remotesync func post_configure_game():
	get_tree().set_pause(false)
	get_node("/root/players/1").turn = true
	emit_signal("level_start")

func turn_taken(p_id):
	for p in players:
		var p_node = get_node("/root/players").get_node(p_id)
		p_node.get_node("/root/world/GUI/GameUI").rpc("update_score")
