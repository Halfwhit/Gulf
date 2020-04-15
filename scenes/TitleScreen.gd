extends CenterContainer

func start():
	visible = false
	get_tree().get_root().get_node("Main/GUI/Lobby").visible = true
