extends Control

func _ready():
	for p_id in Multiplayer.players:
		var name_label = Label.new()
		var score_label = Label.new()
		name_label.set_name("name_" + String(p_id))
		name_label.text = Multiplayer.players[p_id]
		score_label.set_name("score_" + String(p_id))
		score_label.text = "0"
		get_node("ScoreboardPanel/Scoreboard/Names").add_child(name_label)
		get_node("ScoreboardPanel/Scoreboard/Scores").add_child(score_label)
