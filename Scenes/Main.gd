extends Node

var Splash = preload("res://Scenes/Splash.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
#warning-ignore:return_value_discarded
	get_tree().change_scene_to(Splash)
