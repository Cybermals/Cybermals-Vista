extends Node

var cameras = {}
var active_cam = null


func _ready():
	#Add current camera
	active_cam = get_viewport().get_camera()
	
	if active_cam:
		add_camera(active_cam)
	
	
func add_camera(cam):
	cameras[cam.get_name()] = cam
	
	
func switch_camera(name):
	#Deactivate current camera and activate new camera
	if name in cameras:
		active_cam.clear_current()
		active_cam = cameras[name]
		active_cam.make_current()
