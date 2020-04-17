extends Node

var level = preload("res://scenes/World.tscn")
var player_data = {}

func connect_world():
	get_tree().get_root().get_node("Main/World").connect("level_loaded", self, "start_level")

func start_level():
	print("Level Loaded")

