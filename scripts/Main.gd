extends Node

export (PackedScene) var HeightmapTerrain
export (PackedScene) var VoxelTerrain


func _ready():
	pass
	
	
func unload_all():
	if has_node("HeightmapTerrain"):
		var scene = get_node("HeightmapTerrain")
		remove_child(scene)
		scene.queue_free()
		
	if has_node("VoxelTerrain"):
		var scene = get_node("VoxelTerrain")
		remove_child(scene)
		scene.queue_free()


func _on_TestHeightmapTerrainButton_pressed():
	#Unload all test scenes
	unload_all()
		
	#Load heightmap terrain test
	var scene = HeightmapTerrain.instance()
	add_child(scene)


func _on_TestVoxelTerrainButton_button_down():
	#Unload all test scenes
	unload_all()
	
	#Load voxel terrain test
	var scene = VoxelTerrain.instance()
	add_child(scene)
