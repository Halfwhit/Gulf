extends KinematicBody2D

var MAX_FORCE = 300
var FORCE_MULTIPLIER = 3
var FRICTION = 0.98

var ball_vector = Vector2.ZERO
var in_motion = false

func _ready() -> void:
	position = get_tree().get_root().get_node("Main/World/SpawnPoint").position

func _draw():
	if name == str(Steamworks.STEAM_ID):
		draw_line(Vector2(), get_local_mouse_position().clamped(MAX_FORCE), Color(0.0, 0.0, 0.0), 1.0, false)

func _process(delta: float) -> void:
	update()  # Calls _draw() every frame
	if Input.is_action_just_pressed("ui_cancel"):
		print("Escape pressed, goodbye.")
		get_tree().quit()

func _physics_process(delta: float) -> void:
	# Get Input
	if Input.is_action_just_pressed("touch_main"):
		ball_vector = -get_local_mouse_position().clamped(MAX_FORCE) * FORCE_MULTIPLIER
	# Handle collisions
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		ball_vector = ball_vector.bounce(collision_info.normal)
	# Apply friction
	ball_vector = ball_vector.linear_interpolate(Vector2(0,0), FRICTION * delta)
	
func check_motion():
	if ball_vector.length() <= 1: #if ball has nearly or has stopped moving
		ball_vector = Vector2.ZERO
		in_motion = false
