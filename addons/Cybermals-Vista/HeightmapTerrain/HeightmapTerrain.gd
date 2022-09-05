tool
extends Spatial

signal rebuild_complete

var Chunk = preload("HeightmapTerrainChunk.gd")
var image = null
var rebuild_queue = []

export (Material) var material = null setget set_material
export (ImageTexture) var heightmap = null setget set_heightmap


func _ready():
	#Enable event processing
	set_process(true)
	
	
func _process(delta):
	#Are there chunks to rebuild?
	if not rebuild_queue.empty() and image != null:
		#Rebuild next chunk
		var chunk = rebuild_queue.front()
		rebuild_queue.pop_front()
		_rebuild_chunk(chunk)
		
	else:
		#Emit rebuild complete signal
		emit_signal("rebuild_complete")
	
	
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
	
	#Return if there is no heightmap
	if not heightmap:
		return
		
	#Cache heightmap image
	image = heightmap.get_data()
	
	#Free old chunks
	rebuild_queue.clear()
	
	if get_tree():
		get_tree().call_group(
			get_tree().GROUP_CALL_DEFAULT, 
			"HeightmapTerrainChunk", 
			"queue_free"
		)
		yield(get_tree(), "idle_frame")
		
	#Initialize chunks
	for z in range(0, image.get_width() - 1, 64):
		for x in range(0, image.get_height() - 1, 64):
			#Create new chunk
			var chunk = Chunk.new()
			chunk.set_name("Chunk" + str(Vector2(x, z)))
			chunk.set_material_override(material)
			chunk.set_translation(Vector3(x, 0.0, z))
			add_child(chunk)
			
			#Queue chunk for rebuilding
			chunk.dirty = true
			rebuild_queue.push_back(chunk)


func _rebuild_chunk(chunk):
	#Get rebuild region
	var chunk_pos = chunk.get_translation()
	var pos = Vector2(chunk_pos.x, chunk_pos.z)
	var region = image.get_rect(Rect2(pos.x, pos.y, 65, 65))
	
	#Generate mesh
	#Note: Each terrain chunk is 64 tiles by 64 tiles, so we need 65 
	#vertices in each of the 2 dimensions.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for z in range(65):
		for x in range(65):
			st.add_uv((pos + Vector2(x, z)) / heightmap.get_size())
			st.add_vertex(Vector3(x, region.get_pixel(x, z).r, z))
			
	for z in range(64):
		for x in range(64):
			st.add_index(z * 65 + x)
			st.add_index(z * 65 + x + 1)
			st.add_index((z + 1) * 65 + x + 1)
			st.add_index((z + 1) * 65 + x + 1)
			st.add_index((z + 1) * 65 + x)
			st.add_index(z * 65 + x)
			
	st.generate_normals()
	var mesh = st.commit()
	
	#Generate collision shape
	var shape = ConcavePolygonShape.new()
	shape.set_faces(mesh.get_faces())
	
	#Set chunk mesh and generate new collision shape
	var body = chunk.get_node("StaticBody")
	chunk.set_mesh(mesh)
	body.clear_shapes()
	body.add_shape(shape)
	chunk.dirty = false
	
	
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
	#Adjust height value based on terrain height scale
	h = h / get_scale().y
	
	#Do bounds check
	var size = Vector2(image.get_width(), image.get_height())
	
	if x < 0 or x > size.x - 1:
		return
		
	if z < 0 or z > size.y - 1:
		return
		
	#Update heightmap image
	image.put_pixel(x, z, Color(h, h, h))
	
	#Calculate which chunk was modified
	var cx = int(x / 64)
	var cz = int(z / 64)
	var ox = x % 64
	var oz = z % 64
	
	#Queue the chunk for rebuilding if it isn't already
	var chunk = get_node("Chunk" + str(Vector2(cx * 64, cz * 64)))
	
	if not chunk.dirty:
		chunk.dirty = true
		rebuild_queue.push_back(chunk)
		
	#Handle (literal) edge cases
	if not ox and cx:
		chunk = get_node("Chunk" + str(Vector2((cx - 1) * 64, cz * 64)))
		
		if not chunk.dirty:
			chunk.dirty = true
			rebuild_queue.push_back(chunk)
			
	if not oz and cz:
		chunk = get_node("Chunk" + str(Vector2(cx * 64, (cz - 1) * 64)))
		
		if not chunk.dirty:
			chunk.dirty = true
			rebuild_queue.push_back(chunk)
			
	#Handle corner cases too
	if not ox and cx and not oz and cz:
		chunk = get_node("Chunk" + str(Vector2((cx - 1) * 64, (cz - 1) * 64)))
		
		if not chunk.dirty:
			chunk.dirty = true
			rebuild_queue.push_back(chunk)
			
			
func save_heightmap(filename):
	image.save_png(filename)
