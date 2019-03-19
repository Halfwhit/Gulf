extends KinematicBody2D

var max_force = 500
var ball_vector = Vector2()
var collision
var in_motion
var friction = 0.98

func _draw():
	if in_motion == false:
		draw_line(Vector2(), get_local_mouse_position().clamped(max_force/2), Color(0.0, 0.0, 0.0), 1.0, false)

func _process(delta):
		update()

func _physics_process(delta):
	#Update in_motion variable
	check_motion()
	
	if in_motion == false and Input.is_action_just_pressed("touch_main"):
		get_new_vector()
	
	hit_ball(delta)
	
	#Apply friction
	ball_vector = ball_vector.linear_interpolate(Vector2(0,0), friction * delta)

func get_new_vector():
	ball_vector = -get_local_mouse_position().clamped(max_force)

func check_motion():
	if ball_vector.length() < 1:
		ball_vector = Vector2()
		in_motion = false
	else:
		in_motion = true

func hit_ball(delta):
	collision = move_and_collide(ball_vector * delta)
	if collision:
			ball_vector = ball_vector.bounce(collision.normal)
			move_and_collide(ball_vector * delta)