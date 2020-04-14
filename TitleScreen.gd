extends CenterContainer

func start():
	visible = false
	get_tree().get_root().get_node("Main/Lobby").visible = true
