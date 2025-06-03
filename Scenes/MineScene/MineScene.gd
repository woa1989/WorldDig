extends Node2D

@onready var dirt_layer: TileMapLayer = $Dirt
@onready var ore_layer: TileMapLayer = $Ore
@onready var player: CharacterBody2D = $Player
@onready var light_system: DirectionalLight2D = $LightSystem
var torch_lights: Node2D # 动态创建，不用@onready

# 火把照明系统
var torch_light_scene = preload("res://Scenes/LightScene/LightScene.tscn")
var active_torch_lights = {}

func _ready():
	print("MineScene _ready 开始")
	print("Dirt层: ", dirt_layer)
	print("Ore层: ", ore_layer)
	print("Player: ", player)
	
	# 等待一帧确保所有节点都初始化完成
	await get_tree().process_frame
	
	# 设置环境光
	setup_lighting()
	
	# 生成地形（通过TerrainGenerator）
	if dirt_layer:
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
	
	# 创建火把照明
	create_torch_lights()

func setup_lighting():
	"""设置基础照明系统"""
	if light_system:
		# 设置微弱的环境光
		light_system.energy = 0.1
		light_system.color = Color(0.2, 0.2, 0.3, 1)
	
	# 设置画布调制器为深色
	var canvas_modulate = $CanvasModulate
	if canvas_modulate:
		canvas_modulate.color = Color(0.05, 0.05, 0.1, 1)

func create_torch_lights():
	"""为所有火把创建光源"""
	if not dirt_layer:
		return
	
	# 创建火把光源容器
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		add_child(torch_lights)
	
	# 扫描dirt层找到所有火把
	#var used_cells = dirt_layer.get_used_cells()
	#for cell_pos in used_cells:
		#var tile_data = dirt_layer.terrain_data.get(cell_pos, {})
		#if tile_data.get("has_torch", false):
			#create_torch_light_at_position(cell_pos)

func create_torch_light_at_position(grid_pos: Vector2):
	"""在指定位置创建火把光源"""
	if active_torch_lights.has(grid_pos):
		return # 已经有光源了
	
	# 将网格坐标转换为世界坐标
	var world_pos = dirt_layer.map_to_local(grid_pos)
	
	# 创建光源实例
	if torch_light_scene:
		var light_instance = torch_light_scene.instantiate()
		torch_lights.add_child(light_instance)
		light_instance.global_position = world_pos
		
		# 设置火把光源属性
		if light_instance.has_method("setup_torch_light"):
			light_instance.setup_torch_light()
		elif light_instance is PointLight2D:
			light_instance.energy = 1.0
			light_instance.texture_scale = 2.0
			light_instance.color = Color(1.0, 0.8, 0.5, 1)
		
		active_torch_lights[grid_pos] = light_instance
		print("在位置", grid_pos, "创建火把光源")

func remove_torch_light_at_position(grid_pos: Vector2):
	"""移除指定位置的火把光源"""
	if active_torch_lights.has(grid_pos):
		var light_instance = active_torch_lights[grid_pos]
		if light_instance and is_instance_valid(light_instance):
			light_instance.queue_free()
		active_torch_lights.erase(grid_pos)
		print("移除位置", grid_pos, "的火把光源")

func dig_at_position(world_pos: Vector2) -> bool:
	"""处理挖掘请求"""
	if not dirt_layer or not dirt_layer.has_method("dig_at_position"):
		return false
	
	# 获取挖掘前的网格位置
	var grid_pos = dirt_layer.local_to_map(dirt_layer.to_local(world_pos))
	var had_torch = false
	
	if dirt_layer.terrain_data.has(grid_pos):
		had_torch = dirt_layer.terrain_data[grid_pos].get("has_torch", false)
	
	# 执行挖掘
	var success = dirt_layer.dig_at_position(world_pos)
	
	# 如果挖掘的是火把，移除光源
	if success and had_torch:
		remove_torch_light_at_position(grid_pos)
	
	return success

func _on_torch_placed(grid_pos: Vector2):
	"""当放置火把时调用"""
	create_torch_light_at_position(grid_pos)

func get_tile_at_position(world_pos: Vector2) -> Dictionary:
	"""获取指定世界坐标的瓦片信息"""
	if not dirt_layer:
		return {}
	
	var grid_pos = dirt_layer.local_to_map(dirt_layer.to_local(world_pos))
	return dirt_layer.terrain_data.get(grid_pos, {})

# 新增 - 放置火把功能
func place_torch(world_pos: Vector2) -> bool:
	"""在指定世界位置放置火把"""
	if not dirt_layer:
		return false
		
	# 将世界坐标转换为网格坐标
	var grid_pos = dirt_layer.local_to_map(dirt_layer.to_local(world_pos))
	
	# 检查是否有方块可以放置火把
	if not dirt_layer.terrain_data.has(Vector2(grid_pos.x, grid_pos.y)):
		print("没有方块可以放置火把")
		return false
	
	# 检查是否已经有火把
	var tile_data = dirt_layer.terrain_data[Vector2(grid_pos.x, grid_pos.y)]
	if tile_data.get("has_torch", false):
		print("此处已经有火把了")
		return false
	
	# 放置火把
	dirt_layer.set_cell(grid_pos, 1, dirt_layer.torch_tile)
	dirt_layer.terrain_data[Vector2(grid_pos.x, grid_pos.y)]["has_torch"] = true
	
	# 创建火把光源
	create_torch_light_at_position(Vector2(grid_pos.x, grid_pos.y))
	
	print("成功放置火把在位置", grid_pos)
	# 触发火把放置事件
	_on_torch_placed(Vector2(grid_pos.x, grid_pos.y))
	
	return true
