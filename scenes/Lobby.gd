extends Node

var STEAM_LOBBY_ID = 0
var LOBBY_MEMBERS = []
var DATA
var LOBBY_INVITE_ARG = false
var player_data = {}
var players_ready = []


onready var name_list = get_node("HBoxContainer/LeftPanel/VBoxContainer/PlayerList/PanelContainer/MarginContainer/HBoxContainer/Names/Players")
onready var status_list = get_node("HBoxContainer/LeftPanel/VBoxContainer/PlayerList/PanelContainer/MarginContainer/HBoxContainer/Status/Players")


enum PacketType {
	READY_PACKET
}
func _ready():
	Steam.connect("lobby_created", self, "_on_Lobby_Created")
	Steam.connect("lobby_match_list", self, "_on_Lobby_Match_List")
	Steam.connect("lobby_joined", self, "_on_Lobby_Joined")
	Steam.connect("lobby_chat_update", self, "_on_Lobby_Chat_Update")
	Steam.connect("lobby_message", self, "_on_Lobby_Message")
	Steam.connect("lobby_data_update", self, "_on_Lobby_Data_Update")
	Steam.connect("lobby_invite", self, "_on_Lobby_Invite")
	Steam.connect("join_requested", self, "_on_Lobby_Join_Requested")
	Steam.connect("p2p_session_request", self, "_on_P2P_Session_Request")
	Steam.connect("p2p_session_connect_fail", self, "_on_P2P_Session_Connect_Fail")
	Steam.connect("avatar_loaded", self, "loaded_avatar")
	# Check for command line arguments
	_check_Command_Line()


func _on_Quit_pressed():
	get_tree().quit()


# Used to handle steam invites/join requests
func _check_Command_Line():
	var ARGUMENTS = OS.get_cmdline_args()
	# There are arguments to process
	if ARGUMENTS.size() > 0:
		# Loop through them and get the useful ones
		for ARGUMENT in ARGUMENTS:
			print("Command line: "+str(ARGUMENT))
			# An invite argument was passed
			if LOBBY_INVITE_ARG:
				_join_Lobby(int(ARGUMENT))
			# A Steam connection argument exists
			if ARGUMENT == "+connect_lobby":
				LOBBY_INVITE_ARG = true


func _process(delta):
	#_read_P2P_Packet()
	pass


func _on_Public_pressed():
	# Make sure a lobby is not already set
	if STEAM_LOBBY_ID == 0:
		Steam.createLobby(2, 6) # Public, max 6 players


func _on_Friends_pressed():
	# Make sure a lobby is not already set
	if STEAM_LOBBY_ID == 0:
		Steam.createLobby(1, 6) # Friends only, max 6 players


func _on_Lobby_Created(connect, lobbyID):
	if connect == 0:
		# Set the lobby ID
		STEAM_LOBBY_ID = lobbyID
		# Set some lobby data
		var lobby_details = "\nLobby hosted by: " + Steamworks.STEAM_USERNAME + "\n"
		_append_Message("---------------------------------------------------------------------------------\n" +
						"Lobby hosted by: " + Steamworks.STEAM_USERNAME +
						"\n---------------------------------------------------------------------------------")
		Steam.setLobbyData(lobbyID, "name", lobby_details)
		Steam.setLobbyData(lobbyID, "mode", "Gulf")
		# Allow P2P connections to fallback to being relayed through Steam if needed
		var RELAY = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: "+str(RELAY))


func _on_LobbySearch_pressed():
	# Clear list first
	for node in $LobbyPanel/VBoxContainer/ScrollContainer/LobbyList.get_children():
		node.queue_free()
	$LobbyPanel.popup()
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(3)
	print("Requesting a lobby list")
	Steam.requestLobbyList()


func _on_CloseLobbySearch_pressed():
	$LobbyPanel.hide()


# Getting a lobby match list from the steam callback
func _on_Lobby_Match_List(lobbies):
	for LOBBY in lobbies:
		# Pull lobby data from Steam
		var LOBBY_NAME = Steam.getLobbyData(LOBBY, "name")
		var LOBBY_MODE = Steam.getLobbyData(LOBBY, "mode")
		var LOBBY_MEMBERS = Steam.getNumLobbyMembers(LOBBY)
		# Create a button for the lobby
		var LOBBY_BUTTON = Button.new()
		LOBBY_BUTTON.set_text("Lobby "+str(LOBBY)+": "+str(LOBBY_NAME)+" ["+str(LOBBY_MODE)+"] - "+str(LOBBY_MEMBERS)+" Player(s)")
		LOBBY_BUTTON.set_size(Vector2(800, 50))
		LOBBY_BUTTON.set_name("lobby_"+str(LOBBY))
		LOBBY_BUTTON.connect("pressed", self, "_join_Lobby", [LOBBY])
		# Add the new lobby to the list
		$LobbyPanel/VBoxContainer/ScrollContainer/LobbyList.add_child(LOBBY_BUTTON)


func _join_Lobby(lobbyID):
	print("Attempting to join lobby "+str(lobbyID)+"...")
	# Clear any previous lobby members lists, if you were in a previous lobby
	LOBBY_MEMBERS.clear()
	# Make the lobby join request to Steam
	Steam.joinLobby(lobbyID)


# Called when a friend tries to join a running game
func _on_Lobby_Join_Requested(lobbyID, friendID):	
	# Get the lobby owner's name
	var OWNER_NAME = Steam.getFriendPersonaName(friendID)
	print("Joining "+str(OWNER_NAME)+"'s lobby...")
	# Attempt to join the lobby
	_join_Lobby(lobbyID)


func _on_Lobby_Joined(lobbyID, permissions, locked, response):
	# Set this lobby ID as your lobby ID
	STEAM_LOBBY_ID = lobbyID
	Steam.setLobbyMemberData(lobbyID, "status", "Not ready")
	# Get the lobby members
	_get_Lobby_Members()
	# Make the initial handshake
	_make_P2P_Handshake()
	$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Connecting.hide()
	if Steam.getLobbyOwner(lobbyID) == Steamworks.STEAM_ID:
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Host.show()
	else:
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Peer.show()


func _on_Lobby_Chat_Update(lobbyID, changedID, makingChangeID, chatState):
	# Get the user who has made the lobby change
	var CHANGER = Steam.getFriendPersonaName(makingChangeID)
	var message
	# If a player has joined the lobby
	if chatState == 1:
		message = str(CHANGER) + " has joined the lobby."
	# Else if a player has left the lobby
	elif chatState == 2:
		message = str(CHANGER) + " has left the lobby."
	else:
		message = str(CHANGER)+" did... something... -> " + str(chatState)
	# Update the lobby now that a change has occurred
	_get_Lobby_Members()
	_append_Message(message)


func _get_Lobby_Members():
	# Clear your previous lobby list
	LOBBY_MEMBERS.clear()
	# Get the number of members from this lobby from Steam
	var MEMBERS = Steam.getNumLobbyMembers(STEAM_LOBBY_ID)
	# Get the data of these players from Steam
	for MEMBER in range(0, MEMBERS):
		# Get the member's Steam ID and Steam Name
		var MEMBER_STEAM_ID = Steam.getLobbyMemberByIndex(STEAM_LOBBY_ID, MEMBER)
		var MEMBER_STEAM_NAME = Steam.getFriendPersonaName(MEMBER_STEAM_ID)
		# Add them to the list
		LOBBY_MEMBERS.append({"steam_id":MEMBER_STEAM_ID, "steam_name":MEMBER_STEAM_NAME})


func _clear_playerlist():
	for node in name_list.get_children():
		node.queue_free()
	for node in status_list.get_children():
		node.queue_free()


func _on_Lobby_Data_Update(success, lobbyID, memberID, key):
	print("Success: "+str(success)+", Lobby ID: "+str(lobbyID)+", Member ID: "+str(memberID)+", Key: "+str(key))
	if lobbyID == memberID:
		pass
	else:
		_clear_playerlist()
		for MEMBER in LOBBY_MEMBERS:
			# Handle name node in player list
			var MEMBER_STEAM_ID = MEMBER.get("steam_id")
			var MEMBER_STEAM_NAME = MEMBER.get("steam_name")
			var member_name = Label.new()
			member_name.name = "player_name"
			member_name.text = MEMBER_STEAM_NAME
			member_name.align = Label.ALIGN_CENTER
			name_list.add_child(member_name)
			#Handle status node in player list
			var lobby_member_data = Steam.getLobbyMemberData(STEAM_LOBBY_ID, memberID, "status")
			var member_status = Label.new()
			member_status.name = str(MEMBER_STEAM_ID)
			member_status.text = lobby_member_data
			member_status.align = Label.ALIGN_CENTER
			if lobby_member_data == "Ready":
				member_status.add_color_override("font_color", Color.green)
			if lobby_member_data == "Not ready":
				member_status.add_color_override("font_color", Color.red)
			status_list.add_child(member_status)


func _on_Ready_pressed():
	if Steam.getLobbyMemberData(STEAM_LOBBY_ID, Steamworks.STEAM_ID, "status") == "Not ready":
		Steam.setLobbyMemberData(STEAM_LOBBY_ID, "status", "Ready")
	else:
		Steam.setLobbyMemberData(STEAM_LOBBY_ID, "status", "Not ready")


func _on_Lobby_Message(result, user, message, type):
	# We are only concerned with who is sending the message and what the message is
	var SENDER = Steam.getFriendPersonaName(user)
	_append_Message(str(SENDER)+" :  "+str(message))


func _append_Message(message):
	$HBoxContainer/RightPanel/ChatBox/VBoxContainer/Chatlog.add_text("\n" + str(message))


func _on_Message_text_entered(new_text):
	# Get the entered chat message
	var MESSAGE = $HBoxContainer/RightPanel/ChatBox/VBoxContainer/Message.get_text()
	# Pass the message to Steam
	var SENT = Steam.sendLobbyChatMsg(STEAM_LOBBY_ID, MESSAGE)
	# Was it sent successfully?
	if not SENT:
		_append_Message("ERROR: Chat message failed to send.")
	# Clear the chat input
	$HBoxContainer/RightPanel/ChatBox/VBoxContainer/Message.clear()


func _leave_Lobby():
	# If in a lobby, leave it
	if STEAM_LOBBY_ID != 0:
		# Send leave request to Steam
		Steam.leaveLobby(STEAM_LOBBY_ID)
		# Wipe the Steam lobby ID then display the default lobby ID and player list title
		_append_Message("---------------------------------------------------------------------------------\n" + 
						"Disconnected from LobbyID: " + str(STEAM_LOBBY_ID) + 
						"\n---------------------------------------------------------------------------------")
		STEAM_LOBBY_ID = 0
		_clear_playerlist()
		# Close session with all users
		for MEMBERS in LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(MEMBERS['steam_id'])
		# Clear the local lobby list
		LOBBY_MEMBERS.clear()
		# Handle GUI
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Connecting.show()
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Host.hide()
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Peer.hide()
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Host/Ready.pressed = false
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Peer/Ready.pressed = false


func _make_P2P_Handshake():
	print("Sending P2P handshake to the lobby")
	var DATA = PoolByteArray()
	DATA.append(256)
	DATA.append_array(var2bytes({"message":"handshake", "from":Steamworks.STEAM_ID}))
	#_send_P2P_Packet(DATA, 2, 0)


func _on_P2P_Session_Request(remoteID):	
	# Get the requester's name
	var REQUESTER = Steam.getFriendPersonaName(remoteID)
	# Accept the P2P session; can apply logic to deny this request if needed
	Steam.acceptP2PSessionWithUser(remoteID)
	# Make the initial handshake
	_make_P2P_Handshake()


func _send_P2P_Packet(data, send_type, channel):
	# If there is more than one user, send packets
	if LOBBY_MEMBERS.size() > 1:
		# Loop through all members that aren't you
		for MEMBER in LOBBY_MEMBERS:
			if MEMBER['steam_id'] != Steamworks.STEAM_ID:
				Steam.sendP2PPacket(MEMBER['steam_id'], data, send_type, channel)


func _read_P2P_Packet():
	var PACKET_SIZE = Steam.getAvailableP2PPacketSize(0)
	# There is a packet
	if PACKET_SIZE > 0:
		var PACKET = Steam.readP2PPacket(PACKET_SIZE, 0)
		if PACKET.empty():
			print("WARNING: read an empty packet with non-zero size!")
		# Get the remote user's ID
		var PACKET_ID = str(PACKET.steamIDRemote)
		var PACKET_CODE = str(PACKET.data[0])
		# Make the packet data readable
		var READABLE = bytes2var(PACKET.data.subarray(1, PACKET_SIZE - 1))
		# Print the packet to output
		print("Packet: "+str(READABLE))
		# Append logic here to deal with packet data
