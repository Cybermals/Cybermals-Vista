extends Node

export (PackedScene) var HeightmapTerrain


func _ready():
	pass
	
	
func unload_all():
	if has_node("HeightmapTerrain"):
		get_node("HeightmapTerrain").queue_free()


func _on_TestHeightmapTerrainButton_pressed():
	#Unload all test scenes
	unload_all()
		
	#Load heightmap terrain test
	var scene = HeightmapTerrain.instance()
	add_child(scene)
