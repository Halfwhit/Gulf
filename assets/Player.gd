extends KinematicBody2D

onready var Lobby = get_tree().get_root().get_node("Main/GUI/Lobby")

var MAX_FORCE = 350
var FORCE_MULTIPLIER = 5
var FRICTION = 0.98

var slave_pos
var slave_vector = Vector2.ZERO
var ball_vector = Vector2.ZERO
var turn = true

func _ready() -> void:
	position = get_tree().get_root().get_node("Main/World/SpawnPoint").position
	slave_pos = position

func _process(delta: float) -> void:
	$HitLine.points[1] = get_local_mouse_position().clamped(MAX_FORCE)
	check_motion()
	# This is just used for testing, do this somewhere else properly
	if Input.is_action_just_pressed("ui_cancel"):
		print("Escape pressed, goodbye.")
		get_tree().quit()
	if Input.is_action_just_pressed("ui_select"):
		turn = true

func _physics_process(delta: float) -> void:
	# Get Input
	if turn and name == str(Steamworks.STEAM_ID) and Input.is_action_just_pressed("touch_main"):
		var new_vector = -get_local_mouse_position().clamped(MAX_FORCE) * FORCE_MULTIPLIER
		send_vector_packet(new_vector)
		turn = false
	# Handle collisions
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		ball_vector = ball_vector.bounce(collision_info.normal)
	# Apply friction
	ball_vector = ball_vector.linear_interpolate(Vector2(0,0), FRICTION * delta)

func check_motion():
	if ball_vector.length() <= 1: #if ball has nearly or has stopped moving
		ball_vector = Vector2.ZERO
		if turn and name == str(Steamworks.STEAM_ID):
			$HitLine.show()
	else:
		$HitLine.hide()

func send_vector_packet(new_vector):
	var DATA = PoolByteArray()
	DATA.append(Lobby.Packet.VECTOR_UPDATE)
	DATA.append_array(var2bytes({"vector":new_vector, "from":Steamworks.STEAM_ID}))
	Lobby._send_P2P_Packet(DATA, 0, 0)

func send_position_packet(new_position):
	pass
