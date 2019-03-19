extends Control

var TestLevel = preload("res://Scenes/Levels/TestLevel.tscn")

func _on_Test_pressed():
#warning-ignore:return_value_discarded
	get_tree().change_scene_to(TestLevel)
