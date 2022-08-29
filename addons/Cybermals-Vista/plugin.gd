tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"HeightmapTerrain", 
		"Spatial",
		preload("HeightmapTerrain/HeightmapTerrain.gd"),
		preload("HeightmapTerrain/HeightmapTerrain.png")
	)
	
	
func _exit_tree():
	remove_custom_type("HeightmapTerrain")