extends MeshInstance

var dirty = false


func _ready():
	#Create static body
	var body = StaticBody.new()
	body.set_name("StaticBody")
	add_child(body)
