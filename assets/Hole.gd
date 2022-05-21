extends Node2D

func _on_HoleArea2D_body_entered(body):
	if body.is_in_group("balls"):
		if body.get_node("TriggerArea"):
			print("GOOOOAL!")
