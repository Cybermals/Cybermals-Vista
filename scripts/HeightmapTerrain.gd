extends Spatial


func _ready():
	#Enable event processing
	set_process(true)
	
	
func _process(delta):
	#Display ray collision coords
	if get_node("FlyCam/RayCast").is_colliding():
		var collision_point = get_node("FlyCam/RayCast").get_collision_point()
		var height = get_node("HeightmapTerrain").get_height(collision_point.x, collision_point.z)
		#print("Ray Collision At: " + str(collision_point))
		#print("Height at Collision: " + str(height))
		
	#Move one of the vertices up and down over time
	get_node("HeightmapTerrain").set_height(64, 64, 50 * sin(deg2rad(OS.get_ticks_msec() / 100)))
