tool
extends Spatial

signal rebuild_complete

var Chunk = preload("VoxelTerrainChunk.gd")
var voxels = IntArray([])
var rebuild_queue = []
var queue_sorted = false

export (Material) var material = null setget set_material
export (Vector3) var size = Vector3(128, 64, 128) setget set_size


func _ready():
	#Enable event processing
	set_process(true)
	yield(self, "rebuild_complete")
	
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
		#Rebuild next chunk
		var chunk = rebuild_queue.front()
		rebuild_queue.pop_front()
		_rebuild_chunk(chunk)
		
	else:
		#Emit rebuild complete signal
		emit_signal("rebuild_complete")
		
		
func set_material(value):
	material = value
	
	if get_tree():
		get_tree().call_group(
		    get_tree().GROUP_CALL_DEFAULT,
		    "VoxelTerrainChunk",
		    "set_material_override",
		    value
		)
	
	
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
		yield(get_tree(), "idle_frame")
	
	voxels.resize(size.x * size.y * size.z)
	
	#Initialize chunks
	for z in range(0, size.z, 16):
		for y in range(0, size.y, 16):
			for x in range(0, size.x, 16):
				#Create chunk
				var chunk = Chunk.new()
				chunk.set_name("Chunk" + str(Vector3(x, y, z)))
				chunk.set_material_override(material)
				chunk.set_translation(Vector3(x, y, z))
				add_child(chunk)


func _rebuild_chunk(chunk):
	#Get chunk position
	var pos = chunk.get_translation()
	
	#Generate chunk mesh and shape
	var st = SurfaceTool.new() #solids
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st2 = SurfaceTool.new() #liquids
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(16):
		for y in range(16):
			for x in range(16):
				#Skip empty voxels
				var voxel = get_voxel(pos.x + x, pos.y + y, pos.z + z)
				
				if not voxel:
					continue
					
				#Generate top side?
				if pos.y + y == size.y - 1 or not get_voxel(pos.x + x, pos.y + y + 1, pos.z + z):
					_gen_voxel_top(st, st2, Vector3(x, y, z), voxel)
					
				#Generate bottom side?
				if pos.y + y == 0 or not get_voxel(pos.x + x, pos.y + y - 1, pos.z + z):
					_gen_voxel_bottom(st, st2, Vector3(x, y, z), voxel)
					
				#Generate left side?
				if pos.x + x == 0 or not get_voxel(pos.x + x - 1, pos.y + y, pos.z + z):
					_gen_voxel_left(st, st2, Vector3(x, y, z), voxel)
					
				#Generate right side?
				if pos.x + x == size.x - 1 or not get_voxel(pos.x + x + 1, pos.y + y, pos.z + z):
					_gen_voxel_right(st, st2, Vector3(x, y, z), voxel)
					
				#Generate front side?
				if pos.z + z == size.z - 1 or not get_voxel(pos.x + x, pos.y + y, pos.z + z + 1):
					_gen_voxel_front(st, st2, Vector3(x, y, z), voxel)
					
				#Generate back side?
				if pos.z + z == 0 or not get_voxel(pos.x + x, pos.y + y, pos.z + z - 1):
					_gen_voxel_back(st, st2, Vector3(x, y, z), voxel)
					
	#Generate normals
	st.generate_normals()
	st2.generate_normals()
	
	#Generate mesh
	var mesh = st.commit()
	var shape = ConcavePolygonShape.new()
	shape.set_faces(mesh.get_faces())
	st2.commit(mesh)
	
	#Set chunk mesh and collision shape
	var body = chunk.get_node("StaticBody")
	chunk.set_mesh(mesh)
	body.clear_shapes()
	body.add_shape(shape)
	
	
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
	var chunk = get_node("Chunk" + str(chunk_pos * 16))
	
	if not chunk.dirty:
		chunk.dirty = true
		rebuild_queue.push_back(chunk)
		queue_sorted = false
	
	
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
	return cam_pos.distance_to(a.get_translation()) < cam_pos.distance_to(b.get_translation())