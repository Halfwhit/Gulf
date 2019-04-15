extends Node

var total_score
var holes_completed = 0
var hole_test = preload("res://Scenes/Levels/TestLevel.tscn")
var hole_1 = preload("res://Scenes/Levels/Solo/Hole1.tscn")
var hole_2 = preload("res://Scenes/Levels/Solo/Hole2.tscn")

var next_hole

func _ready():
	total_score = 0
	get_next_level()

func get_next_level():
	if holes_completed == 0:
		next_hole = hole_1
	if holes_completed == 1:
		next_hole = hole_2
	if holes_completed >= 2:
		next_hole = hole_test