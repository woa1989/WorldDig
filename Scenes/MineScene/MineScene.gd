extends Node2D

@onready var dirt_layer: TileMapLayer = $Dirt
@onready var ore_layer: TileMapLayer = $Ore
@onready var player: CharacterBody2D = $Player
@onready var light_system: DirectionalLight2D = $LightSystem
@onready var background_sprite: Sprite2D = $ParallaxBackground/ParallaxLayer/Bg
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
	
	# 设置背景
	setup_background()
	
	# 设置环境光
	setup_lighting()
	
	# 创建火把光源容器
	create_torch_lights_container()
	
	# 生成地形（通过TerrainGenerator）
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
	
	# 创建火把照明
	create_torch_lights()

func setup_lighting():
	"""设置基础照明系统"""
	if light_system:
		# 设置微弱的环境光
		light_system.energy = 0.1
		light_system.color = Color(0.2, 0.2, 0.3, 1)
	
	# 保持原始深色设置以配合火把照明系统
	var canvas_modulate = $CanvasModulate
	if canvas_modulate:
		canvas_modulate.color = Color(0.1, 0.1, 0.15, 1)

func create_torch_lights_container():
	"""创建火把光源容器"""
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		add_child(torch_lights)
		print("创建火把光源容器")

func create_torch_lights():
	"""为所有火把创建光源"""
	if not dirt_layer:
		return
	
	# 创建火把光源容器
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		add_child(torch_lights)
	
	
func create_torch_light(grid_pos: Vector2):
	if active_torch_lights.has(grid_pos):
		return
	if not torch_lights:
		torch_lights = Node2D.new()
		torch_lights.name = "TorchLights"
		add_child(torch_lights)
	var world_pos = dirt_layer.map_to_local(grid_pos)
	if torch_light_scene:
		var light_instance = torch_light_scene.instantiate()
		torch_lights.add_child(light_instance)
		light_instance.global_position = world_pos
		if light_instance.has_method("setup_torch_light"):
			light_instance.setup_torch_light()
		elif light_instance is PointLight2D:
			light_instance.energy = 1.0
			light_instance.texture_scale = 2.0
			light_instance.color = Color(1.0, 0.8, 0.5, 1)
		active_torch_lights[grid_pos] = light_instance
		print("在位置", grid_pos, "创建火把光源")

func remove_torch_light(grid_pos: Vector2):
	if active_torch_lights.has(grid_pos):
		var light_instance = active_torch_lights[grid_pos]
		if light_instance and is_instance_valid(light_instance):
			light_instance.queue_free()
		active_torch_lights.erase(grid_pos)
		print("移除位置", grid_pos, "的火把光源")

func clear_all_torch_lights():
	for light_instance in active_torch_lights.values():
		if light_instance and is_instance_valid(light_instance):
			light_instance.queue_free()
	active_torch_lights.clear()
	print("清除了所有火把光源")

# 便捷的预设密度函数
func set_torch_density_low():
	"""设置低密度火把 (密度0.2, 距离8)"""
	set_torch_density(0.2)
	set_torch_distance(8)
	regenerate_torches()
	print("已设置为低密度火把")

func set_torch_density_medium():
	"""设置中等密度火把 (密度0.5, 距离5)"""
	set_torch_density(0.5)
	set_torch_distance(5)
	regenerate_torches()
	print("已设置为中等密度火把")

func set_torch_density_high():
	"""设置高密度火把 (密度0.8, 距离3)"""
	set_torch_density(0.8)
	set_torch_distance(3)
	regenerate_torches()
	print("已设置为高密度火把")

func _on_torch_created(grid_pos: Vector2):
	"""当火把被创建时的信号处理函数 - 来自TerrainGenerator的torch_created信号"""
	create_torch_light(grid_pos)

# 处理火把密度控制快捷键
func _input(event):
	# 只在矿井场景中处理这些快捷键
	if event is InputEventKey and event.pressed:
		handle_torch_density_shortcut(event.keycode)

# 工具函数：火把密度快捷键
func handle_torch_density_shortcut(keycode):
	match keycode:
		KEY_1:
			set_torch_density_low()
		KEY_2:
			set_torch_density_medium()
		KEY_3:
			set_torch_density_high()
		KEY_0:
			clear_all_torch_lights()
			if dirt_layer and dirt_layer.has_method("clear_all_torches"):
				dirt_layer.clear_all_torches()
			print("清除了所有火把")
		KEY_H:
			print("=== 火把密度控制帮助 ===")
			print("数字键1 - 低密度火把 (20%密度, 8格距离)")
			print("数字键2 - 中等密度火把 (50%密度, 5格距离)")
			print("数字键3 - 高密度火把 (80%密度, 3格距离)")
			print("数字键0 - 清除所有火把")
			print("H键 - 显示此帮助信息")

func set_torch_distance(distance: int):
	"""设置火把之间的最小距离"""
	if dirt_layer and dirt_layer.has_method("set_min_torch_distance"):
		dirt_layer.set_min_torch_distance(distance)
		print("设置火把最小距离为: ", distance)
		
func regenerate_torches():
	"""重新生成火把并更新光源"""
	if dirt_layer and dirt_layer.has_method("regenerate_torches_with_new_density"):
		# 清除现有光源
		clear_all_torch_lights()
		
		# 重新生成火把
		dirt_layer.regenerate_torches_with_new_density()
		print("重新生成了火把")

func get_tile_at_position(world_pos: Vector2) -> Dictionary:
	"""获取指定世界坐标的瓦片信息"""
	if not dirt_layer:
		return {}
	
	var grid_pos = dirt_layer.local_to_map(dirt_layer.to_local(world_pos))
	return dirt_layer.terrain_data.get(grid_pos, {})

# 挖掘功能 - 转发到 TerrainGenerator
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

# 新增 - 放置火把功能
func place_torch(world_pos: Vector2) -> bool:
	"""在指定世界位置放置火把"""
	print("MineScene: 尝试放置火把在位置", world_pos)
	
	if not dirt_layer:
		print("MineScene: 错误 - dirt_layer不存在")
		return false
		
	# 将世界坐标转换为网格坐标
	var grid_pos = dirt_layer.local_to_map(dirt_layer.to_local(world_pos))
	print("MineScene: 转换为网格坐标", grid_pos)
	
	# 首先检查原始位置
	if try_place_torch_at(grid_pos):
		return true
		
	# 如果原始位置不行，尝试周围8个方向
	print("MineScene: 尝试周围位置...")
	for x_offset in [-1, 0, 1]:
		for y_offset in [-1, 0, 1]:
			if x_offset == 0 and y_offset == 0:
				continue # 跳过原来的位置
			
			var alt_pos = Vector2i(grid_pos.x + x_offset, grid_pos.y + y_offset)
			if try_place_torch_at(alt_pos):
				return true
				
	print("MineScene: 在原始位置及周围都无法放置火把")
	return false

# 辅助函数：尝试在特定网格坐标放置火把
func try_place_torch_at(grid_pos: Vector2i) -> bool:
	# 检查是否有方块可以放置火把
	if not dirt_layer.terrain_data.has(Vector2(grid_pos.x, grid_pos.y)):
		return false
	
	# 检查是否已经有火把
	var tile_data = dirt_layer.terrain_data[Vector2(grid_pos.x, grid_pos.y)]
	if tile_data.get("has_torch", false):
		return false
	
	print("MineScene: 条件检查通过，开始放置火把在位置", grid_pos)
	
	# 检查torch_tile是否有效
	print("MineScene: torch_tile =", dirt_layer.torch_tile)
	
	# 放置火把 - 确保使用正确的torch_tile
	if dirt_layer.get("torch_tile") != null:
		dirt_layer.set_cell(grid_pos, 1, dirt_layer.torch_tile)
	else:
		# 如果dirt_layer没有torch_tile属性，使用默认值
		dirt_layer.set_cell(grid_pos, 1, Vector2i(9, 0))
	
	dirt_layer.terrain_data[Vector2(grid_pos.x, grid_pos.y)]["has_torch"] = true
	
	# 创建火把光源
	create_torch_light(Vector2(grid_pos.x, grid_pos.y))
	
	print("MineScene: 成功放置火把在位置", grid_pos)
	# 触发火把放置事件
	_on_torch_created(Vector2(grid_pos.x, grid_pos.y))
	
	return true

# 火把密度控制功能
func set_torch_density(density: float):
	"""设置火把密度 (0.1-1.0)"""
	if dirt_layer and dirt_layer.has_method("set_torch_density"):
		dirt_layer.set_torch_density(density)
		print("设置火把密度为: ", density)

func setup_background():
	"""设置背景图片"""
	if background_sprite:
		# 获取屏幕尺寸
		var viewport_size = get_viewport().get_visible_rect().size
		var texture_size = background_sprite.texture.get_size()
		
		# 计算需要的缩放比例以覆盖整个屏幕
		var scale_x = viewport_size.x / texture_size.x
		var scale_y = viewport_size.y / texture_size.y
		var scale_factor = max(scale_x, scale_y) * 2.0 # 乘以2确保覆盖更大区域
		
		background_sprite.scale = Vector2(scale_factor, scale_factor)
		
		# 获取 ParallaxLayer 并调整其 modulate 使背景在深色环境下可见
		var parallax_layer = $ParallaxBackground/ParallaxLayer
		if parallax_layer:
			# 适度提高背景亮度，保持照明系统的效果
			parallax_layer.modulate = Color(1.8, 1.8, 1.8, 1.0)
		
		print("背景设置完成，缩放比例: ", scale_factor, " 背景亮度调整: 1.8")
