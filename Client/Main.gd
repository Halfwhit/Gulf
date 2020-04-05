extends Control

onready var connection_status = get_node("MarginContainer/PanelContainer/MainContainer/LeftMargin/LeftContainer/GameinfoPanel/MarginContainer/GameinfoContainer/ConnectionStatus")
onready var join_button = get_node("MarginContainer/PanelContainer/MainContainer/LeftMargin/LeftContainer/ButtonPanel/MarginContainer/HBoxContainer/Join")
onready var player_name = get_node("MarginContainer/PanelContainer/MainContainer/LeftMargin/LeftContainer/SetupPanel/MarginContainer/VBoxContainer/NameContainer/PlayerName")
onready var player_colour = get_node("MarginContainer/PanelContainer/MainContainer/LeftMargin/LeftContainer/SetupPanel/MarginContainer/VBoxContainer/ColourContainer/PlayerColour")
onready var chatbox = get_node("MarginContainer/PanelContainer/MainContainer/RightMargin/RightContainer/PanelContainer/MarginContainer/Chatbox")
onready var message_edit = get_node("MarginContainer/PanelContainer/MainContainer/RightMargin/RightContainer/Message")


func _ready():
	gamestate.connect("connection_failed", self, "_on_connection_failed")
	gamestate.connect("connection_succeeded", self, "_on_connection_success")
	gamestate.connect("server_disconnected", self, "_on_server_disconnect")
	gamestate.connect("players_updated", self, "update_players_list")
	
	join_button.disabled = true
	message_edit.editable = false
	connection_status.text = "Connecting..."
	connection_status.modulate = Color.yellow


func _on_Quit_pressed():
	get_tree().quit()


func _on_Join_pressed():
	gamestate.pre_start_game()


func _on_connection_success():
	join_button.disabled = false
	message_edit.editable = true
	connection_status.text = "Connected"
	connection_status.modulate = Color.green


func _on_connection_failed():
	join_button.disabled = true
	message_edit.editable = false
	connection_status.text = "Connection Failed, trying again"
	connection_status.modulate = Color.red


func _on_server_disconnect():
	join_button.disabled = true
	message_edit.editable = false
	connection_status.text = "Server Disconnected, trying to connect..."
	connection_status.modulate = Color.red


func _on_Message_text_entered(new_text):
	var message = gamestate.my_name + " (Lobby) : " + new_text + "\n"
	message_edit.clear()
	rpc("rpc_message", message)

sync func rpc_message(message_text):
	chatbox.add_text(message_text)


func _on_PlayerName_changed(new_text):
	if new_text == "":
		gamestate.my_name = "Gulfer"
	else:
		gamestate.my_name = new_text
