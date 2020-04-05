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

remotesync func update_score():
	print("update_score called")
	for p_id in Multiplayer.players:
		var score_nodepath = NodePath("ScoreboardPanel/Scoreboard/Scores/score_" + str(p_id))
		var score_node = get_node(score_nodepath)
		print(score_node.get_network_master())
		var player_nodepath = NodePath("/root/players/" + str(p_id))
		var player_node = get_node(player_nodepath)
		print(player_node.get_network_master())
		score_node.set_text(str(player_node.total_hits))
