extends Camera

export (float) var move_speed = 8
export (float) var look_speed = 128
export (float) var slowdown_factor = .5
export (Vector3) var rotation = Vector3()


func _ready():
	#Enable event handling
	set_fixed_process(true)
	
	
func _fixed_process(delta):
	#Ignore input if not current
	if not is_current():
		return
		
	#Handle input
	var move_vec = Vector3()
	
	if Input.is_action_pressed("move_forward"):
		move_vec.z = -1
		
	elif Input.is_action_pressed("move_backward"):
		move_vec.z = 1
		
	if Input.is_action_pressed("move_left"):
		move_vec.x = -1
		
	elif Input.is_action_pressed("move_right"):
		move_vec.x = 1
		
	if Input.is_action_pressed("move_up"):
		move_vec.y = 1
		
	elif Input.is_action_pressed("move_down"):
		move_vec.y = -1
		
	if Input.is_action_pressed("look_left"):
		rotation.y += look_speed * delta
		
	elif Input.is_action_pressed("look_right"):
		rotation.y += -look_speed * delta
		
	if Input.is_action_pressed("look_up"):
		rotation.x += look_speed * delta
		
	elif Input.is_action_pressed("look_down"):
		rotation.x += -look_speed * delta
		
	#Update movement
	set_rotation(Vector3())
	rotate_y(-deg2rad(rotation.y))
	rotate_x(-deg2rad(rotation.x))
	set_translation(get_translation() + move_vec.rotated(Vector3(0.0, 1.0, 0.0), -deg2rad(rotation.y)) * move_speed * (slowdown_factor if Input.is_action_pressed("move_slow") else 1.0) * delta)
