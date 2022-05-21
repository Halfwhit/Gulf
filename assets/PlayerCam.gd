extends Camera2D

export var camera_target: NodePath
onready var target = get_node(camera_target)
export var move_speed: float = 1.1
var zoom_increment: float = 1.1
var last_mouse_pos: Vector2
var dragging: bool = false

func _ready() -> void:
	if get_parent().name == str(Steamworks.STEAM_ID):
		make_current()

func _input(event):
	if event.is_action("scroll_up"):
		zoom("in")
	if event.is_action("scroll_down"):
		zoom("out")

func _process(_delta: float) -> void:
	if Input.is_mouse_button_pressed(BUTTON_RIGHT) or Input.is_mouse_button_pressed(BUTTON_MIDDLE):
		if not dragging:
			last_mouse_pos = get_viewport().get_mouse_position()
			dragging = true
		move()
	else:
		dragging = false
		self.global_position = target.position

func zoom(direction):
	var current_zoom = get_zoom()
	match direction:
		"in":
			set_zoom(current_zoom * (1/zoom_increment))
		"out":
			set_zoom(current_zoom * zoom_increment)

func move():
	var current_mouse_pos = get_viewport().get_mouse_position()
	self.position.x -= (current_mouse_pos.x - last_mouse_pos.x)
	self.position.y -= (current_mouse_pos.y - last_mouse_pos.y)
	last_mouse_pos = current_mouse_pos
