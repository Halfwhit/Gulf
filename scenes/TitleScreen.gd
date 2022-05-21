extends CenterContainer

var LevelEditor = preload("res://scenes/Editor.tscn")

func start():
	visible = false
	get_tree().get_root().get_node("Main/GUI/Lobby").visible = true


func _on_Editor_pressed() -> void:
	var level_editor = LevelEditor.instance()
	get_tree().get_root().add_child(level_editor)
	visible = false
