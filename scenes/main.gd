extends Node

const TEST_LEVEL = preload("uid://bofnpxvr5bqax")
const LEVEL_EDITOR = preload("uid://dwi2j3ulk5npk")

func _on_physics_pressed() -> void:
	var scene = TEST_LEVEL.instantiate()
	add_child(scene)
	$UI.queue_free()


func _on_editor_pressed() -> void:
	var scene = LEVEL_EDITOR.instantiate()
	add_child(scene)
	$UI.queue_free()
