extends CenterContainer

func _on_Start_pressed():
	visible = false
	get_tree().get_root().get_node("Main/Lobby").visible = true
