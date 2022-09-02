tool
extends EditorPlugin

var EditorUI = preload("EditorUI.tscn")
var editor_ui

var edit_obj = null
var obj_type = ""


func _enter_tree():
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
	
	#Create editor UI
	editor_ui = EditorUI.instance()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE, editor_ui)
	editor_ui.hide()
	
	
func _exit_tree():
	#Free editor UI
	editor_ui.queue_free()
	
	#Unregister node types
	remove_custom_type("HeightmapTerrain")
	remove_custom_type("VoxelTerrain")
	
	
func handles(obj):
	#Do we support editing this type of object?
	var script = obj.get_script()
	
	if not script:
		return false
		
	if "Cybermals-Vista" in script.get_path():
		return true
		
		
func make_visible(visible):
	#Show editor UI?
	if visible:
		editor_ui.show()
		
	else:
		editor_ui.hide()
	
	
func edit(obj):
	edit_obj = obj
	var script = obj.get_script()
	
	#Heightmap terrain?
	if "HeightmapTerrain.gd" in script.get_path():
		obj_type = "HeightmapTerrain"
		editor_ui.get_node("HeightmappedTerrain").show()
		editor_ui.get_node("VoxelTerrain").hide()
		
	#Voxel terrain?
	elif "VoxelTerrain.gd" in script.get_path():
		obj_type = "VoxelTerrain"
		editor_ui.get_node("VoxelTerrain").show()
		editor_ui.get_node("HeightmappedTerrain").hide()
