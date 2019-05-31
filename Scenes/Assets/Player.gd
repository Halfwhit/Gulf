extends KinematicBody2D

var max_force = 5000 
var ball_vector = Vector2()
var in_motion
var in_water
var in_yellow
var friction = 0.98
var start_point
var reset_point
var total_hits = 0

puppet var slave_position = Vector2()
var player_name
signal turn_taken

func is_a_ball(): #used for collision testing
	#warning-ignore:standalone_expression
	true

func set_player_name(playerName):
	player_name = playerName
	$Label.set_text(str(player_name))

func _ready():
	#start_point = get_parent().get_node_or_null("SpawnPoint").position
	#warning-ignore:return_value_discarded
	connect("turn_taken", self, "release_physics")
	slave_position = position

func release_physics():
	set_collision_mask_bit(0, true)

func _draw():
	if in_motion == false:
		draw_line(Vector2(), get_local_mouse_position().clamped(max_force/5), Color(0.0, 0.0, 0.0), 1.0, false)

#warning-ignore:unused_argument
func _process(delta):
		update() #calls _draw()

func _physics_process(delta):
	if is_network_master(): #if owner take turn
		#Update in_motion variable
		check_motion()
		if in_motion == false and Input.is_action_just_pressed("touch_main"): #then set vector for shot and update score
			get_new_vector()
			total_hits += 1
			global.total_score += 1
			emit_signal("turn_taken")
		
		hit_ball(delta)
		#Apply friction
		ball_vector = ball_vector.linear_interpolate(Vector2(0,0), friction * delta)
		
		rset_unreliable("slave_position", position) #update this players slave position with its actual position, so that it renders for other players
	else: #update my location for other players
		position = slave_position

func get_new_vector():
	reset_point = get("position")
	ball_vector = -get_local_mouse_position().clamped(max_force)

func set_new_vector(vector):
	ball_vector = vector

func check_motion():
	if ball_vector.length() <= 1: #if ball has nearly or has stopped moving
		ball_vector = Vector2() #resets the balls vector to an empty vector (no movement)
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
	var collision = move_and_collide(ball_vector * delta)
	if collision:
			ball_vector = ball_vector.bounce(collision.normal)
			#warning-ignore:return_value_discarded
			move_and_collide(ball_vector * delta)

func is_in_water():
	in_water = true
	ball_vector /= 4
	
func is_in_yellow():
	in_yellow = true
	ball_vector /= 4

func _on_Area2D_area_entered(area):
	if area.get_name() == "WaterArea2D":
		is_in_water()
	if area.get_name() == "YellowArea2D":
		is_in_yellow()
