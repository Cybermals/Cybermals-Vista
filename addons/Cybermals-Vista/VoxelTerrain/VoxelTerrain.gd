extends Spatial

signal rebuild_progress(current, total)
signal rebuild_complete

var voxels = IntArray([])
var chunks = []

export (Vector3) var size = Vector3(512, 64, 512) setget set_size
export (Material) var material = null setget set_material

var Chunk = preload("VoxelTerrainChunk.gd")
var queue_sorted = false
var rebuild_queue = []


func _ready():
	#Enable event processing
	set_process(true)
	
	for z in range(size.z):
		for y in range(size.y):
			for x in range(size.x):
				if y == 63:
					set_voxel(x, y, z, 2)
					
				else:
					set_voxel(x, y, z, 1)
					
					
func _process(delta):
	#Does the rebuild queue need to be sorted?
	if not queue_sorted:
		rebuild_queue.sort_custom(self, "_by_distance")
		queue_sorted = true
	
	#Are there chunks to rebuild?
	if not rebuild_queue.empty():
		#Get next chunk to rebuild
		var chunk_pos = rebuild_queue.front()
		rebuild_queue.pop_front()
		
		#Free old chunk and build new chunk
		var chunks_size = size / 16
		var i = chunk_pos.x * chunks_size.x * chunks_size.y + chunk_pos.y * chunks_size.x + chunk_pos.x
		
		if chunks[i]:
			chunks[i].queue_free()
			
		chunks[i] = _create_chunk(chunk_pos * 16)
		
	else:
		#Emit rebuild complete signal
		emit_signal("rebuild_complete")
	
	
func get_voxel(x, y, z):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return 0
		
	#Return the given voxel
	return voxels[z * size.x * size.y + y * size.x + x]
	
	
func set_voxel(x, y, z, value):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return
		
	#Set the given voxel
	voxels[z * size.x * size.y + y * size.x + x] = value
	
	#Queue the containing chunk for rebuilding if it isn't already
	var chunk_pos = Vector3(int(x / 16), int(y / 16), int(z / 16))
	var chunks_size = size / 16
	var chunk = chunks[chunk_pos.z * chunks_size.x * chunks_size.y + chunk_pos.y * chunks_size.x + chunk_pos.x]
	
	if chunk == null:
		rebuild_queue.append(chunk_pos)
		queue_sorted = false
		
	elif chunk != null and not chunk.dirty:
		chunk.dirty = true
		rebuild_queue.append(chunk_pos)
		queue_sorted = false
	
	
func set_size(value):
	size = value
	
	#Clear the rebuild queue, clear the chunk list, free existing chunks,
	#resize the voxel array, and resize the chunk array
	rebuild_queue.clear()
	
	if get_tree():
		get_tree().call_group(
		    get_tree().GROUP_CALL_DEFAULT,
		    "VoxelTerrainChunk",
		    "queue_free"
		)
	
	voxels.resize(size.x * size.y * size.z)
	chunks.resize((size.x / 16) * (size.y / 16) * (size.z / 16))
	
	#Fill the chunk array with placeholders
	for i in range(chunks.size()):
		chunks[i] = Chunk.new()
	
	
func set_material(value):
	material = value
	
	if get_tree():
		get_tree().call_group(
		    get_tree().GROUP_CALL_DEFAULT,
		    "VoxelTerrainChunk",
		    "set_material_override",
		    value
		)


func _create_chunk(pos):
	#Generate chunk mesh and shape
	var st = SurfaceTool.new() #solids
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st2 = SurfaceTool.new() #liquids
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(pos.z, pos.z + 16):
		for y in range(pos.y, pos.y + 16):
			for x in range(pos.x, pos.x + 16):
				#Skip empty voxels
				var voxel = get_voxel(x, y, z)
				
				if not voxel:
					continue
					
				#Generate top side?
				if y == size.y or not get_voxel(x, y + 1, z):
					_gen_voxel_top(st, st2, Vector3(x, y, z) - pos, voxel)
					
				#Generate bottom side?
				if y == 0 or not get_voxel(x, y - 1, z):
					_gen_voxel_bottom(st, st2, Vector3(x, y, z) - pos, voxel)
					
				#Generate left side?
				if x == 0 or not get_voxel(x - 1, y, z):
					_gen_voxel_left(st, st2, Vector3(x, y, z) - pos, voxel)
					
				#Generate right side?
				if x == size.x or not get_voxel(x + 1, y, z):
					_gen_voxel_right(st, st2, Vector3(x, y, z) - pos, voxel)
					
				#Generate front side?
				if z == size.z or not get_voxel(x, y, z + 1):
					_gen_voxel_front(st, st2, Vector3(x, y, z) - pos, voxel)
					
				#Generate back side?
				if z == 0 or not get_voxel(x, y, z - 1):
					_gen_voxel_back(st, st2, Vector3(x, y, z) - pos, voxel)
					
	#Generate normals
	st.generate_normals()
	st2.generate_normals()
	
	#Generate mesh
	var mesh = st.commit()
	var shape = ConcavePolygonShape.new()
	shape.set_faces(mesh.get_faces())
	st2.commit(mesh)
	
	#Create mesh instance
	var chunk = Chunk.new()
	chunk.set_mesh(mesh)
	chunk.set_material_override(material)
	chunk.set_translation(pos)
	add_child(chunk)
	
	#Generate static body
	var body = StaticBody.new()
	body.add_shape(shape)
	chunk.add_child(body)
	
	#Generate collision shape
	var col_shape = CollisionShape.new()
	col_shape.set_shape(shape)
	body.add_child(col_shape)
	
	
func _gen_voxel_top(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(0, 0, 0)
	var v2 = Vector3(1, 0, 0)
	var v3 = Vector3(1, 0, 1)
	var v4 = Vector3(0, 0, 1)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0.03125, 0)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0, 0.03125)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _gen_voxel_bottom(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(0, -1, 0)
	var v2 = Vector3(0, -1, 1)
	var v3 = Vector3(1, -1, 1)
	var v4 = Vector3(1, -1, 0)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0, 0.03125)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0.03125, 0)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32 + 1) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _gen_voxel_left(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(0, 0, 0)
	var v2 = Vector3(0, 0, 1)
	var v3 = Vector3(0, -1, 1)
	var v4 = Vector3(0, -1, 0)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0.03125, 0)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0, 0.03125)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32 + 2) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _gen_voxel_right(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(1, 0, 0)
	var v2 = Vector3(1, -1, 0)
	var v3 = Vector3(1, -1, 1)
	var v4 = Vector3(1, 0, 1)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0, 0.03125)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0.03125, 0)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32 + 3) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _gen_voxel_front(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(0, 0, 1)
	var v2 = Vector3(1, 0, 1)
	var v3 = Vector3(1, -1, 1)
	var v4 = Vector3(0, -1, 1)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0.03125, 0)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0, 0.03125)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32 + 4) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _gen_voxel_back(st, st2, pos, voxel):
	var type = voxel - 1
	
	var v1 = Vector3(0, 0, 0)
	var v2 = Vector3(0, -1, 0)
	var v3 = Vector3(1, -1, 0)
	var v4 = Vector3(1, 0, 0)
	
	var uv1 = Vector2(0, 0)
	var uv2 = Vector2(0, 0.03125)
	var uv3 = Vector2(0.03125, 0.03125)
	var uv4 = Vector2(0.03125, 0)
	
	var uv_inc = Vector2((type % 32) * 0.03125, floor(type / 32 + 5) * 0.03125)
	
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	st.add_uv(uv2 + uv_inc)
	st.add_vertex(v2 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv3 + uv_inc)
	st.add_vertex(v3 + pos)
	st.add_uv(uv4 + uv_inc)
	st.add_vertex(v4 + pos)
	st.add_uv(uv1 + uv_inc)
	st.add_vertex(v1 + pos)
	
	
func _by_distance(a, b):
	#Get current camera position
	var cam_pos = get_viewport().get_camera().get_translation()
	
	#Compare distance from the camera
	return cam_pos.distance_to(a) < cam_pos.distance_to(b)