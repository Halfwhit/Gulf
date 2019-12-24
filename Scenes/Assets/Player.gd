extends KinematicBody2D

var max_force = 5000 
var friction = 0.98
var ball_vector = Vector2()
var start_point # Used for yellow shit
var reset_point # Used for water
puppet var slave_position = Vector2() # Used to display position to other players

var in_motion      # Update these to signals? TODO
var in_water
var in_yellow

var total_hits = 0 # Score?

var player_name # TODO: add labels
signal turn_taken # TODO: turns

func set_player_name(setName):
	player_name = setName
	$Label.set_text(str(player_name))

func _ready():
	slave_position = position

func _draw():
	if in_motion == false: # TODO: turns
		draw_line(Vector2(), get_local_mouse_position().clamped(max_force/5), Color(0.0, 0.0, 0.0), 1.0, false)

func _process(_delta):
		update() #calls _draw() away from physics thread

func _physics_process(delta):
	if is_network_master(): #if owner take turn
		
		#Update in_motion variable
		check_motion()
		# TODO: move this out of physics thread
		if in_motion == false and Input.is_action_just_pressed("touch_main"): #then set vector for shot and update score
			get_new_vector()
			total_hits += 1
			emit_signal("turn_taken")
			set_collision_mask_bit(0, 1)
		
		#hit_ball(delta) # Apply new vector or just continue moving (I think that's how it works?)
		#Apply friction
		var collision = move_and_collide(ball_vector * delta)
		if collision:
			if collision.collider.is_class("Player.gd"):
				rpc_id(collision.collider.get_network_master(), "ball_collide", collision.remaining/2, delta)
				ball_vector = ball_vector.bounce(collision.remaining)/2
				move_and_collide(ball_vector * delta)
			else:
				ball_vector = ball_vector.bounce(collision.normal)
		ball_vector = ball_vector.linear_interpolate(Vector2(0,0), friction * delta)
		
		rset_unreliable("slave_position", position) #update this players slave position with its actual position, so that it renders for other players
	else: #update my location for other players
		position = slave_position

remote func ball_collide(new_vector, delta):
	reset_point = get("position")
	ball_vector = new_vector
	move_and_collide(ball_vector * delta)

func get_new_vector():
	ball_vector = -get_local_mouse_position().clamped(max_force)

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
		reset_point = get("position")
	else:
		in_motion = true

func hit_ball(delta):
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
