extends Spatial

signal rebuild_progress(current, total)
signal rebuild_complete

var voxels = IntArray([])

export (Vector3) var size = Vector3(512, 64, 512) setget set_size
export (Material) var material = null setget set_material

var chunks = []
var rebuild_state = null


func _ready():
	for z in range(512):
		for y in range(64):
			for x in range(512):
				if y == 63:
					set_voxel(x, y, z, 2)
					
				else:
					set_voxel(x, y, z, 1)
	
	rebuild_state = rebuild()
	
	#Enable event processing
	set_process(true)
	
	
func _process(delta):
	#Resume terrain rebuilding
	if rebuild_state:
		rebuild_state = rebuild_state.resume()
	
	
func get_voxel(x, y, z):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return 0
		
	return voxels[z * size.x * size.y + y * size.x + x]
	
	
func set_voxel(x, y, z, value):
	#Do bounds check
	if x < 0 or x >= size.x or y < 0 or y >= size.y or z < 0 or z >= size.z:
		return
		
	voxels[z * size.x * size.y + y * size.x + x] = value
	
	
func set_size(value):
	size = value
	voxels.resize(size.x * size.y * size.z)
	
	
func set_material(value):
	material = value
	
	if get_tree():
		get_tree().call_group(
		    get_tree().GROUP_CALL_DEFAULT,
		    "VoxelTerrainChunk",
		    "set_material_override",
		    value
		)
	
	
func rebuild():
	#Skip rebuilding if there is no voxel data
	if voxels == null:
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
	for z in range(0, size.z, 16):
		var layer = []
		
		for y in range(0, size.y, 16):
			var row = []
			
			for x in range(0, size.x, 16):
				row.append(_create_chunk(Vector3(x, y, z)))
				emit_signal("rebuild_progress", z * size.x * size.y + y * size.x + x, voxels.size())
				yield()
				
			layer.append(row)
			
		chunks.append(layer)
		
	#Emit rebuild complete signal
	emit_signal("rebuild_complete")


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
	var chunk = MeshInstance.new()
	chunk.set_name("Chunk")
	chunk.add_to_group("VoxelTerrainChunk")
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