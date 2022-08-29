extends Spatial

export (Resource) var voxel_data = null setget set_voxel_data

var material = preload("VoxelTerrainMaterial.tres")
var chunks = []


func _ready():
	pass
	
	
func set_voxel_data(value):
	voxel_data = value
	rebuild()
	
	
func rebuild():
	#Skip rebuilding if there is no voxel data
	if not voxel_data:
		return
		
	#Free old chunks
	if get_tree():
		get_tree().call_group(
		    get_tree().GROUP_CALL_DEFAULT,
		    "VoxelTerrainChunk",
		    "queue_free"
		)
		chunks.clear()
		
	#Rebuild terrain
	for z in range(0, voxel_data.size.z, 64):
		var layer = []
		
		for y in range(0, voxel_data.size.y, 64):
			var row = []
			
			for x in range(0, voxel_data.size.x, 64):
				row.append(_create_chunk(Vector3(x, y, z)))
				
			layer.append(row)
			
		chunks.append(layer)


func _create_chunk(pos):
	#Generate chunk mesh and shape
	var st = SurfaceTool.new() #solids
	var st2 = SurfaceTool.new() #liquids
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(pos.z, pos.z + 64):
		for y in range(pos.y, pos.y + 64):
			for x in range(pos.x, pos.x + 64):
				#Skip empty voxels
				var voxel = voxel_data.get_voxel(x, y, z)
				
				if not voxel:
					continue
					
				#Generate top side?
				if y == voxel_data.size.y or not voxel_data.get_voxel(x, y + 1, z):
					_gen_voxel_top(st, Vector3(x, y, z), voxel)
					
				#Generate bottom side?
				if y == 0 or not voxel_data.get_voxel(x, y - 1, z):
					_gen_voxel_bottom(st, Vector3(x, y, z), voxel)
					
				#Generate left side?
				if x == 0 or not voxel_data.get_voxel(x - 1, y, z):
					_gen_voxel_left(st, Vector3(x, y, z), voxel)
					
				#Generate right side?
				if x == voxel_data.size.x or not voxel_data.get_voxel(x + 1, y, z):
					_gen_voxel_right(st, Vector3(x, y, z), voxel)
					
				#Generate front side?
				if z == voxel_data.size.z or not voxel_data.get_voxel(x, y, z + 1):
					_gen_voxel_front(st, Vector3(x, y, z), voxel)
					
				#Generate back side?
				if z == 0 or not voxel_data.get_voxel(x, y, z - 1):
					_gen_voxel_back(st, Vector3(x, y, z), voxel)
					
	#<========
	
	#Create mesh instance
	var chunk = MeshInstance.new()
	chunk.set_name("Chunk")
	chunk.add_to_group("VoxelTerrainChunk")
	chunk.set_material_override(material)
	chunk.set_translation(pos)
	add_child(chunk)
	
	#Generate static body
	
	
func _gen_voxel_top(st, st2, pos, voxel):
	pass
	
	
func _gen_voxel_bottom(st, st2, pos, voxel):
	pass
	
	
func _gen_voxel_left(st, st2, pos, voxel):
	pass
	
	
func _gen_voxel_right(st, st2, pos, voxel):
	pass
	
	
func _gen_voxel_front(st, st2, pos, voxel):
	pass
	
	
func _gen_voxel_back(st, st2, pos, voxel):
	pass