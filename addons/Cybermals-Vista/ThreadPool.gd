extends Object

var queue = []
var lock = Mutex.new()
var threads = []
var is_running = true


func _init():
	#Start the worker threads
	for i in range(4):
		var thread = Thread.new()
		thread.start(self, "_thread_proc")
		threads.append(thread)
	
	
func _notification(type):
	#Pre-delete?
	if type == NOTIFICATION_PREDELETE:
		#Stop all worker threads
		is_running = false
		
		for thread in threads:
			if thread.is_active():
				thread.wait_to_finish()
	
	
func _thread_proc(data):
	print("Worker thread starting...")
	
	while is_running:
		#Fetch next job
		var job = get_job()
		
		#Sleep for a bit if there was no job
		if job == null:
			OS.delay_msec(100)
			continue
			
		#Execute the job
		print("Executing a job...")
		job[0].call(job[1], job[2])
		
		
	print("Worker thread terminating...")
	
	
func queue_job(obj, method, data = null):
	lock.lock()
	queue.push_back([obj, method, data])
	lock.unlock()
	
func get_job():
	lock.lock()
	var job = null
	
	if not queue.empty():
		job = queue.front()
		queue.pop_front()
	
	lock.unlock()
	return job
	
	
func get_queue_size():
	lock.lock()
	var queue_size = queue.size()
	lock.unlock()
	return queue_size
