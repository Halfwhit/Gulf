extends Node

# Default game port
const DEFAULT_PORT = 4444

# Max number of players
const MAX_PEERS = 4

# Name for my player
var player_name = "Default Host"

# Names for remote players in id:name format
var players = {}

var turn_player


# Signals to let lobby GUI know what's going on
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)

# Callback from SceneTree
func _player_disconnected(id):
	if get_tree().is_network_server():
		if has_node("/root/world"): # Game is in progress
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
		else: # Game is not in progress
			# If we are the server, send to the new dude all the already registered players
			unregister_player(id)
			for p_id in players:
				# Erase in the server
				rpc_id(p_id, "unregister_player", id)

# Callback from SceneTree, only for clients (not server)
func _connected_ok():
	# Registration of a client beings here, tell everyone that we are here
	rpc("register_player", get_tree().get_network_unique_id(), player_name)
	emit_signal("connection_succeeded")

# Callback from SceneTree, only for clients (not server)
func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	end_game()

# Callback from SceneTree, only for clients (not server)
func _connected_fail():
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

# Lobby management functions
remote func register_player(id, new_player_name):
	players[id] = new_player_name
	if get_tree().is_network_server():
		# If we are the server, let everyone know about the new player
		rpc_id(id, "register_player", 1, player_name) # Send myself to new dude
		for p_id in players: # Then, for each remote player
			rpc_id(id, "register_player", p_id, players[p_id]) # Send player to new dude
			rpc_id(p_id, "register_player", id, new_player_name) # Send new dude to player

	print("Adding " + new_player_name + " with an id of: " + str(id))
	emit_signal("player_list_changed")

remote func unregister_player(id):
	players.erase(id)
	emit_signal("player_list_changed")

remote func pre_start_game():
	# Change scene
	print("Setting up world with " + str(players.size()) + " players.")
	var world = global.next_hole.instance()
	get_tree().get_root().add_child(world)
	get_tree().get_root().get_node("Lobby").hide()
	var player_scene = preload("res://Scenes/Assets/Player.tscn")
	for p_id in players:
		var spawn_pos = world.get_node("SpawnPoint").position
		var player = player_scene.instance()
		player.set_name(str(p_id)) # Use unique ID as node name
		player.position=spawn_pos
		player.set_network_master(p_id) #set unique id as master
		if p_id == get_tree().get_network_unique_id():
			# If node for this peer id, set name
			player.set_player_name(player_name)
		else:
			# Otherwise set name from peer
			player.set_player_name(players[p_id])
		print("Adding " + player.player_name + " to the world")
		world.add_child(player)
	# Set up score TODO
	#world.get_node("score").add_player(get_tree().get_network_unique_id(), player_name)
	#for pn in players:
	#	world.get_node("score").add_player(pn, players[pn])
	if not get_tree().is_network_server():
		# Tell server we are ready to start
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())
	elif players.size() == 0:
		post_start_game()

remotesync func post_start_game():
	get_tree().set_pause(false) # Unpause and unleash the game!

var players_ready = []
remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if not id in players_ready:
		players_ready.append(id)

	if players_ready.size() == players.size():
		rpc("post_start_game")

func host_game(new_player_name):
	player_name = new_player_name
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)
	register_player(get_tree().get_network_unique_id(), player_name)

func join_game(ip, new_player_name):
	player_name = new_player_name
	var host = NetworkedMultiplayerENet.new()
	host.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(host)

func get_player_list():
	return players.values()

func get_player_name():
	return player_name

func get_player_name_by_id(id):
	return players.get(id)

func begin_game():
	assert(get_tree().is_network_server())
	for p_id in players:
		rpc_id(p_id, "pre_start_game")
	pre_start_game()

func end_game():
	print("Attempting to end game...")
	if has_node("/root/world"): # Game is in progress
		# End it
		print("Found world node")
		get_node("/root/world").queue_free()
		print("Cleared world's queue")
	print("Emitting signal")
	emit_signal("game_ended")

var players_finished = 0
func player_scored():
	players_finished += 1
	if players_finished == players.size():
		global.holes_completed += 1
		print("Holes completed: " + str(global.holes_completed))
		global.get_next_level()
		players_finished = 0
		end_game()

func _ready():
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")