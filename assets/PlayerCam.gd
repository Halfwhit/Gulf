extends Camera2D

var zoom_increment = 1.1

func _input(event):
	if event.is_action("scroll_up"):
		zoom("in")
	if event.is_action("scroll_down"):
		zoom("out")

func zoom(direction):
	var current_zoom = get_zoom()
	match direction:
		"in":
			set_zoom(current_zoom * (1/zoom_increment))
		"out":
			set_zoom(current_zoom * zoom_increment)
