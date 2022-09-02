tool
extends Panel


func _ready():
	#Populate voxel type option button
	for i in range(128):
		get_node("VoxelTerrain/VoxelType").add_item(str(i + 1), i)
