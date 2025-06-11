extends Node2D

@onready var dirt_layer: TileMapLayer = $Dirt
@onready var ore_layer: TileMapLayer = $Ore
@onready var player: CharacterBody2D = $Player
@onready var canvas_modulate: CanvasModulate = $CanvasModulate

# 光照系统 - 使用Godot内置光照
var torch_lights: Node2D
var torch_light_scene = preload("res://Scenes/LightScene/LightScene.tscn")
var active_torch_lights = {}

func _ready():
	# 等待一帧确保所有节点都初始化完成
	await get_tree().process_frame

	# 创建火把光源容器
	create_torch_lights_container()

	# 生成地形
	if dirt_layer:
		# 连接火把创建信号
		if dirt_layer.has_signal("torch_created"):
			dirt_layer.torch_created.connect(_on_torch_created)
		
		if dirt_layer.has_method("generate_terrain"):
			print("开始地形生成")
			dirt_layer.generate_terrain()
			
			# 设置玩家位置
			if player and dirt_layer.has_method("get_player_spawn_position"):
				var spawn_pos = dirt_layer.get_player_spawn_position()
				player.global_position = spawn_pos
				print("玩家位置设置为:", spawn_pos)
				
		else:
			print("错误: dirt_layer没有generate_terrain方法")
	else:
		print("错误: dirt_layer为null")
	
	# 启动玩家深度监控定时器
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_check_player_depth)
	timer.autostart = true
	add_child(timer)


func create_torch_light(grid_pos: Vector2):
	"""创建火把光源"""
	if active_torch_lights.has(grid_pos):
		return
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		torch_lights.z_index = 1
		add_child(torch_lights)
	
	var world_pos = dirt_layer.map_to_local(grid_pos)
	
	if torch_light_scene:
		var light_instance = torch_light_scene.instantiate()
		torch_lights.add_child(light_instance)
		light_instance.global_position = world_pos
		light_instance.visible = true
		
		active_torch_lights[grid_pos] = light_instance
		print("在位置", grid_pos, "创建火把光源")

func remove_torch_light(grid_pos: Vector2):
	"""移除火把光源"""
	if active_torch_lights.has(grid_pos):
		var light_instance = active_torch_lights[grid_pos]
		if light_instance and is_instance_valid(light_instance):
			light_instance.queue_free()
		active_torch_lights.erase(grid_pos)
		print("移除位置", grid_pos, "的火把光源")

func clear_all_torch_lights():
	"""清除所有火把光源"""
	for light_instance in active_torch_lights.values():
		if light_instance and is_instance_valid(light_instance):
			light_instance.queue_free()
	active_torch_lights.clear()
	print("清除了所有火把光源")

func _on_torch_created(grid_pos: Vector2):
	"""当火把被创建时的信号处理函数"""
	create_torch_light(grid_pos)

func create_torch_lights_container():
	"""创建火把光源容器"""
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		torch_lights.z_index = 1
		add_child(torch_lights)

func dig_at_position(world_pos: Vector2) -> bool:
	"""在指定世界位置挖掘"""
	if not dirt_layer:
		print("MineScene: 错误 - dirt_layer不存在")
		return false
	
	if dirt_layer.has_method("dig_at_position"):
		return dirt_layer.dig_at_position(world_pos)
	else:
		print("MineScene: 错误 - dirt_layer没有dig_at_position方法")
		return false


func _check_player_depth():
	"""检查玩家深度并在需要时生成新地形"""
	if not player or not dirt_layer:
		return
	
	var player_depth = dirt_layer.get_player_depth_from_position(player.global_position)
	
	if dirt_layer.has_method("check_and_generate_new_layers"):
		dirt_layer.check_and_generate_new_layers(player_depth)
