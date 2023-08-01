extends CharacterBody2D

const MAX_FORCE = 350
const FORCE_MULTIPLIER = 5
const FRICTION = 0.98

var ball_vector = Vector2.ZERO

func _process(delta):
	$HitLine.points[1] = get_local_mouse_position().limit_length(MAX_FORCE)

func _physics_process(delta):
	if Input.is_action_just_pressed("touch_main"):
		ball_vector = -get_local_mouse_position().limit_length(MAX_FORCE) * FORCE_MULTIPLIER
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		var collider = collision_info.get_collider()
		if collider.is_in_group("balls"):
			collider.ball_vector = ball_vector/2
			ball_vector = ball_vector.bounce(collision_info.get_normal())/2
		else:
			ball_vector = ball_vector.bounce(collision_info.get_normal())
	# Apply friction
	ball_vector = ball_vector.lerp(Vector2(0,0), FRICTION * delta)
