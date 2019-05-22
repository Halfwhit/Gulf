extends MarginContainer

var player_score

#warning-ignore:unused_argument
func _process(delta):	
	player_score = get_parent().get_node("Player").total_hits
	
	get_node("HBoxContainer/Values/ScoreValue").text = str(player_score)
	get_node("HBoxContainer/Values/ScoreTotal").text = str(global.total_score)
	get_node("HBoxContainer/Values/HolesTotal").text = str(global.holes_completed)