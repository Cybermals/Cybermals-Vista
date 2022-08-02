tool
extends EditorPlugin


func _enter_tree():
	add_custom_type(
		"FlyCam", 
		"Camera", 
		preload("FlyCam.gd"), 
		preload("FlyCam.png")
	)
	
	
func _exit_tree():
	remove_custom_type("FlyCam")