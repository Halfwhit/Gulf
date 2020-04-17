extends Node

var level = preload("res://scenes/World.tscn")

var is_host = false
var host_id

enum Packet {
	HANDSHAKE
	LEVEL_START
	VECTOR_UPDATE
	TURN_UPDATE
}

func _process(delta: float) -> void:
	_read_P2P_Packet()


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
		print("Packet: "+str(PACKET_CODE)+" "+str(READABLE))
		# Append logic here to deal with packet data
		if int(PACKET_CODE) == Packet.LEVEL_START:
			start_world()
		if int(PACKET_CODE) == Packet.VECTOR_UPDATE:
			var new_vector = READABLE.get("vector")
			var node_path = NodePath("Main/World/Players/" + PACKET_ID)
			get_tree().get_root().get_node(node_path).ball_vector = new_vector
		if int(PACKET_CODE) == Packet.TURN_UPDATE:
			if PACKET_ID == READABLE.get("ball"):
				get_tree().get_root().get_node("Main/World").ready_for_turn = true



func start_world():
	print("Starting level")
	get_tree().get_root().get_node("Main/GUI/Lobby").visible = false
	var world = level.instance()
	get_tree().get_root().get_node("Main").add_child(world)


func send_to_host_reliable(DATA):
	Steam.sendP2PPacket(int(host_id), DATA, 2, 0)
