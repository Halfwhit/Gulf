extends RigidBody2D

@export var MAX_FORCE = 300
@export var FORCE_MULTIPLIER = 3
@export var FRICTION = 0.98

@onready var hit_line: Line2D = $HitLine

var ball_vector = Vector2.ZERO
var line_visible: bool = false
var active: bool = false
var waiting: bool = false

signal turn_taken

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("touch_main") and line_visible:
		ball_vector = -get_local_mouse_position().limit_length(MAX_FORCE) * FORCE_MULTIPLIER
		line_visible = false
		waiting = true

func _process(_delta) -> void:
	if hit_line.visible != line_visible:
		hit_line.visible = line_visible
	if line_visible:
		hit_line.points[1] = get_local_mouse_position().limit_length(MAX_FORCE)

func _physics_process(delta) -> void:
	var collision_info = move_and_collide(ball_vector * delta)
	if collision_info:
		var collider = collision_info.get_collider()
		if collider.is_in_group("balls"):
			collider.ball_vector = ball_vector / 2
			ball_vector = ball_vector.bounce(collision_info.get_normal()) / 2
		else:
			ball_vector = ball_vector.bounce(collision_info.get_normal())
	ball_vector = ball_vector.lerp(Vector2.ZERO, FRICTION * delta)

	if waiting and ball_vector.length() < 1.0:
		ball_vector = Vector2.ZERO
		active = false
		waiting = false
		turn_taken.emit()

func play_turn() -> void:
	active = true
	line_visible = true
	freeze = false
	$CollisionShape2D.call_deferred("set_disabled", false)
	await turn_taken
