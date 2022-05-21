extends Node2D

var MAX_FORCE = 350
var FORCE_MULTIPLIER = 5
var turn = false
var ball_vector


func _process(_delta: float) -> void:
	hit_line()
	get_input()
	# Dev test command
	if Input.is_action_just_pressed("ui_select"):
		turn = true


func hit_line():
	$HitLine.points[1] = get_local_mouse_position().clamped(MAX_FORCE)
	if turn and name == str(Steamworks.STEAM_ID):
		$HitLine.show()
	else:
		$HitLine.hide()

func get_input():
	if turn and name == str(Steamworks.STEAM_ID) and Input.is_action_just_pressed("touch_main"):
		ball_vector = -get_local_mouse_position().clamped(MAX_FORCE) * FORCE_MULTIPLIER
		send_vector_packet(ball_vector)
		turn = false


func send_vector_packet(new_vector):
	var DATA = PoolByteArray()
	DATA.append(Gamestate.Packet.VECTOR_UPDATE)
	DATA.append_array(var2bytes({"vector":new_vector}))
	Gamestate.send_to_host_reliable(DATA)
