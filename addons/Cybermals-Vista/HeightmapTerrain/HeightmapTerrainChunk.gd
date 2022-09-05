extends MeshInstance

var dirty = false


func _ready():
	#Add to chunk group
	add_to_group("HeightmapTerrainChunk")
	
	#Create static body
	var body = StaticBody.new()
	body.set_name("StaticBody")
	add_child(body)
