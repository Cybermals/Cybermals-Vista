tool
extends Spatial

signal rebuild_progress(current, total)
signal rebuild_complete

var image = null

export (Material) var material = null setget set_material
export (ImageTexture) var heightmap = null setget set_heightmap

var rebuild_state = null


func _ready():
	#Enable event processing
	set_process(true)
	
	
func _process(delta):
	#Resume terrain rebuilding
	if rebuild_state:
		rebuild_state = rebuild_state.resume()
	
	
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
	image = heightmap.get_data()
	
	#Free old chunks
	if get_tree():
		get_tree().call_group(
			get_tree().GROUP_CALL_DEFAULT, 
			"HeightmapTerrainChunk", 
			"queue_free"
		)
		
	#Initialize chunks
	for z in range(0, image.get_width() - 1, 64):
		for x in range(0, image.get_height() - 1, 64):
			#Create new chunk
			var chunk = MeshInstance.new()
			chunk.set_name("Chunk" + str(Vector2(x, z)))
			chunk.add_to_group("HeightmapTerrainChunk")
			chunk.set_material_override(material)
			chunk.set_translation(Vector3(x, 0.0, z))
			add_child(chunk)
			
			#Create static body
			var body = StaticBody.new()
			body.set_name("StaticBody")
			chunk.add_child(body)
			
	rebuild_state = rebuild()
	
	
func rebuild():
	#Skip terrain rebuilding if no height data
	if image == null:
		return
	
	#Rebuild terrain
	#Note: We use co-routines here to keep the game responsive during the 
	#terrain rebuilding process and to avoid race conditions that would 
	#occur if threads were used.
	var width = image.get_width()
	var depth = image.get_height()
	var chunk_count = (width / 64) * (depth / 64)
	
	for z in range(0, depth - 1, 64):
		for x in range(0, width - 1, 64):
			_create_chunk(Vector2(x, z), image.get_rect(Rect2(x, z, 65, 65)))
			emit_signal("rebuild_progress", (z / 64) * (depth / 64) + (x / 64), chunk_count)
			yield()
		
	#Emit rebuild complete signal
	emit_signal("rebuild_complete")
			
			
func _create_chunk(pos, image):
	#Generate mesh
	#Note: Each terrain chunk is 64 tiles by 64 tiles, so we need 65 
	#vertices in each of the 2 dimensions.
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
	
	#Set chunk mesh and generate new collision shape
	var chunk = get_node("Chunk" + str(pos))
	var body = chunk.get_node("StaticBody")
	chunk.set_mesh(st.commit())
	body.add_shape(chunk.get_mesh().create_trimesh_shape())
	
	
func get_height(x, z):
	#Remove scale from input coords
	x = x / get_scale().x
	z = z / get_scale().z
	
	#Do bounds check
	var size = Vector2(image.get_width(), image.get_height())
	
	if x < 0 or x > size.x - 1:
		return 0
		
	if z < 0 or z > size.y - 1:
		return 0
		
	#Sample the height of the 4 points around the given coordinate
	var h1 = image.get_pixel(floor(x), floor(z)).r
	var h2 = image.get_pixel(ceil(x), floor(z)).r
	var h3 = image.get_pixel(floor(x), ceil(z)).r
	var h4 = image.get_pixel(ceil(x), ceil(z)).r
	
	#Now calculate the difference between the left and right pairs of heights
	var dx1 = h2 - h1
	var dx2 = h4 - h3
	
	#Then calculate the front and back heights at the given X coordinate
	var xfactor = ceil(x) - floor(x)
	var hx1 = h1 + dx1 * xfactor
	var hx2 = h3 + dx2 * xfactor
	
	#And now we calculate the height at the given point
	var zfactor = ceil(z) - floor(z)
	return (hx1 + (hx2 - hx1) * zfactor) * get_scale().y


func set_height(x, z, h):
	pass