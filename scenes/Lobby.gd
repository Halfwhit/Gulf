extends Node

var STEAM_LOBBY_ID = 0
var LOBBY_MEMBERS = []
var DATA
var LOBBY_INVITE_ARG = false
var player_data = {}


onready var name_list = get_node("HBoxContainer/LeftPanel/VBoxContainer/PlayerList/PanelContainer/MarginContainer/HBoxContainer/Names/Players")
onready var status_list = get_node("HBoxContainer/LeftPanel/VBoxContainer/PlayerList/PanelContainer/MarginContainer/HBoxContainer/Status/Players")

func _on_Quit_pressed():
	get_tree().quit()



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

func loaded_avatar(id, size, buffer):
	print("Avatar for user: "+str(id))
	print("Size: "+str(size))
	# Create a new image and texture to fill out
	var AVATAR = Image.new()
	var AVATAR_TEXTURE = ImageTexture.new()
	AVATAR.create(size, size, false, Image.FORMAT_RGBAF)

	# Lock the image and fill the pixels from the data buffer
	AVATAR.lock()
	for y in range(0, size):
		for x in range(0, size):
			var pixel = 4 * (x + y * size)
			var r = float(buffer[pixel]) / 255
			var g = float(buffer[pixel+1]) / 255
			var b = float(buffer[pixel+2]) / 255
			var a = float(buffer[pixel+3]) / 255
			AVATAR.set_pixel(x, y, Color(r, g, b, a))
	AVATAR.unlock()

	# Now apply the texture
	AVATAR_TEXTURE.create_from_image(AVATAR)

	# For our purposes, set a sprite with the avatar texture
	var node_path = NodePath("HBoxContainer/LeftPanel/VBoxContainer/PlayerList/PanelContainer/MarginContainer/HBoxContainer/Names/Players/" + str(id))
	get_node(node_path).get_node("player_icon").set_texture(AVATAR_TEXTURE)
	


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
		print("Created a lobby: "+str(STEAM_LOBBY_ID))

		# Set some lobby data
		var lobby_name = "Lobby hosted by: " + Steamworks.STEAM_USERNAME
		print(lobby_name)
		_append_Message(lobby_name)
		Steam.setLobbyData(lobbyID, "name", lobby_name)
		Steam.setLobbyData(lobbyID, "mode", "Gulf")

		# Allow P2P connections to fallback to being relayed through Steam if needed
		var RELAY = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: "+str(RELAY))


func _on_LobbySearch_pressed():
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
	# Show the list 
	print(lobbies)
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
	# Get the lobby members
	_get_Lobby_Members()
	# Make the initial handshake
	_make_P2P_Handshake()
	Steam.getPlayerAvatar(Steam.AVATAR_SMALL)
	$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Connecting.hide()
	if Steam.getLobbyOwner(lobbyID) == Steamworks.STEAM_ID:
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Host.show()
	else:
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Peer.show()


func _clear_playerlist():
	for node in name_list.get_children():
		node.queue_free()
	for node in status_list.get_children():
		node.queue_free()


func _get_Lobby_Members():
	# Clear your previous lobby list
	LOBBY_MEMBERS.clear()

	# Get the number of members from this lobby from Steam
	var MEMBERS = Steam.getNumLobbyMembers(STEAM_LOBBY_ID)

	# Get the data of these players from Steam
	for MEMBER in range(0, MEMBERS):

		# Get the member's Steam ID
		var MEMBER_STEAM_ID = Steam.getLobbyMemberByIndex(STEAM_LOBBY_ID, MEMBER)

		# Get the member's Steam name
		var MEMBER_STEAM_NAME = Steam.getFriendPersonaName(MEMBER_STEAM_ID)

		# Add them to the list
		LOBBY_MEMBERS.append({"steam_id":MEMBER_STEAM_ID, "steam_name":MEMBER_STEAM_NAME})
		
		var container = HBoxContainer.new()
		var player_icon = TextureRect.new()
		var member_name = Label.new()
		var member_status = Label.new()
		member_name.text = MEMBER_STEAM_NAME
		member_status.text = "Not ready"
		member_name.align = Label.ALIGN_CENTER
		member_status.align = Label.ALIGN_CENTER
		member_status.add_color_override("font_color", Color.red)
		container.name = str(MEMBER_STEAM_ID)
		container.size_flags_horizontal = 3
		container.size_flags_vertical = 1
		member_name.valign = 1
		member_name.size_flags_vertical = 3
		member_name.name = "player_name"
		member_status.name = "player_status"
		name_list.add_child(container)
		player_icon.name = "player_icon"
		var node_path = NodePath(str(MEMBER_STEAM_ID))
		name_list.get_node(node_path).add_child(player_icon)
		name_list.get_node(node_path).add_child(member_name)
		status_list.add_child(member_status)

func _on_Lobby_Data_Update(success, lobbyID, memberID, key):
	print("Success: "+str(success)+", Lobby ID: "+str(lobbyID)+", Member ID: "+str(memberID)+", Key: "+str(key))


func _on_Lobby_Message(result, user, message, type):
	# We are only concerned with who is sending the message and what the message is
	var SENDER = Steam.getFriendPersonaName(user)
	_append_Message(str(SENDER)+" :  "+str(message))

func _append_Message(message):
	$HBoxContainer/RightPanel/ChatBox/VBoxContainer/Chatlog.add_text("\n" + str(message))


func _make_P2P_Handshake():
	print("Sending P2P handshake to the lobby")
	var DATA = PoolByteArray()
	DATA.append(256)
	DATA.append_array(var2bytes({"message":"handshake", "from":Steamworks.STEAM_ID}))
	#_send_P2P_Packet(DATA, 2, 0)


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
		_clear_playerlist()

		# Wipe the Steam lobby ID then display the default lobby ID and player list title
		STEAM_LOBBY_ID = 0

		# Close session with all users
		for MEMBERS in LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(MEMBERS['steam_id'])
		
		# Clear the local lobby list
		LOBBY_MEMBERS.clear()
		
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Connecting.show()
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Host.hide()
		$HBoxContainer/LeftPanel/VBoxContainer/LobbyControl/Peer.hide()
