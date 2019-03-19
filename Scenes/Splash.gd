extends Control

var Menu = preload("res://Scenes/Menu.tscn")

func _input(event):
	
	#Skip splash screen on mouse click
	if event is InputEventMouseButton: 
		if event.button_index == BUTTON_LEFT and event.pressed:
			get_node("Splash").hide()

func _on_Timer_timeout():
	get_node("Splash").hide()


func _on_Splash_hide():
	#Show menu when splash disappears
	var menuScene = Menu.instance()
	add_child(menuScene)
