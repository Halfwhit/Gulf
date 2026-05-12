extends RigidBody2D

@export var MAX_FORCE = 350
@export var FORCE_MULTIPLIER = 5
@export var FRICTION = 0.98

var ball_vector = Vector2.ZERO
var draw_line: bool = false
var active: bool = false
var waiting: bool = false


signal turn_taken

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("touch_main") && draw_line == true:
		ball_vector = -get_local_mouse_position().limit_length(MAX_FORCE) * FORCE_MULTIPLIER
		draw_line = false
		waiting = true
		print("Hit made")

func _process(delta):
	if draw_line:
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
	draw_line = true
	await(turn_taken)
