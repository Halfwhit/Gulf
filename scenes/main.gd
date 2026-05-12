extends Node

const TEST_LEVEL = preload("uid://bofnpxvr5bqax")


func _on_physics_pressed() -> void:
	var scene = TEST_LEVEL.instantiate()
	add_child(scene)
	$UI.queue_free()


func _on_editor_pressed() -> void:
	pass # Replace with function body.
