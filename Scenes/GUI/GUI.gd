extends MarginContainer

var player_score
var holes_total

func _process(delta):	
	player_score = get_parent().get_node("Player").total_hits
	holes_total = "Not yet implemented"
	
	get_node("HBoxContainer/Values/ScoreValue").text = str(player_score)
	get_node("HBoxContainer/Values/HolesTotal").text = str(holes_total)