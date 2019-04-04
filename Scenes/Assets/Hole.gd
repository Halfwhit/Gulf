extends Node2D

func _on_HoleArea2D_body_entered(body):
	if body.get_name() == "Player":
		print("GOAAAAAAAAAAAAAAAAL!")
		#get_node("Player").hide().
