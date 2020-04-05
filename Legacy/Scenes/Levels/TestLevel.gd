extends Node2D

var PlayerSpawn = preload("res://Scenes/Assets/Player.tscn")
var HoleSpawn = preload("res://Scenes/Assets/Hole.tscn")
var WaterSpawn = preload("res://Scenes/Assets/Water.tscn")
var YellowSpawn = preload("res://Scenes/Assets/Yellow.tscn")
var startPos
var pos

func _ready():
	var tileMap = get_node("TileMap")
	var size_x = tileMap.get_cell_size().x
	var size_y = tileMap.get_cell_size().y
	var tileSet = tileMap.get_tileset()
	var usedCells = tileMap.get_used_cells()

	for pos in usedCells :
		var id = tileMap.get_cell(pos.x, pos.y)
		var name = tileSet.tile_get_name(id)

		if name == "Start":
			print("Spawning Player")
			var player = PlayerSpawn.instance()
			player.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(player)
		
		if name == "Hole":
			print("Spawning Hole")
			var hole = HoleSpawn.instance()
			hole.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(hole)
		
		if name == "Water":
			print("Spawning Water")
			var water = WaterSpawn.instance()
			water.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(water)
		
		if name == "Yellow":
			print("Spawning Yellow")
			var yellow = YellowSpawn.instance()
			yellow.position = Vector2( pos.x * size_x + (0.5*size_x), pos.y * size_y + (0.5*size_y))
			add_child(yellow)
