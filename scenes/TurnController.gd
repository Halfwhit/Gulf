extends Node2D
class_name TurnController

var active_player

func initialise() -> void:
	active_player = get_child(0)

func player_turn() -> void:
	await(active_player.play_turn())
	var new_index: int = (active_player.get_index() + 1) % get_child_count()
	active_player = get_child(new_index)
	player_turn()
