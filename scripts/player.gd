extends RigidBody2D

@export var MAX_FORCE = 300
@export var FORCE_MULTIPLIER = 3
@export var FRICTION = 0.98

var ball_vector = Vector2.ZERO
var line_visible: bool = false
var active: bool = false
var waiting: bool = false
var start_pos

signal turn_taken

func _ready() -> void:
	start_pos = position

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("touch_main") && line_visible == true:
		ball_vector = -get_local_mouse_position().limit_length(MAX_FORCE) * FORCE_MULTIPLIER
		line_visible = false
		waiting = true


func _process(_delta):
	#if position.distance_to(start_pos) > 4:
		#set_collision_mask_value(2, true)
	if line_visible:
		$HitLine.visible = true
		$HitLine.points[1] = get_local_mouse_position().limit_length(MAX_FORCE)
	else:
		$HitLine.visible = false

func _physics_process(delta):
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
	
	if  ball_vector.x < 1 && ball_vector.x > -1:
		if ball_vector.y < 1 && ball_vector.y > -1:
			ball_vector = Vector2.ZERO
			if waiting == true:
				active = false
				waiting = false
				turn_taken.emit()

func play_turn():
	active = true
	line_visible = true
	freeze = false
	$CollisionShape2D.call_deferred("set_disabled", false)
	await(turn_taken)
