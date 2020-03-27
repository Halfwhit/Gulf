extends KinematicBody2D

var max_force = 5000 
var friction = 0.98
var ball_vector = Vector2()
var start_point
var reset_point # Used for water
puppet var slave_position = Vector2() # Used to display position to other players
var player_name
var total_hits = 0 # Score
var in_motion      # Update these to signals?
var in_water
var in_yellow
var start_dist
remotesync var turn = false
var in_turn = false
signal turn_taken(p_id)

func set_player_name(setName):
	$Name.set_text(str(setName))
	player_name = setName

func _ready():
	slave_position = position
	start_point =  get_node("/root/world/SpawnPoint").get_position()

func _draw():
	if is_network_master() and turn == true and in_motion == false:
		draw_line(Vector2(), get_local_mouse_position().clamped(max_force/5), Color(0.0, 0.0, 0.0), 1.0, false)

func _process(_delta):
		update() #calls _draw() away from physics thread
		check_motion()
		toggle_scoreboard()
		toggle_names()
		start_dist = start_point.distance_to(position)
		if start_dist > 8:
			set_collision_mask_bit(0, 1)

func toggle_scoreboard():
	if Input.is_action_just_pressed("scoreboard"):
		get_node("/root/world/GUI/GameUI").show()
	if Input.is_action_just_released("scoreboard"):
		get_node("/root/world/GUI/GameUI").hide()

func toggle_names():
	if Input.is_action_just_pressed("show_names"):
		get_node("Name").show()
	if Input.is_action_just_released("show_names"):
		get_node("Name").hide()

func _physics_process(delta):
	if is_network_master(): #if owner take turn
		if turn == true and in_motion == false and Input.is_action_just_pressed("touch_main"):
			take_turn()
		var collision_info = move_and_collide(ball_vector * delta)
		if collision_info:
			var collider = collision_info.collider
			if collider.is_in_group("Player"):
				collider.rpc_unreliable("ball_collide", ball_vector/2)
				ball_vector = ball_vector.bounce(collision_info.normal)/2
			else:
				ball_vector = ball_vector.bounce(collision_info.normal)
		ball_vector = ball_vector.linear_interpolate(Vector2(0,0), friction * delta) #Apply friction
		rset_unreliable("slave_position", position) #update this players slave position with its actual position, so that it renders for other players
	else: 
		position = slave_position #update my location for other players

func take_turn():
	ball_vector = -get_local_mouse_position().clamped(max_force)
	total_hits += 1
	in_turn = true
	emit_signal("turn_taken", name)

remote func ball_collide(new_vector):
	ball_vector = ball_vector + new_vector

func check_motion():
	if ball_vector.length() <= 1: #if ball has nearly or has stopped moving
		ball_vector = Vector2() #resets the balls vector to an empty vector (no movement)
		in_motion = false
		if in_turn == true:
			get_node("/root/world").rpc("turn_taken", name)
			in_turn = false
		if in_water:
			position = reset_point
			in_water = false
		if in_yellow:
			position = start_point
			in_yellow = false
		reset_point = get("position")
	else:
		in_motion = true

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
