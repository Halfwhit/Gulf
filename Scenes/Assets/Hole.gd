extends Node2D

func _on_HoleArea2D_body_entered(body):
	if body.is_in_group("Player"):
		if body.get_node("TriggerArea"):
			print("GOOOOAL!")
			#Multiplayer.player_scored(body.name, body.total_hits)
