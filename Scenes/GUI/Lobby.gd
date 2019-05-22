extends Control

const PORT = 4242
const MAX_USERS = 3 #not including host

var player_name
var player_list = {}

func _ready():
		$Control/JoinButton.connect("pressed", self, "join_room")
		$Control/LeaveButton.connect("pressed", self, "leave_room")
		$Control/HostButton.connect("pressed", self, "host_room")

		get_tree().connect("connected_to_server", self, "enter_room")
		get_tree().connect("network_peer_disconnected", self, "user_exited")
		get_tree().connect("server_disconnected", self, "_server_disconnected")
		get_tree().connect("network_peer_connected", self, "user_entered")

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			send_message()

func host_room():
	player_name = $Control/NameEnter.text
	var host = NetworkedMultiplayerENet.new()
	host.create_server(PORT, MAX_USERS)
	get_tree().set_network_peer(host)
	$Room/ChatDisplay.add_text("Hosting Room\n")
	player_list[1] = player_name #register self as host
	enter_room()

func join_room():
	player_name = $Control/NameEnter.text
	var ip = $Control/IpEnter.text
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(ip, PORT)
	get_tree().set_network_peer(peer)

func enter_room():
	ui_connected(true)
	var id = get_tree().get_network_unique_id()
	rpc("register_connected", id, player_name)

func leave_room():
	$Room/ChatDisplay.add_text("Left Room\n")
	get_tree().set_network_peer(null)
	ui_connected(false)

func user_entered(id):
	$Room/ChatDisplay.text += "User joining with an id of " + str(id) + "\n"

func user_exited(id):
	$Room/ChatDisplay.text += player_list[id] + " left the room\n"

func ui_connected(b: bool):
	if b:
		$Control/LeaveButton.show()
		$Control/JoinButton.hide()
		$Control/HostButton.hide()
		$Control/IpEnter.hide()
		$Control/NameEnter.hide()
	else:
		$Control/LeaveButton.hide()
		$Control/JoinButton.show()
		$Control/HostButton.show()
		$Control/IpEnter.show()
		$Control/NameEnter.show()

remote func register_connected(id, player_name):
	print("Registering " + str(id) + " as " + player_name)
	player_list[id] = player_name
	if get_tree().is_network_server():
		print("Server doing registering stuff")
		rpc_id(id, "register_connected", 1, player_name)
		for peer_id in player_list:
			print("Sending " + str(id) + " information about " + str(peer_id))
			rpc_id(id, "register_connected", peer_id, (player_list[peer_id]));

func send_message():
	var message = $Room/ChatInput.text
	$Room/ChatInput.text = ""
	var id = get_tree().get_network_unique_id()
	rpc("receive_message", id, message)

remotesync func receive_message(id, message):
	$Room/ChatDisplay.add_text(str(player_list.get(id)) + " :  " + message + "\n")

func _server_disconnected():
	$Room/ChatDisplay.add_text("Disconnected from Server\n")
	leave_room()

func _on_NameEnter_text_changed(new_text):
	player_name = new_text
