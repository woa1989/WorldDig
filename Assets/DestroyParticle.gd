extends Node2D

@onready var particles: GPUParticles2D = $CPUParticles2D

func _ready():
	# 开始粒子效果
	particles.emitting = true
	
	# 设置自动销毁
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = particles.lifetime + 0.5
	timer.one_shot = true
	timer.timeout.connect(_on_destroy_timer_timeout)
	timer.start()

func _on_destroy_timer_timeout():
	"""销毁粒子效果"""
	queue_free()

func setup_particle_color(tile_type: String):
	"""根据瓦片类型设置粒子颜色"""
	if particles.process_material:
		var gradient = particles.process_material.color_ramp.gradient
		var colors = gradient.colors
		var start_color: Color
		
		match tile_type:
			"stone":
				start_color = Color(0.6, 0.6, 0.6, 1) # 灰色
			"iron_ore":
				start_color = Color(0.7, 0.5, 0.3, 1) # 铁色
			"gold_ore":
				start_color = Color(1.0, 0.8, 0.2, 1) # 金色
			"dirt":
				start_color = Color(0.6, 0.4, 0.2, 1) # 土色
			"chest":
				start_color = Color(0.8, 0.6, 0.4, 1) # 木色
			_:
				start_color = Color(0.8, 0.6, 0.4, 1) # 默认色
				
		# 应用颜色更改
		if colors.size() > 0:
			var new_colors = colors.duplicate()
			new_colors[0] = start_color
			gradient.colors = new_colors

func setup_position(world_position: Vector2):
	"""设置粒子效果的世界位置"""
	global_position = world_position
