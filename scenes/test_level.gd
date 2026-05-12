extends Node2D

@onready var players: TurnController = $Players

func _ready() -> void:
	players.initialise()
	players.player_turn()
