extends KinematicBody2D

var max_force = 500
var ball_vector = Vector2()
var collision
var in_motion
var in_water
var in_yellow
var friction = 0.98
var start_point
var reset_point

func _ready():
	start_point = get("position")

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
	reset_point = get("position")
	ball_vector = -get_local_mouse_position().clamped(max_force)

func set_new_vector(vector):
	ball_vector = vector

func check_motion():
	if ball_vector.length() <= 1:
		ball_vector = Vector2()
		in_motion = false
		if in_water:
			position = reset_point
			in_water = false
		if in_yellow:
			position = start_point
			in_yellow = false
	else:
		in_motion = true

func hit_ball(delta):
	collision = move_and_collide(ball_vector * delta)
	if collision:
			ball_vector = ball_vector.bounce(collision.normal)
			move_and_collide(ball_vector * delta)

func in_water():
	in_water = true
	ball_vector /= 4
	
func in_yellow():
	in_yellow = true
	ball_vector /= 4

func _on_Area2D_area_entered(area):
	if area.get_name() == "WaterArea2D":
		in_water()
	if area.get_name() == "YellowArea2D":
		in_yellow()
