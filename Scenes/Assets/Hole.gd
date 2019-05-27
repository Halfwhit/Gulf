extends Node2D

func _on_HoleArea2D_body_entered(body):
	if body.has_method("is_a_ball"):
		if body.get_node("TriggerArea"):
			print("GOOOOAL!")
			multiGlobal.player_scored()
