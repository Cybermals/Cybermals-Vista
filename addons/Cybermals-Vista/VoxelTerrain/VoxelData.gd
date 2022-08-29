extends Resource

export (Vector3) var size
export (IntArray) var voxels
export (ImageTexture) var texture_atlas


func _init(
    p_size = Vector3(512, 512, 512),
    p_voxels = IntArray([]),
    p_texture_atlas = null
):
	size = p_size
	voxels = p_voxels
	texture_atlas = p_texture_atlas


func get_voxel(x, y, z):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return 0
	
	return voxels[z * size.y * size.x + y * size.x + x]
	
	
func set_voxel(x, y, z, value):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return
	
	voxels[z * size.y * size.x + y * size.x + x] = value