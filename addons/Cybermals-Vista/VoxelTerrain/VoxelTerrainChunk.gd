extends MeshInstance

var dirty = false


func _ready():
	#Set name and group
	set_name("Chunk")
	add_to_group("VoxelTerrainChunk")
