extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const MAX_FORCE = 350
const FORCE_MULTIPLIER = 5
const FRICTION = 0.98

var ball_vector = Vector2.ZERO

func _physics_process(delta):
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		var collider = collision_info.collider
		if collider.is_in_group("balls"):
			collider.ball_vector = ball_vector/2
			ball_vector = ball_vector.bounce(collision_info.normal)/2
		else:
			ball_vector = ball_vector.bounce(collision_info.normal)
	# Apply friction
	ball_vector = ball_vector.lerp(Vector2(0,0), FRICTION * delta)
