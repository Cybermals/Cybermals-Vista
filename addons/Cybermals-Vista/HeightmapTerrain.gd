tool
extends Spatial

export (Material) var material = null setget set_material
export (ImageTexture) var heightmap = null setget set_heightmap

var chunks = []


func _ready():
	pass
	
	
func set_material(value):
	material = value
	
	if not get_tree():
		return
		
	get_tree().call_group(
		get_tree().GROUP_CALL_DEFAULT, 
		"HeightmapTerrainChunk", 
		"set_material_override", 
		material
	)
	
	
func set_heightmap(value):
	heightmap = value
	
	#Skip terrain rebuilding if no heightmap
	if not heightmap:
		return
		
	#Free old chunks
	if get_tree():
		get_tree().call_group(
			get_tree().GROUP_CALL_DEFAULT, 
			"HeightmapTerrainChunk", 
			"queue_free"
		)
		chunks.clear()
	
	#Rebuild terrain
	var width = heightmap.get_width()
	var depth = heightmap.get_height()
	var image = heightmap.get_data()
	
	for z in range(0, depth - 1, 64):
		var row = []
		
		for x in range(0, width - 1, 64):
			row.append(_create_chunk(Vector2(x, z), image.get_rect(Rect2(x, z, 65, 65))))
			
		chunks.append(row)
			
			
func _create_chunk(pos, image):
	#Generate mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(65):
		for x in range(65):
			st.add_uv((pos + Vector2(x, z)) / heightmap.get_size())
			st.add_vertex(Vector3(x, image.get_pixel(x, z).r, z))
			
	for z in range(64):
		for x in range(64):
			st.add_index(z * 65 + x)
			st.add_index(z * 65 + x + 1)
			st.add_index((z + 1) * 65 + x + 1)
			st.add_index((z + 1) * 65 + x + 1)
			st.add_index((z + 1) * 65 + x)
			st.add_index(z * 65 + x)
			
	st.generate_normals()
	
	#Generate mesh instance
	var chunk = MeshInstance.new()
	chunk.set_name("Chunk")
	chunk.add_to_group("HeightmapTerrainChunk")
	chunk.set_mesh(st.commit())
	chunk.set_material_override(material)
	chunk.set_translation(Vector3(pos.x, 0.0, pos.y))
	add_child(chunk)
	
	#Generate static body
	var body = StaticBody.new()
	body.add_shape(chunk.get_mesh().create_trimesh_shape())
	chunk.add_child(body)
	
	var colshape = CollisionShape.new()
	colshape.set_shape(body.get_shape(0))
	body.add_child(colshape)
	
	return chunk
