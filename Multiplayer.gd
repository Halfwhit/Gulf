extends Node

# Game port and ip
const DEFAULT_PORT = 44444  # Default game port
const MAX_PEERS = 4        # Max number of players
var players = {}           # Names for players in id:name format
var players_ready = []
var my_name = "Player 1"
var my_color = Color("aaaaaa")
signal player_list_updated

func _ready():
	#warning-ignore:return_value_discarded
	get_tree().connect("connected_to_server", self, "player_connected")
	get_tree().connect("network_peer_disconnected", self, "player_disconnected")

func host_server():
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)
	players[1] = my_name
	emit_signal("player_list_updated")

func connect_to_server(ip):
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(peer)

func player_connected():
	# Tell everyone about me when I join
	rpc("register_player", get_tree().get_network_unique_id(), my_name)

func player_disconnected(p_id):
	players.erase(p_id)
	emit_signal("player_list_updated")

remote func register_player(id, player_name):
	players[id] = player_name
	
	if get_tree().is_network_server():
		# Send the new player information about everyone else
		for p_id in players:
			print("Sending data for: " + players.get(p_id))
			rpc_id(id, "register_player", p_id, players.get(p_id))
		print("Sent all data to new player")
		emit_signal("player_list_updated")

sync func player_ready(p_id):
	if players_ready.has(p_id):
		players_ready.erase(p_id)
	else:
		players_ready.append(p_id)
	emit_signal("player_list_updated")