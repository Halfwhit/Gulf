extends Node2D

signal ball_in_yellow
signal ball_reset

func _on_Timer_timeout():
	print("emitting reset")
	emit_signal("ball_reset")

func _on_WaterArea2D_body_entered(body):
	if body.get_name() == "Player":
		print("emitting")
		emit_signal("ball_in_water")
		get_node("Timer").start()
		print("counting")