extends Camera2D

export var move_speed: float = 1.1
var zoom_increment: float = 0.05
var zoom_max: float = 0.5
var zoom_min: float = 1
var current_zoom = 1
var last_mouse_pos: Vector2
var dragging: bool = false

func _ready() -> void:
	make_current()

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
		if not dragging:
			last_mouse_pos = get_viewport().get_mouse_position()
			dragging = true
		get_tree().set_input_as_handled()
		move()
	else:
		dragging = false

func move():
	var current_mouse_pos = get_viewport().get_mouse_position()
	position.x -= (current_mouse_pos.x - last_mouse_pos.x)
	position.y -= (current_mouse_pos.y - last_mouse_pos.y)
	last_mouse_pos = current_mouse_pos

func _input(event):
	if event.is_action("scroll_up"):
		zoom("in")
	if event.is_action("scroll_down"):
		zoom("out")

func zoom(direction):
	match direction:
		"in":
			current_zoom -= zoom_increment
			if current_zoom < zoom_max:
				current_zoom = zoom_max
		"out":
			current_zoom += zoom_increment
			if current_zoom > zoom_min:
				current_zoom = zoom_min
	set_zoom(Vector2(current_zoom, current_zoom))
