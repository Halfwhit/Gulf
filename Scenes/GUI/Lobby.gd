extends Control

const PORT = 4242
const MAX_USERS = 3 #not including host

func _ready():
	$Control/JoinButton.connect("pressed", self, "join_room")
	$Control/LeaveButton.connect("pressed", self, "leave_room")
	$Control/HostButton.connect("pressed", self, "host_room")
	$Control/StartGame.connect("pressed", self, "start_game")
		
	multiGlobal.connect("connection_failed", self, "_on_connection_failed")
	multiGlobal.connect("player_list_changed", self, "refresh_lobby")
	multiGlobal.connect("game_ended", self, "_on_game_ended")
	multiGlobal.connect("game_error", self, "_on_game_error")

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			send_message()

func send_message():
	var message = $Room/ChatInput.text
	$Room/ChatInput.text = ""
	var player_name = str(multiGlobal.get_player_name())
	rpc("receive_message", player_name, message)

remotesync func receive_message(player_name, message):
	$Room/ChatDisplay.add_text(player_name + " :  " + message + "\n")

func host_room():
	if $Control/NameEnter.text == "":
		$Room/ChatDisplay.add_text("Invalid name\n")
		return
	var player_name = $Control/NameEnter.text
	$Room/ChatDisplay.add_text("Hosting Room\n")
	multiGlobal.host_game(player_name)
	ui_connected(true)
	refresh_lobby()

func join_room():
	if $Control/NameEnter.text == "":
		$Room/ChatDisplay.add_text("Invalid name\n")
		return
	var ip = $Control/IpEnter.text
	if not ip.is_valid_ip_address():
		$Room/ChatDisplay.add_text("Invalid IPv4 address\n")
		return
	ui_connected(true)
	var player_name = $Control/NameEnter.text
	multiGlobal.join_game(ip, player_name)

func leave_room():
	$Room/ChatDisplay.add_text("Left Room\n")
	get_tree().set_network_peer(null)
	ui_connected(false)
	refresh_lobby()
	$Control/PlayerList.clear()

func start_game():
	multiGlobal.begin_game()

func refresh_lobby():
	var players = multiGlobal.get_player_list()
	players.sort()
	$Control/PlayerList.clear()
	$Control/PlayerList.add_item(multiGlobal.get_player_name() + " (You)")
	for p in players:
		if p != multiGlobal.get_player_name():
			$Control/PlayerList.add_item(p)

	$Control/StartGame.disabled = not get_tree().is_network_server()

func ui_connected(connected: bool):
	if connected:
		$Control/LeaveButton.show()
		$Control/JoinButton.hide()
		$Control/HostButton.hide()
		$Control/IpEnter.hide()
		$Control/NameEnter.hide()
		$Control/StartGame.disabled=true
		$Room/ChatInput.editable=true
		if get_tree().is_network_server():
			$Control/StartGame.disabled=false
	else:
		$Control/LeaveButton.hide()
		$Control/JoinButton.show()
		$Control/HostButton.show()
		$Control/IpEnter.show()
		$Control/NameEnter.show()
		$Control/StartGame.disabled=true
		$Room/ChatInput.editable=false

func _on_connection_failed():
	$Room/ChatDisplay.add_text("Connection failed\n")

func _on_game_ended():
	refresh_lobby()
	show()