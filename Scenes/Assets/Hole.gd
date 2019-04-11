extends Node2D

func _on_HoleArea2D_body_entered(body):
	if body.get_name() == "Player":
		if body.get_node("TriggerArea"):
			global.holes_completed += 1
			global.get_next_level()
			get_tree().change_scene_to(global.next_hole)
