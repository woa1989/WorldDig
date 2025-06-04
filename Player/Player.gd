extends CharacterBody2D

# 玩家控制脚本
# 处理移动、跳跃、挖掘等操作

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D

# 移动相关
var speed = 345.6 # 在288.0基础上增加20% (288.0 * 1.2)
var jump_velocity = -540.0 # 在-450.0基础上增加20% (-450.0 * 1.2)
var gravity = 1200.0

# 二段跳相关
var max_jumps = 1
var current_jumps = 0
var coyote_time = 0.05
var coyote_timer = 0.0

# 墙跳相关
var wall_jump_velocity = Vector2(200.0, -500.0) # 墙跳的水平和垂直速度
var wall_slide_speed = 100.0 # 贴墙滑行速度
var wall_jump_time = 0.2 # 墙跳后的控制延迟时间
var wall_jump_timer = 0.0 # 墙跳计时器


# 挖掘相关
var dig_range = 128.0
var dig_timer = 0.0
var dig_cooldown = 0.3

# 状态
var is_digging = false
var facing_direction = 1 # 1为右，-1为左
var is_wall_sliding = false
var is_wall_jumping = false
var wall_direction = 0 # 墙壁方向：1为右墙，-1为左墙，0为无墙

func _ready():
	# 设置初始动画
	if animated_sprite:
		animated_sprite.play("Idle")
		print("Player _ready: 动画精灵已设置为Idle")
	else:
		print("Player _ready: 找不到AnimatedSprite2D节点！")
	
	# 确保玩家可见
	visible = true
	modulate = Color.WHITE
	print("Player _ready: 玩家可见性设置完成")

func _physics_process(delta):
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# 墙壁检测
	detect_wall()
	
	# 统一输入处理
	handle_input(delta)
	
	# 重置跳跃次数和土狼时间
	if is_on_floor():
		current_jumps = 0
		coyote_timer = coyote_time
		is_wall_sliding = false
		is_wall_jumping = false
	elif was_on_floor() and coyote_timer <= 0:
		# 刚离开地面，开始土狼时间
		coyote_timer = coyote_time
	
	# 重力处理
	if not is_on_floor():
		if is_wall_sliding:
			# 贴墙滑行时的重力减缓，限制下降速度
			velocity.y += gravity * delta * 0.3
			if velocity.y > wall_slide_speed:
				velocity.y = wall_slide_speed
		else:
			velocity.y += gravity * delta
	
	# 跳跃处理
	handle_jumping()
	
	# 移动处理
	handle_movement()
	
	# 挖掘
	handle_digging(delta)
	
	# 放置火把
	handle_torch_placement()
	
	move_and_slide()

func handle_jumping():
	"""处理跳跃逻辑"""
	if Input.is_action_just_pressed("jump"):
		# 墙跳优先级最高
		if is_wall_sliding and wall_direction != 0:
			# 墙跳：向墙的反方向跳跃
			velocity.x = -wall_direction * wall_jump_velocity.x
			velocity.y = wall_jump_velocity.y
			is_wall_jumping = true
			is_wall_sliding = false
			wall_jump_timer = wall_jump_time
			current_jumps = 1
			play_anim("jump")
			print("墙跳！方向：", -wall_direction)
		# 普通跳跃
		elif is_on_floor() or coyote_timer > 0:
			# 第一段跳跃
			velocity.y = jump_velocity
			current_jumps = 1
			coyote_timer = 0
			play_anim("jump")
		elif current_jumps < max_jumps:
			# 二段跳
			velocity.y = jump_velocity * 0.8
			current_jumps += 1
			play_anim("jump")
	
func handle_movement():
	"""处理水平移动"""
	var direction = Input.get_axis("left", "right")
	
	# 墙跳期间限制玩家控制
	if is_wall_jumping and wall_jump_timer > 0:
		# 墙跳期间减少玩家的水平控制力
		if direction != 0:
			velocity.x = move_toward(velocity.x, direction * speed, speed * 0.05)
		return
	
	# 正常移动
	if direction != 0:
		# 应用移动速度
		velocity.x = move_toward(velocity.x, direction * speed, speed * 0.2)
		
		# 更新面向方向
		if not is_wall_sliding:
			facing_direction = direction
		
		# 翻转精灵
		if animated_sprite:
			animated_sprite.flip_h = (facing_direction < 0)
		
		# 播放走路动画（如果在地面且不在挖掘）
		if is_on_floor() and not is_digging:
			if animated_sprite and animated_sprite.animation != "Walk":
				animated_sprite.play("Walk")
	else:
		# 没有输入时减速
		if is_wall_sliding:
			# 贴墙时保持少量水平速度
			velocity.x = move_toward(velocity.x, wall_direction * 50, speed * 0.1)
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 0.1)
		
		# 播放空闲动画（如果在地面且不在挖掘和爬墙）
		if is_on_floor() and not is_digging and not is_wall_sliding:
			if animated_sprite and animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
	
	# 爬墙动画
	if is_wall_sliding and animated_sprite:
		if animated_sprite.animation != "Wall_Slide":
			# 如果没有专门的爬墙动画，可以使用Idle或创建一个
			animated_sprite.play("Idle")

func was_on_floor() -> bool:
	"""检查上一帧是否在地面（简化实现）"""
	return coyote_timer > 0

func detect_wall():
	"""检测墙壁并设置墙滑状态"""
	# 重置墙壁状态
	wall_direction = 0
	var was_wall_sliding = is_wall_sliding
	is_wall_sliding = false
	
	# 只有在空中时才能贴墙
	if is_on_floor():
		return
	
	# 检测左墙
	if is_on_wall_only() and velocity.y > 0:
		var direction = Input.get_axis("left", "right")
		
		# 检查玩家是否在向墙的方向移动或按住方向键
		if direction < 0 and check_wall_collision(-1):
			# 左墙
			wall_direction = -1
			is_wall_sliding = true
		elif direction > 0 and check_wall_collision(1):
			# 右墙
			wall_direction = 1
			is_wall_sliding = true
	
	# 调试输出
	if is_wall_sliding and not was_wall_sliding:
		print("开始贴墙滑行，墙壁方向：", wall_direction)
	elif not is_wall_sliding and was_wall_sliding:
		print("结束贴墙滑行")

func check_wall_collision(direction: int) -> bool:
	"""检查指定方向是否有墙壁碰撞"""
	# 使用射线检测或形状查询来检测墙壁
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(direction * 20, 0)
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result != null

func handle_digging(delta):
	# 更新挖掘计时器
	if dig_timer > 0:
		dig_timer -= delta
		
	# 检测挖掘输入
	if Input.is_action_pressed("dig") and dig_timer <= 0:
		var dig_direction = Vector2.ZERO
		
		# 检测方向键输入，只允许4个基本方向挖掘
		if Input.is_action_pressed("up"):
			dig_direction = Vector2(0, -1)
		elif Input.is_action_pressed("down"):
			dig_direction = Vector2(0, 1)
		elif Input.is_action_pressed("left"):
			dig_direction = Vector2(-1, 0)
		elif Input.is_action_pressed("right"):
			dig_direction = Vector2(1, 0)
		else:
			# 没有方向键时，根据玩家朝向挖掘
			dig_direction = Vector2(facing_direction, 0)
		
		# 执行挖掘
		perform_directional_dig(dig_direction)
		dig_timer = dig_cooldown
		
		# 播放攻击动画
		if animated_sprite and not is_digging:
			is_digging = true
			play_anim("Dig")
			if dig_direction.x != 0:
				animated_sprite.flip_h = dig_direction.x < 0
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(_on_dig_animation_finished)
		
		# 打印挖掘方向的调试信息
		var direction_name = get_direction_name(dig_direction)
		print(direction_name, "挖掘！")

func get_direction_name(direction: Vector2) -> String:
	"""获取方向名称用于调试"""
	var direction_name = ""
	if direction.y < 0:
		direction_name = "向上"
	elif direction.y > 0:
		direction_name = "向下"
	
	if direction.x < 0:
		direction_name += "向左"
	elif direction.x > 0:
		direction_name += "向右"
	
	if direction_name == "":
		direction_name = "未知方向"
	
	return direction_name

func perform_directional_dig(direction: Vector2):
	# tile_size = dig_range
	var tile_size = dig_range
	var player_grid = (global_position / tile_size).floor()
	var target_grid = player_grid + direction
	var dig_position = (target_grid + Vector2(0.5, 0.5)) * tile_size
	if not try_dig_nearby(dig_position):
		print("无法在此方向及附近挖掘")

func perform_forward_dig():
	# 向前挖掘
	var dig_position = global_position + Vector2(facing_direction * dig_range, 0)
	if not try_dig_nearby(dig_position):
		print("无法在前方及附近挖掘")

func attempt_dig(world_position):
	# 兼容旧接口，直接用新工具函数
	if not try_dig_nearby(world_position):
		print("无法在此处及附近挖掘")

func _on_dig_animation_finished():
	# 挖掘动画结束
	is_digging = false
	if is_on_floor():
		if velocity.x != 0:
			play_anim("Walk")
		else:
			play_anim("Idle")

func take_damage(amount):
	# 受伤
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.damage_player(amount)
	
	# 播放受伤动画
	if animated_sprite:
		play_anim("Hurt")
		animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func _on_hurt_animation_finished():
	# 受伤动画结束，返回正常状态
	if is_on_floor():
		if velocity.x != 0:
			play_anim("Walk")
		else:
			play_anim("Idle")

func die():
	# 死亡
	if animated_sprite:
		play_anim("Dying")
		# 禁用控制
		set_physics_process(false)

# 新增 - 处理放置火把
func handle_torch_placement():
	# 检测T键放置火把
	if Input.is_action_just_pressed("place_torch"):
		print("检测到T键按下，尝试放置火把")
		place_torch()

# 新增 - 放置火把
func place_torch():
	# 检查玩家是否有火把道具
	print("执行place_torch函数")
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		print("错误: 找不到GameManager")
		return
	print("检查火把数量...")
	var torch_count = game_manager.get_item_count("torch")
	print("火把数量:", torch_count)
	if game_manager.has_item("torch"):
		print("有火把可以放置")
		# 获取放置位置（就在玩家当前位置）
		var place_position = global_position
		print("尝试在位置放置:", place_position)
		# 获取矿场引用并尝试放置火把
		if try_place_torch_nearby(place_position):
			game_manager.remove_item("torch", 1)
			print("放置了一个火把！")
		else:
			print("无法在此处及附近放置火把")
	else:
		print("没有火把可以放置!")

# 新增：动画切换统一方法
func play_anim(anim_name: String):
	if animated_sprite and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

# 新增：统一输入处理
func handle_input(delta):
	if Input.is_action_just_pressed("jump"):
		handle_jumping()
	if Input.is_action_pressed("dig"):
		handle_digging(delta)
	if Input.is_action_just_pressed("place_torch"):
		handle_torch_placement()

# 工具函数：生成周围8格偏移
func get_surrounding_offsets() -> Array:
	return [
		Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0),
		Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1),
		Vector2(1, -1), Vector2(-1, -1)
	]

# 工具函数：尝试在当前位置及周围8格执行操作
func try_action_nearby(base_pos: Vector2, offsets: Array, func_name: String) -> bool:
	for offset in offsets:
		if call(func_name, base_pos + offset):
			return true
	return false

# 挖掘：尝试当前位置及周围8格
func try_dig_nearby(world_position: Vector2) -> bool:
	for offset in get_surrounding_offsets():
		var mine_scene = get_parent()
		if mine_scene and mine_scene.has_method("dig_at_position") and mine_scene.dig_at_position(world_position + offset):
			return true
	return false

# 火把放置：尝试当前位置及周围8格
func try_place_torch_nearby(world_position: Vector2) -> bool:
	for offset in get_surrounding_offsets():
		var mine_scene = get_parent()
		if mine_scene and mine_scene.has_method("place_torch") and mine_scene.place_torch(world_position + offset):
			return true
	return false
