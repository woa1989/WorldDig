extends Node2D

# 真实洞穴挖掘系统 - 主场景控制器

@onready var terrain_generator: TileMapLayer = $Dirt # 地形生成器
@onready var player
@onready var ui_container
@onready var money_label
@onready var camera
@onready var light_system: Node2D

# 照明系统
var torch_light_radius = 400.0 # 增大火把光照范围
var player_light_radius = 250.0 # 增大玩家光照范围

# 可见性系统
var visible_tiles = {}
var fog_overlay: CanvasLayer

# 粒子效果系统
var particle_system: Node2D

# 音效系统
var audio_player: AudioStreamPlayer2D

func _ready():
	print("MineScene _ready 开始")
	
	# 设置场景背景颜色为黑色，模拟地下洞穴
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	# 确保2D灯光渲染正确设置
	setup_2d_lighting_environment()
	
	# 等待一帧确保GameManager加载
	await get_tree().process_frame
	
	print("开始初始化系统...")
	
	# 先设置照明环境
	setup_2d_lighting_environment()
	print("照明环境设置完成")
	
	setup_terrain_generator()
	print("地形生成器设置完成")
	
	await setup_player()
	print("玩家设置完成")
	
	setup_lighting_system()
	print("照明系统设置完成")
	
	setup_ui()
	print("UI设置完成")
	
	setup_fog_system()
	print("雾系统设置完成")
	
	setup_particle_system()
	print("粒子系统设置完成")
	
	setup_audio_system()
	print("音频系统设置完成")
	
	# 更新初始可见性
	update_visibility()
	print("MineScene 初始化完成！")

func setup_terrain_generator():
	# 连接地形生成器信号
	terrain_generator.terrain_generated.connect(_on_terrain_generated)
	terrain_generator.torch_positions_updated.connect(_on_torch_positions_updated)
	
	# 开始生成地形
	terrain_generator.generate_cave_terrain()

func _on_terrain_generated():
	print("地形生成完成")

func _on_torch_positions_updated(_positions: Array):
	# 更新照明系统的火把位置
	if light_system:
		for torch_pos in _positions:
			add_torch_light(torch_pos)

func setup_player():
	player = $Player
	
	if not player:
		print("错误：找不到Player节点！")
		return
	
	# 确保玩家可见
	player.visible = true
	player.modulate = Color.WHITE
	player.z_index = 10 # 确保玩家在最上层
	
	# 创建并设置相机
	camera = Camera2D.new()
	camera.enabled = true
	player.add_child(camera)
	# 等待一帧确保相机在场景树中
	await get_tree().process_frame
	camera.make_current()
	print("相机已添加到玩家节点并设为当前相机")
	
	# 设置玩家初始位置为入口空间中央
	var entrance_chamber = terrain_generator.get_entrance_chamber_bounds()
	var entrance_pos = entrance_chamber["center_world_pos"]
	player.position = entrance_pos
	print("玩家位置设置为入口空间中央: ", entrance_pos)
	print("入口空间范围: (", entrance_chamber["start_x"], ",", entrance_chamber["start_y"], ") 大小: ", entrance_chamber["width"], "x", entrance_chamber["height"])
	print("玩家可见性: ", player.visible)
	print("玩家调制颜色: ", player.modulate)
	print("相机位置: ", camera.global_position)
	
	# 在玩家周围显示初始可见区域
	terrain_generator.reveal_area_around_position(entrance_pos, 3)

func add_torch_light(pos: Vector2):
	if not light_system:
		return
	
	var light = PointLight2D.new()
	light.energy = 0.8
	light.texture_scale = torch_light_radius / 100.0
	light.color = Color(1.0, 0.8, 0.6, 1.0) # 暖黄色光
	light.position = Vector2(pos.x * terrain_generator.tile_size + float(terrain_generator.tile_size) / 2.0, pos.y * terrain_generator.tile_size + float(terrain_generator.tile_size) / 2.0) # 居中放置
	light_system.add_child(light)

func update_visibility():
	# 更新玩家周围瓦片的可见性
	if not player or not terrain_generator:
		return
	
	var player_tile = Vector2i(player.position / terrain_generator.tile_size)
	var visibility_radius = 8
	
	for x in range(player_tile.x - visibility_radius, player_tile.x + visibility_radius + 1):
		for y in range(player_tile.y - visibility_radius, player_tile.y + visibility_radius + 1):
			if x >= 0 and x < terrain_generator.map_width and y >= 0 and y < terrain_generator.map_height:
				var tile_key = Vector2(x, y)
				visible_tiles[tile_key] = true

func dig_at_position(world_pos: Vector2):
	if not terrain_generator:
		return false
		
	# 直接传递世界坐标给地形生成器
	return terrain_generator.dig_tile(world_pos)

func check_teleport_collision():
	if not player or not terrain_generator:
		return
		
	var player_tile_pos = Vector2i(player.position / terrain_generator.tile_size)
	
	if player_tile_pos.x < 0 or player_tile_pos.x >= terrain_generator.map_width or player_tile_pos.y < 0 or player_tile_pos.y >= terrain_generator.map_height:
		return
	
	if terrain_generator.terrain_data.has(player_tile_pos.x) and terrain_generator.terrain_data[player_tile_pos.x].has(player_tile_pos.y):
		var terrain_type = terrain_generator.terrain_data[player_tile_pos.x][player_tile_pos.y]
		if terrain_type == terrain_generator.TerrainType.TELEPORT_BACK:
			print("玩家踩到传送点，返回城镇")
			get_tree().change_scene_to_file("res://Scenes/TownScene/TownScene.tscn")

func _process(_delta):
	# 定期检查玩家位置（减少频率以提高性能）
	if get_tree().get_frame() % 60 == 0:
		update_visibility()
	
	# 检测玩家是否踩到传送点
	check_teleport_collision()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# ESC键返回城镇
		var game_manager = get_node("/root/GameManager")
		if game_manager:
			game_manager.change_scene("res://Scenes/TownScene/TownScene.tscn")
		else:
			get_tree().change_scene_to_file("res://Scenes/TownScene/TownScene.tscn")

func setup_lighting_system():
	light_system = $LightSystem
	if not light_system:
		light_system = Node2D.new()
		light_system.name = "LightSystem"
		add_child(light_system)
	
	# 创建玩家光照
	setup_player_light()
	
	# 为火把创建光照
	if terrain_generator:
		for torch_pos in terrain_generator.torch_positions:
			add_torch_light(torch_pos)

func setup_player_light():
	if not player:
		return
	
	var player_light = PointLight2D.new()
	player_light.energy = 1.0
	player_light.texture_scale = player_light_radius / 100.0 # 光照半径调整
	player_light.color = Color(1.0, 1.0, 0.9, 1.0) # 略微偏白的光
	player.add_child(player_light)

func setup_ui():
	ui_container = $UI
	# 注意：UI节点中没有MoneyLabel子节点，如果需要请添加到场景中
	# money_label = $UI/MoneyLabel
	
	if money_label:
		# 连接GameManager的金币更新信号
		var game_manager = get_node("/root/GameManager")
		if game_manager:
			game_manager.money_changed.connect(_on_money_changed)
			# 设置初始金币显示
			money_label.text = "金币: " + str(game_manager.money)
	
	# 添加提示文本
	var hint_label = Label.new()
	hint_label.text = "WASD移动 | J键向下挖掘 | 鼠标左键挖掘指定位置 | ESC返回城镇"
	hint_label.position = Vector2(20, 80)
	hint_label.add_theme_color_override("font_color", Color.YELLOW)
	ui_container.add_child(hint_label)

func _on_money_changed(new_amount):
	if money_label:
		money_label.text = "金币: " + str(new_amount)

func setup_fog_system():
	# 创建雾系统 - 简单版本，只显示玩家周围可见的区域
	fog_overlay = CanvasLayer.new()
	fog_overlay.layer = 10 # 确保在最上层
	add_child(fog_overlay)

func setup_particle_system():
	particle_system = Node2D.new()
	particle_system.name = "ParticleSystem"
	add_child(particle_system)

func setup_audio_system():
	audio_player = AudioStreamPlayer2D.new()
	audio_player.name = "AudioPlayer"
	add_child(audio_player)

func setup_2d_lighting_environment():
	# 设置2D照明环境
	if terrain_generator:
		# 确保瓦片地图可以被灯光照亮
		terrain_generator.light_mask = 1
	
	# 设置环境光为很暗的灰色
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.1, 1.0))
