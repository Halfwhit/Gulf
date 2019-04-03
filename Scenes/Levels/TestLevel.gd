extends Node2D

var PlayerSpawn = preload("res://Scenes/Assets/Player.tscn")

func _ready():
	var tilemap = get_node("TileMap")
	var sizex = tilemap.get_cell_size().x
	var sizey = tilemap.get_cell_size().y
	var tileset = tilemap.get_tileset()
	var usedcells = tilemap.get_used_cells()

	for pos in usedcells :
		var id = tilemap.get_cell(pos.x, pos.y)
		var name = tileset.tile_get_name(id)

		if name == "Start":
			var player = PlayerSpawn.instance()
			player.position = Vector2( pos.x * sizex + (0.5*sizex), pos.y * sizey + (0.5*sizey))
			add_child(player)

func _on_Hole_body_entered(body):
	if body.get_name() == "Player":
		print("GOAAAAAAAAAAAAAAAAL!")
		#get_node("Player").hide()