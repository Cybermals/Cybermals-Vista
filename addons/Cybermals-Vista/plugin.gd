tool
extends EditorPlugin


func _enter_tree():
	#Register resource types
	add_custom_type(
		"VoxelData",
		"Resource",
		preload("VoxelTerrain/VoxelData.gd"),
		preload("VoxelTerrain/VoxelTerrain.png")
	)
	
	#Register node types
	add_custom_type(
		"HeightmapTerrain", 
		"Spatial",
		preload("HeightmapTerrain/HeightmapTerrain.gd"),
		preload("HeightmapTerrain/HeightmapTerrain.png")
	)
	add_custom_type(
		"VoxelTerrain",
		"Spatial",
		preload("VoxelTerrain/VoxelTerrain.gd"),
		preload("VoxelTerrain/VoxelTerrain.png")
	)
	
	
func _exit_tree():
	#Unregister node types
	remove_custom_type("HeightmapTerrain")
	remove_custom_type("VoxelTerrain")
	
	#Unregister resource types
	remove_custom_type("VoxelData")