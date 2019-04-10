extends Node2D

var NextLevel = load("res://Scenes/Levels/TestLevel.tscn")

func _on_HoleArea2D_body_entered(body):
	if body.get_name() == "Player":
		if body.get_node("TriggerArea"):
			global.holes_completed += 1
			get_tree().change_scene_to(NextLevel)
