extends KinematicBody2D

onready var Lobby = get_tree().get_root().get_node("Main/GUI/Lobby")

var MAX_FORCE = 350
var FORCE_MULTIPLIER = 5
var FRICTION = 0.98

var start_point  # Used for yellow
var reset_point  # Used for water
var ball_vector = Vector2.ZERO
var turn = false
var in_motion = false
var in_water
var in_yellow


func _ready() -> void:
	start_point = get_tree().get_root().get_node("Main/World/SpawnPoint").position


func _process(delta: float) -> void:
	$HitLine.points[1] = get_local_mouse_position().clamped(MAX_FORCE)
	check_motion()
	var start_dist = start_point.distance_to(position)
	if start_dist > 16:
		set_collision_mask_bit(0, true)


func _physics_process(delta: float) -> void:
	# Get Input
	if turn and name == str(Steamworks.STEAM_ID) and Input.is_action_just_pressed("touch_main"):
		var new_vector = -get_local_mouse_position().clamped(MAX_FORCE) * FORCE_MULTIPLIER
		send_vector_packet(new_vector, position, name)
		turn = false
		in_motion = true
	# Handle collisions
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		var collider = collision_info.collider
		if collider.is_in_group("balls"):
			ball_vector = ball_vector.bounce(collision_info.normal)/2
			send_vector_packet(-ball_vector, collider.position, collider.name)
		else:
			ball_vector = ball_vector.bounce(collision_info.normal)
	# Apply friction
	ball_vector = ball_vector.linear_interpolate(Vector2(0,0), FRICTION * delta)


func check_motion():
	if ball_vector.length() <= 1: #if ball has nearly or has stopped moving
		ball_vector = Vector2.ZERO
		if in_motion:
			in_motion = false
			send_turn_packet(position)
		if turn and name == str(Steamworks.STEAM_ID):
			$HitLine.show()
		if in_water:
			position = reset_point
			in_water = false
		if in_yellow:
			position = start_point
			in_yellow = false
		reset_point = get("position")
	else:
		$HitLine.hide()


func send_vector_packet(new_vector, pos, ball_id):
	var DATA = PoolByteArray()
	DATA.append(Lobby.Packet.VECTOR_UPDATE)
	DATA.append_array(var2bytes({"vector":new_vector, "position":pos, "ball":ball_id}))
	Lobby._send_P2P_Packet(DATA, 0, 0)


func send_turn_packet(pos):
	var DATA = PoolByteArray()
	DATA.append(Lobby.Packet.TURN_TAKEN)
	DATA.append_array(var2bytes({"position":pos, "from":Steamworks.STEAM_ID}))
	Lobby._send_P2P_Packet(DATA, 0, 0)


func _on_TriggerArea_entered(area: Area2D) -> void:
	if area.get_name() == "WaterArea2D":
		print("Water")
		is_in_water()
	if area.get_name() == "YellowArea2D":
		print("Yellow")
		is_in_yellow()


func is_in_water():
	in_water = true
	ball_vector /= 4


func is_in_yellow():
	in_yellow = true
	ball_vector /= 4
	set_collision_mask_bit(0, false)
