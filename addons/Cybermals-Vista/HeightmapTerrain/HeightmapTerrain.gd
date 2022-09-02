tool
extends Spatial

signal rebuild_progress(current, total)
signal rebuild_complete

export (Material) var material = null setget set_material
export (ImageTexture) var heightmap = null setget set_heightmap

var chunks = []
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
	rebuild_state = rebuild()
	
	
func rebuild():
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
	#Note: We use co-routines here to keep the game responsive during the 
	#terrain rebuilding process and to avoid race conditions that would 
	#occur if threads were used.
	var width = heightmap.get_width()
	var depth = heightmap.get_height()
	var image = heightmap.get_data()
	var chunk_count = (width / 64) * (depth / 64)
	
	for z in range(0, depth - 1, 64):
		var row = []
		
		for x in range(0, width - 1, 64):
			row.append(_create_chunk(Vector2(x, z), image.get_rect(Rect2(x, z, 65, 65))))
			emit_signal("rebuild_progress", (z / 64) * (depth / 64) + (x / 64), chunk_count)
			yield()
			
		chunks.append(row)
		
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
	
	
func get_height(x, z):
	#Remove scale from input coords
	x = x / get_scale().x
	z = z / get_scale().z
	
	#Do bounds check
	var size = heightmap.get_size()
	
	if x < 0 or x > size.x - 1:
		return 0
		
	if z < 0 or z > size.y - 1:
		return 0
		
	#Sample the height of the 4 points around the given coordinate
	var image = heightmap.get_data()
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
	#If the terrain is rebuilding, yield until it is rebuilt
	if is_rebuilding():
		yield(self, "rebuild_complete")
	
	#Remove scale from input coords and height
	x = int(x / get_scale().x)
	z = int(z / get_scale().z)
	h = h / get_scale().y
	
	#Update heightmap
	var image = heightmap.get_data()
	image.put_pixel(x, z, Color(h, h, h))
	heightmap.set_data(image)
	
	#Calculate which chunk contains the point and the offset within the chunk
	var cx = int(x / 64)
	var cz = int(z / 64)
	var ox = x % 64
	var oz = z % 64
	
	#Delete old chunk and generate new chunk
	chunks[cz][cx].queue_free()
	chunks[cz][cx] = _create_chunk(Vector2(cx * 64, cz * 64), image.get_rect(Rect2(cx * 64, cz * 64, 65, 65)))
	
	#Handle (literal) edge cases to prevent holes in the terrain mesh
	if not ox and cx:
		chunks[cz][cx - 1].queue_free()
		chunks[cz][cx - 1] = _create_chunk(Vector2((cx - 1) * 64, cz * 64), image.get_rect(Rect2((cx - 1) * 64, cz * 64, 65, 65)))
		
	if not oz and cz:
		chunks[cz - 1][cx].queue_free()
		chunks[cz - 1][cx] = _create_chunk(Vector2(cx * 64, (cz - 1) * 64), image.get_rect(Rect2(cx * 64, (cz - 1) * 64, 65, 65)))
		
	#Handle "corner" cases too
	if not ox and not oz and cx and cz:
		chunks[cz - 1][cx - 1].queue_free()
		chunks[cz - 1][cx - 1] = _create_chunk(Vector2((cx - 1) * 64, (cz - 1) * 64), image.get_rect(Rect2((cx - 1) * 64, (cz - 1) * 64, 65, 65)))


func is_rebuilding():
	return rebuild_state != null