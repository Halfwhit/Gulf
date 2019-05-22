extends Control

func _on_Test_pressed():
#warning-ignore:return_value_discarded
	get_tree().change_scene_to(global.next_hole)


func _on_Start_pressed():
	get_tree().change_scene_to(global.next_hole)


func _on_Multi_pressed():
	get_tree().change_scene_to(global.multi_lobby)
