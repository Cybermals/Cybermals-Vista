tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"HeightmapTerrain", 
		"Spatial",
		preload("HeightmapTerrain.gd"),
		preload("HeightmapTerrain.png")
	)
	
	
func _exit_tree():
	remove_custom_type("HeightmapTerrain")