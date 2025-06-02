extends TileMapLayer

# 地形生成器 - 挂载到Dirt TileMapLayer上
# 负责生成洞穴地形、管理地形数据和瓦片显示

# 地形数据
var terrain_data = {}
var current_durability = {}
var dig_progress = {}

# 地图参数
var tile_size = 128
var map_width = 40
var map_height = 30

# 洞穴生成参数
var cave_entrance_y = 5 # 洞穴入口深度
var cave_height = 20 # 洞穴垂直高度

# source:1 
var dirt = Vector2(4, 0) # 泥土瓦片位置
var ground = Vector2(0, 0) # 墙壁瓦片位置
var stone = Vector2(18, 0) # 石头瓦片位置
var chest = Vector2(8, 0) # 宝箱瓦片位置
var light = Vector2(20, 0) # 火把瓦片位置

# 材料类型和耐久度
enum TerrainType {
	AIR,
	DIRT,
	STONE,
	CHEST,
	TORCH,
	RARE_ORE,
	COAL,
	TELEPORT_BACK, # 传送回城
	PLATFORM # 不可挖掘的平台
}

var terrain_durability = {
	TerrainType.DIRT: 1, # 泥土需要挖1次
	TerrainType.STONE: 3, # 石头需要挖3次
	TerrainType.CHEST: 1, # 宝箱挖1次
	TerrainType.TORCH: - 1, # 火把不可破坏
	TerrainType.RARE_ORE: 4, # 稀有矿石需要4次
	TerrainType.COAL: 2, # 煤炭需要2次
	TerrainType.TELEPORT_BACK: - 1, # 传送点不可破坏
	TerrainType.PLATFORM: - 1 # 平台不可破坏
}

# 火把位置数组，供照明系统使用
var torch_positions = []

# 光照相关参数
var PLAYER_LIGHT_RADIUS = 4
var TORCH_LIGHT_RADIUS = 3
var light_map: Array # 存储每个格子的亮度
var is_lit_map: Array # 存储每个格子是否被照亮

signal terrain_generated
signal torch_positions_updated(positions: Array)

func _ready():
	print("TerrainGenerator _ready 开始")
	
	# 确保tilemap有正确的TileSet
	setup_tileset()
	
	# 等待一帧确保所有系统准备就绪
	await get_tree().process_frame
	
	# 生成地形
	generate_cave_terrain()
	
	print("TerrainGenerator 初始化完成！")
	
	initialize_light_maps()

func setup_tileset():
	if tile_set == null:
		var tileset_path = "res://Scenes/MineScene/terrain_tileset.tres"
		if ResourceLoader.exists(tileset_path):
			tile_set = load(tileset_path)
			print("加载了地形tileset")
		else:
			print("使用场景默认tileset")

func generate_cave_terrain():
	print("开始生成SteamWorld Dig风格地形...")
	
	# 初始化地形数据结构
	for x in range(map_width):
		terrain_data[x] = {}
		current_durability[x] = {}
	
	# 生成地表层（空气）
	generate_surface_layer()
	print("地表层生成完成")
	
	# 生成地下分层结构
	generate_underground_layers()
	print("地下分层生成完成")
	
	# 生成边界墙壁
	generate_boundary_walls()
	print("边界墙壁生成完成")
	
	# 生成宝箱和特殊资源
	generate_treasures_and_resources()
	print("宝箱和资源生成完成")
	
	# 只显示边界和入口引导，不显示所有地形
	display_initial_terrain()
	print("初始地形显示完成")
	
	# 发送信号通知地形生成完成
	terrain_generated.emit()
	torch_positions_updated.emit(torch_positions)

func read_existing_tiles():
	# 读取场景中已经存在的瓦片数据，避免覆盖用户手动绘制的内容
	print("读取已存在的瓦片数据...")
	
	# 初始化地形数据结构
	for x in range(map_width):
		terrain_data[x] = {}
		current_durability[x] = {}
	
	# 扫描整个地图，读取已存在的瓦片
	var existing_tile_count = 0
	var teleport_tiles_found = 0
	
	for x in range(map_width):
		for y in range(map_height):
			var tile_pos = Vector2i(x, y)
			var source_id = get_cell_source_id(tile_pos)
			var atlas_coords = get_cell_atlas_coords(tile_pos)
			
			if source_id != -1: # 该位置有瓦片
				# 根据瓦片的source_id和atlas_coords推断地形类型
				var terrain_type = get_terrain_type_from_tile(source_id, atlas_coords)
				
				# 特殊处理：如果用户在通道区域绘制了特定瓦片，可能是传送点
				if is_teleport_tile(x, y, source_id, atlas_coords):
					terrain_type = TerrainType.TELEPORT_BACK
					teleport_tiles_found += 1
					print("在位置 (", x, ",", y, ") 发现传送点")
				
				terrain_data[x][y] = terrain_type
				current_durability[x][y] = terrain_durability[terrain_type]
				existing_tile_count += 1
			else:
				# 该位置为空气
				terrain_data[x][y] = TerrainType.AIR
				current_durability[x][y] = 0
	
	print("已读取", existing_tile_count, "个现有瓦片，其中包含", teleport_tiles_found, "个传送点")

func is_teleport_tile(_x, _y, source_id, atlas_coords):
	# 判断指定位置的瓦片是否为传送点
	if source_id == 1 and atlas_coords == Vector2i(0, 0):
		return true
	return false

func get_terrain_type_from_tile(source_id, atlas_coords):
	# 根据瓦片的source_id和atlas_coords推断地形类型 - 只识别土、石头和宝箱
	if source_id == 1: # 优先检查source 1
		if atlas_coords == Vector2i(4, 0): # 泥土
			return TerrainType.DIRT
		elif atlas_coords == Vector2i(17, 0): # 石头
			return TerrainType.STONE
		elif atlas_coords == Vector2i(20, 0): # 宝箱
			return TerrainType.CHEST
		else:
			return TerrainType.STONE # 默认为石头
	elif source_id == 0: # source 0，兼容旧数据
		if atlas_coords == Vector2i(1, 2): # 泥土
			return TerrainType.DIRT
		elif atlas_coords == Vector2i(0, 2): # 石头
			return TerrainType.STONE
		else:
			return TerrainType.STONE # 默认为石头
	else:
		return TerrainType.STONE # 默认为石头

func generate_surface_layer():
	# 生成地表层（空气层）
	for x in range(map_width):
		for y in range(cave_entrance_y):
			terrain_data[x][y] = TerrainType.AIR
			current_durability[x][y] = 0
	
	# 在入口处创建一个2x4的初始挖掘空间
	create_entrance_chamber()

var entrance_position: Vector2

func create_entrance_chamber():
	# 生成入口平台
	var platform_width: int = 5 # 平台宽度
	var platform_start_x: int = int(map_width / 2) - int(platform_width / 2)
	var platform_y: int = 3 # 平台高度位置
	var center_x: int = int(platform_width / 2)
	
	# 生成初始平台
	for x in range(platform_width):
		var platform_x = platform_start_x + x
		if x != center_x: # 中间留空
			terrain_data[platform_x][platform_y] = TerrainType.PLATFORM
		else:
			terrain_data[platform_x][platform_y] = TerrainType.AIR
			
	# 在平台上方创建空气
	for x in range(platform_width):
		var platform_x = platform_start_x + x
		for y in range(platform_y):
			terrain_data[platform_x][y] = TerrainType.AIR
			
	# 放置火把
	place_torch(platform_start_x - 1, platform_y)
	place_torch(platform_start_x + platform_width, platform_y)
	
	# 记录入口位置
	entrance_position = Vector2(int(map_width / 2), platform_y)
	
func place_torch(x: int, y: int):
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		terrain_data[x][y] = TerrainType.TORCH

func create_entrance_guidance_terrain(start_x: int, start_y: int, chamber_width: int, chamber_height: int):
	# 在入口空间周围创建易挖掘的泥土作为挖掘引导
	var guidance_radius = 2
	
	for x in range(start_x - guidance_radius, start_x + chamber_width + guidance_radius):
		for y in range(start_y + chamber_height, start_y + chamber_height + guidance_radius):
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				# 确保这个位置不在入口空间内
				var in_chamber = (x >= start_x and x < start_x + chamber_width and
								y >= start_y and y < start_y + chamber_height)
				
				if not in_chamber:
					# 在入口下方和周围创建泥土，便于玩家开始挖掘
					if y == start_y + chamber_height: # 紧贴入口底部的一行都是泥土
						terrain_data[x][y] = TerrainType.DIRT
						current_durability[x][y] = terrain_durability[TerrainType.DIRT]
					elif abs(x - (start_x + chamber_width / 2.0)) <= 3: # 入口中央下方3格范围内主要是泥土
						if randf() < 0.8: # 80%概率是泥土
							terrain_data[x][y] = TerrainType.DIRT
							current_durability[x][y] = terrain_durability[TerrainType.DIRT]
	
	print("入口引导地形创建完成")

func generate_underground_layers():
	# 生成分层地下结构
	for x in range(map_width):
		for y in range(cave_entrance_y, map_height):
			var depth = y - cave_entrance_y
			var terrain_type = get_terrain_type_by_depth(depth, x, y)
			terrain_data[x][y] = terrain_type
			current_durability[x][y] = terrain_durability[terrain_type]

func get_terrain_type_by_depth(depth: int, _x: int, _y: int) -> TerrainType:
	# 根据深度和位置确定地形类型 - 只生成土和石头
	var noise_value = randf()
	
	# 浅层（0-15格）：主要是泥土
	if depth < 15:
		if noise_value < 0.85:
			return TerrainType.DIRT
		else:
			return TerrainType.STONE
	
	# 中层（15-25格）：泥土和石头混合
	elif depth < 25:
		if noise_value < 0.6:
			return TerrainType.DIRT
		else:
			return TerrainType.STONE
	
	# 深层（25格以上）：主要是石头，少量泥土
	else:
		if noise_value < 0.3:
			return TerrainType.DIRT
		else:
			return TerrainType.STONE

func generate_boundary_walls():
	# 生成不可挖掘的边界墙壁
	for y in range(map_height):
		# 左右边界
		terrain_data[0][y] = TerrainType.STONE
		terrain_data[map_width - 1][y] = TerrainType.STONE
		current_durability[0][y] = -1 # -1表示不可挖掘
		current_durability[map_width - 1][y] = -1
	
	for x in range(map_width):
		# 底部边界
		terrain_data[x][map_height - 1] = TerrainType.STONE
		current_durability[x][map_height - 1] = -1

func generate_treasures_and_resources():
	# 生成宝箱和特殊资源
	generate_treasure_chests()
	generate_torches()

func display_all_terrain():
	# 显示所有地形瓦片
	for x in range(map_width):
		for y in range(map_height):
			var terrain_type = terrain_data[x][y]
			if terrain_type != TerrainType.AIR:
				var source_id = get_source_id_for_terrain(terrain_type)
				var tile_vector = get_tile_vector_for_terrain(terrain_type)
				set_cell(Vector2i(x, y), source_id, tile_vector)

func display_initial_terrain():
	# 只显示边界和入口引导区域，其他地形保持隐藏直到被挖掘
	# 显示地图边界（让玩家知道边界在哪）
	for y in range(map_height):
		# 左右边界
		var left_terrain = terrain_data[0][y]
		var right_terrain = terrain_data[map_width - 1][y]
		
		if left_terrain != TerrainType.AIR:
			var source_id = get_source_id_for_terrain(left_terrain)
			var tile_vector = get_tile_vector_for_terrain(left_terrain)
			set_cell(Vector2i(0, y), source_id, tile_vector)
		
		if right_terrain != TerrainType.AIR:
			var source_id = get_source_id_for_terrain(right_terrain)
			var tile_vector = get_tile_vector_for_terrain(right_terrain)
			set_cell(Vector2i(map_width - 1, y), source_id, tile_vector)
	
	# 显示底部边界
	for x in range(map_width):
		var bottom_terrain = terrain_data[x][map_height - 1]
		if bottom_terrain != TerrainType.AIR:
			var source_id = get_source_id_for_terrain(bottom_terrain)
			var tile_vector = get_tile_vector_for_terrain(bottom_terrain)
			set_cell(Vector2i(x, map_height - 1), source_id, tile_vector)
	
	# 显示入口空间周围的引导地形，让玩家知道可以挖掘的区域
	var entrance_x = map_width / 2.0 # 使用浮点除法避免警告
	var chamber_width = 2
	var chamber_height = 4
	var start_x = int(entrance_x) - int(chamber_width / 2.0)
	var start_y = cave_entrance_y - 1
	
	# 显示入口空间底部和周围的泥土引导
	for x in range(start_x - 2, start_x + chamber_width + 2):
		for y in range(start_y + chamber_height, start_y + chamber_height + 3):
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				var terrain_type = terrain_data[x][y]
				if terrain_type != TerrainType.AIR:
					var source_id = get_source_id_for_terrain(terrain_type)
					var tile_vector = get_tile_vector_for_terrain(terrain_type)
					set_cell(Vector2i(x, y), source_id, tile_vector)
	
	print("只显示了边界和入口引导区域")

func reveal_area_around_position(center_pos: Vector2, radius: int = 2):
	# 在指定位置周围显示地形（用于玩家初始视野）
	var center_tile = Vector2i(center_pos / tile_size)
	
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var x = center_tile.x + dx
			var y = center_tile.y + dy
			
			# 确保坐标有效
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				var terrain_type = terrain_data[x][y]
				if terrain_type != TerrainType.AIR:
					var source_id = get_source_id_for_terrain(terrain_type)
					var tile_vector = get_tile_vector_for_terrain(terrain_type)
					set_cell(Vector2i(x, y), source_id, tile_vector)
	
	# 同时显示附近的火把
	for torch_pos in torch_positions:
		var distance = abs(torch_pos.x - center_tile.x) + abs(torch_pos.y - center_tile.y)
		if distance <= radius + 1:
			var source_id = get_source_id_for_terrain(TerrainType.TORCH)
			var tile_vector = get_tile_vector_for_terrain(TerrainType.TORCH)
			set_cell(Vector2i(torch_pos.x, torch_pos.y), source_id, tile_vector)

func generate_treasure_chests():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 在地下随机生成宝箱
	var chest_count = 0
	var max_chests = 12
	
	for attempt in range(100): # 最多尝试100次
		if chest_count >= max_chests:
			break
			
		var x = rng.randi_range(2, map_width - 3)
		var y = rng.randi_range(cave_entrance_y + 10, map_height - 3)
		
		# 检查该位置是否适合放置宝箱（不是空气且不是边界）
		if terrain_data[x][y] != TerrainType.AIR and terrain_data[x][y] != TerrainType.CHEST:
			# 深度越深，宝箱出现概率越高
			var depth = y - cave_entrance_y
			var chest_probability = min(0.8, depth * 0.02)
			
			if rng.randf() < chest_probability:
				terrain_data[x][y] = TerrainType.CHEST
				current_durability[x][y] = terrain_durability[TerrainType.CHEST]
				chest_count += 1
				print("在位置 (", x, ",", y, ") 生成宝箱")
	
	print("总共生成了", chest_count, "个宝箱")

func generate_torches():
	torch_positions.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 在地下随机生成火把照明
	var torch_count = 0
	var max_torches = 20
	
	for attempt in range(150): # 最多尝试150次
		if torch_count >= max_torches:
			break
			
		var x = rng.randi_range(3, map_width - 4)
		var y = rng.randi_range(cave_entrance_y + 5, map_height - 5)
		
		# 在石头或泥土位置放置火把，分布要相对均匀
		if (terrain_data[x][y] == TerrainType.STONE or terrain_data[x][y] == TerrainType.DIRT):
			# 检查附近是否已有火把（避免过于密集）
			var too_close = false
			for existing_torch in torch_positions:
				var distance = abs(existing_torch.x - x) + abs(existing_torch.y - y)
				if distance < 8: # 最小间距8格
					too_close = true
					break
			
			if not too_close:
				terrain_data[x][y] = TerrainType.TORCH
				torch_positions.append(Vector2(x, y))
				torch_count += 1
				print("在位置 (", x, ",", y, ") 生成火把")
	
	print("总共生成了", torch_count, "个火把")

# 移除不再使用的函数

# 移除不再使用的函数

func initialize_essential_tiles():
	# 只初始化边界和关键位置的瓦片，而不是全部显示
	print("初始化边界瓦片...")
	
	# 初始化地图边界（确保边界是石头墙）
	for y in range(map_height):
		# 左右边界
		terrain_data[0][y] = TerrainType.STONE
		terrain_data[map_width - 1][y] = TerrainType.STONE
		current_durability[0][y] = terrain_durability[TerrainType.STONE]
		current_durability[map_width - 1][y] = terrain_durability[TerrainType.STONE]
		
		# 设置边界瓦片
		var source_id = get_source_id_for_terrain(TerrainType.STONE)
		var tile_vector = get_tile_vector_for_terrain(TerrainType.STONE)
		set_cell(Vector2i(0, y), source_id, tile_vector)
		set_cell(Vector2i(map_width - 1, y), source_id, tile_vector)
	
	for x in range(map_width):
		# 底部边界
		terrain_data[x][map_height - 1] = TerrainType.STONE
		current_durability[x][map_height - 1] = terrain_durability[TerrainType.STONE]
		
		# 设置底部边界瓦片
		var source_id = get_source_id_for_terrain(TerrainType.STONE)
		var tile_vector = get_tile_vector_for_terrain(TerrainType.STONE)
		set_cell(Vector2i(x, map_height - 1), source_id, tile_vector)
	
	# 初始化火把位置的瓦片
	for torch_pos in torch_positions:
		var source_id = get_source_id_for_terrain(TerrainType.TORCH)
		var tile_vector = get_tile_vector_for_terrain(TerrainType.TORCH)
		set_cell(Vector2i(torch_pos.x, torch_pos.y), source_id, tile_vector)
	
	# 在入口附近添加一些泥土作为引导
	var entrance_x = map_width / 2.0 # 使用浮点除法避免警告
	for x in range(int(entrance_x) - 2, int(entrance_x) + 3):
		for y in range(cave_entrance_y, cave_entrance_y + 3):
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				if terrain_data[x][y] == TerrainType.STONE:
					terrain_data[x][y] = TerrainType.DIRT
					current_durability[x][y] = terrain_durability[TerrainType.DIRT]
					
					# 显示泥土瓦片
					var source_id = get_source_id_for_terrain(TerrainType.DIRT)
					var tile_vector = get_tile_vector_for_terrain(TerrainType.DIRT)
					set_cell(Vector2i(x, y), source_id, tile_vector)
	
	print("边界和关键瓦片初始化完成")

# 光照系统相关函数
func initialize_light_maps():
	light_map = []
	is_lit_map = []
	for x in range(map_width):
		light_map.append([])
		is_lit_map.append([])
		for y in range(map_height):
			light_map[x].append(0)
			is_lit_map[x].append(false)

func update_lighting(player_position: Vector2):
	# 重置光照图
	for x in range(map_width):
		for y in range(map_height):
			light_map[x][y] = 0
			is_lit_map[x][y] = false
	
	# 更新玩家光源
	apply_light(player_position, PLAYER_LIGHT_RADIUS)
	
	# 更新火把光源
	for x in range(map_width):
		for y in range(map_height):
			if terrain_data[x][y] == TerrainType.TORCH:
				apply_light(Vector2(x, y), TORCH_LIGHT_RADIUS)

func apply_light(source_pos: Vector2, radius: int):
	var start_x = max(0, int(source_pos.x - radius))
	var end_x = min(map_width - 1, int(source_pos.x + radius))
	var start_y = max(0, int(source_pos.y - radius))
	var end_y = min(map_height - 1, int(source_pos.y + radius))
	
	for x in range(start_x, end_x + 1):
		for y in range(start_y, end_y + 1):
			var distance = source_pos.distance_to(Vector2(x, y))
			if distance <= radius:
				var intensity = 1.0 - (distance / radius)
				light_map[x][y] = max(light_map[x][y], intensity)
				is_lit_map[x][y] = true

func get_source_id_for_terrain(terrain_type):
	match terrain_type:
		TerrainType.DIRT:
			return 1 # source 1 for dirt textures，使用自定义的瓦片
		TerrainType.STONE:
			return 1 # source 1 for stone textures，使用自定义的瓦片
		TerrainType.CHEST:
			return 1 # source 1 for chest
		TerrainType.TORCH:
			return 1 # source 1 for torch
		TerrainType.TELEPORT_BACK:
			return 1 # source 1 for teleport back
		_:
			return 1 # 默认使用source 1

# 获取洞穴入口位置（世界坐标）
func get_cave_entrance_position() -> Vector2:
	# 入口位置在地图中央的入口空间内
	var entrance_x = map_width / 2.0 # 使用浮点除法避免整数除法警告
	var entrance_y = cave_entrance_y # 入口空间的中央位置
	# 转换为世界坐标，放在入口空间的中央
	return Vector2(entrance_x * tile_size, entrance_y * tile_size)

func get_tile_vector_for_terrain(terrain_type):
	var tile_vector
	match terrain_type:
		TerrainType.DIRT:
			tile_vector = Vector2i(4, 0) # 使用类变量中定义的泥土瓦片位置
		TerrainType.STONE:
			tile_vector = Vector2i(17, 0) # 使用类变量中定义的石头瓦片位置
		TerrainType.CHEST:
			tile_vector = Vector2i(20, 0) # 宝箱瓦片位置
		TerrainType.TORCH:
			tile_vector = Vector2i(17, 0) # 火把瓦片位置
		TerrainType.TELEPORT_BACK:
			tile_vector = Vector2i(0, 0) # 传送点瓦片位置
		_:
			tile_vector = Vector2i(4, 0) # 默认为泥土
	
	return tile_vector

# 挖掘相关方法
func dig_tile(world_pos: Vector2) -> bool:
	# 将世界坐标转换为瓦片坐标
	var tile_pos = local_to_map(world_pos)
	var x = tile_pos.x
	var y = tile_pos.y
	
	# 检查坐标是否有效
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return false
	
	# 检查是否为不可挖掘的边界墙壁
	if current_durability[x][y] == -1:
		return false # 边界墙壁不可挖掘
	
	# 检查该位置是否可以挖掘
	var terrain_type = terrain_data[x][y]
	if terrain_type == TerrainType.AIR:
		return false # 空气不能挖掘
	
	# 根据地形类型调用相应的挖掘函数
	match terrain_type:
		TerrainType.DIRT:
			return dig_dirt_tile(Vector2i(x, y))
		TerrainType.CHEST:
			return dig_chest_tile(Vector2i(x, y))
		TerrainType.STONE:
			return dig_stone_tile(Vector2i(x, y))
		TerrainType.TORCH:
			print("无法挖掘火把！")
			return false
		_:
			return false

func dig_dirt_tile(tile_pos):
	# 挖掘泥土（需要1次）
	terrain_data[tile_pos.x][tile_pos.y] = TerrainType.AIR
	update_tile_display(tile_pos)
	print("泥土被挖掉了！")
	
	# 挖掘后显示周围的方块
	reveal_surrounding_tiles(tile_pos)
	
	return true

func dig_stone_tile(tile_pos):
	# 挖掘石头（需要3次）
	var current_hp = current_durability[tile_pos.x][tile_pos.y]
	current_hp -= 1
	current_durability[tile_pos.x][tile_pos.y] = current_hp
	
	print("挖掘石头，剩余耐久度: " + str(current_hp))
	
	if current_hp <= 0:
		# 石头被完全挖掉
		terrain_data[tile_pos.x][tile_pos.y] = TerrainType.AIR
		update_tile_display(tile_pos)
		print("石头被挖掉了！")
		
		# 挖掘完成后显示周围的方块
		reveal_surrounding_tiles(tile_pos)
		return true
	else:
		# 显示挖掘进度
		show_dig_progress(tile_pos, current_hp)
		return true

func dig_chest_tile(tile_pos):
	# 挖掘宝箱（1次即可）
	terrain_data[tile_pos.x][tile_pos.y] = TerrainType.AIR
	update_tile_display(tile_pos)
	
	# 挖掘后显示周围的方块
	reveal_surrounding_tiles(tile_pos)
	
	print("挖开宝箱！")
	return true

func show_dig_progress(_tile_pos, _remaining_hp):
	# 可以在这里添加视觉效果显示挖掘进度
	pass

func update_tile_display(tile_pos):
	# 更新单个瓦片的显示
	var terrain_type = terrain_data[tile_pos.x][tile_pos.y]
	if terrain_type == TerrainType.AIR:
		erase_cell(Vector2i(tile_pos.x, tile_pos.y))
	else:
		var source_id = get_source_id_for_terrain(terrain_type)
		var tile_vector = get_tile_vector_for_terrain(terrain_type)
		set_cell(Vector2i(tile_pos.x, tile_pos.y), source_id, tile_vector)

func reveal_surrounding_tiles(tile_pos):
	# 在玩家挖掘后，显示周围的方块（递归显示2格范围内的所有方块）
	var reveal_radius = 2
	
	for dx in range(-reveal_radius, reveal_radius + 1):
		for dy in range(-reveal_radius, reveal_radius + 1):
			var x = tile_pos.x + dx
			var y = tile_pos.y + dy
			
			# 确保坐标有效
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				var terrain_type = terrain_data[x][y]
				if terrain_type != TerrainType.AIR:
					# 显示周围的方块
					var source_id = get_source_id_for_terrain(terrain_type)
					var tile_vector = get_tile_vector_for_terrain(terrain_type)
					set_cell(Vector2i(x, y), source_id, tile_vector)
	
	# 额外检查并显示附近的火把
	for torch_pos in torch_positions:
		var distance = abs(torch_pos.x - tile_pos.x) + abs(torch_pos.y - tile_pos.y)
		if distance <= reveal_radius + 1: # 火把显示范围稍大一些
			var source_id = get_source_id_for_terrain(TerrainType.TORCH)
			var tile_vector = get_tile_vector_for_terrain(TerrainType.TORCH)
			set_cell(Vector2i(torch_pos.x, torch_pos.y), source_id, tile_vector)

# 获取地形数据的方法，供其他系统使用
func get_terrain_type(x: int, y: int) -> TerrainType:
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		if terrain_data.has(x) and terrain_data[x].has(y):
			return terrain_data[x][y]
	return TerrainType.AIR

func get_terrain_data():
	return terrain_data

func get_torch_positions():
	return torch_positions

func get_map_size():
	return Vector2i(map_width, map_height)

func get_tile_size():
	return tile_size

func get_entrance_chamber_bounds() -> Dictionary:
	# 返回入口空间的边界信息，供其他系统使用
	var entrance_center_x = map_width / 2.0
	var chamber_width = 2
	var chamber_height = 4
	var start_x = int(entrance_center_x) - int(chamber_width / 2.0)
	var start_y = cave_entrance_y - 1
	
	return {
		"start_x": start_x,
		"start_y": start_y,
		"width": chamber_width,
		"height": chamber_height,
		"center_world_pos": Vector2((start_x + chamber_width / 2.0) * tile_size, (start_y + chamber_height / 2.0) * tile_size)
	}
