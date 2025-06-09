extends CharacterBody2D

# 玩家控制脚本
# 处理移动、跳跃、挖掘等操作

@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var down_attack_area = $DownAttackArea
@onready var down_attack_debug_visual = $DownAttackArea/DebugVisual

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
var is_dig_animation_playing = false # 新增：防止动画播放期间的重复挖掘输入

# 状态
var is_digging = false
var facing_direction = 1 # 1为右，-1为左
var is_wall_sliding = false
var is_wall_jumping = false
var wall_direction = 0 # 墙壁方向：1为右墙，-1为左墙，0为无墙
var can_down_attack = false # 是否可以使用下砸攻击（只有主动跳跃后才能使用）

var is_defending = false # 是否正在防御
var is_parrying = false # 是否正在弹反
var parry_window_duration = 1000 # 弹反窗口持续时间(毫秒) - 按下防御键后1秒内
var parry_timer = 0 # 弹反计时器

# 下砸攻击相关属性
var is_down_attacking = false # 是否正在下砸攻击
var down_attack_velocity = 600.0 # 下砸攻击速度（减少50%）
var bounce_velocity = -648.0 # 反弹速度（比普通跳跃快20%）
var bounce_gravity_reduction_time = 0.15 # 反弹后重力减免时间
var bounce_gravity_factor = 0.3 # 反弹期间重力系数
var is_bouncing = false # 是否正在反弹状态
var bounce_timer = 0.0 # 反弹计时器

# 下砸攻击反弹配置（可在编辑器中调整）
@export var bounce_strength = 648.0 # 反弹强度（比普通跳跃快20%：540 * 1.2 = 648）
@export var bounce_gravity_reduction = 0.15 # 反弹后重力减免时间（秒）
@export var bounce_gravity_multiplier = 0.3 # 反弹期间重力系数

# 攻击和防御相关
var attack_damage = 1 # 攻击伤害
var is_attacking = false # 是否正在攻击
var is_invulnerable = false # 无敌状态
var invulnerability_timer = 0 # 无敌时间计时器
var invulnerability_duration = 600 # 受伤后无敌时间(毫秒)

func _ready():
	# 设置初始动画
	if animated_sprite:
		animated_sprite.play("Idle")
		print("[DEBUG] Player _ready: 动画精灵已设置为Idle")
		
		# 检查动画资源
		if animated_sprite.sprite_frames:
			print("[DEBUG] SpriteFrames 资源已加载")
			if animated_sprite.sprite_frames.has_animation("Dig"):
				var dig_frame_count = animated_sprite.sprite_frames.get_frame_count("Dig")
				print("[DEBUG] Dig 动画包含 ", dig_frame_count, " 帧")
			else:
				print("[DEBUG] 警告: 没有找到 'Dig' 动画")
		else:
			print("[DEBUG] 错误: SpriteFrames 资源未加载")
	else:
		print("[DEBUG] 错误: AnimatedSprite2D 节点未找到")
	
	# 应用可配置的反弹参数
	bounce_velocity = - bounce_strength
	bounce_gravity_reduction_time = bounce_gravity_reduction
	bounce_gravity_factor = bounce_gravity_multiplier
	
	# 连接下砸攻击区域信号
	if down_attack_area:
		down_attack_area.body_entered.connect(_on_down_attack_area_body_entered)
		down_attack_area.area_entered.connect(_on_down_attack_area_area_entered)
	
	# 确保玩家可见
	visible = true
	modulate = Color.WHITE
	

func _physics_process(delta):
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	# 处理反弹计时器
	if is_bouncing and bounce_timer > 0:
		bounce_timer -= delta
		if bounce_timer <= 0:
			is_bouncing = false
	
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
		can_down_attack = false # 落地后重置下砸攻击能力
	elif was_on_floor() and coyote_timer <= 0:
		# 刚离开地面，开始土狼时间
		coyote_timer = coyote_time
	
	# 重力处理（增强版本，支持反弹重力减免）
	if not is_on_floor():
		var gravity_factor = 1.0
		if is_bouncing:
			gravity_factor = bounce_gravity_factor
		
		if is_wall_sliding:
			# 贴墙滑行时的重力减缓，限制下降速度
			velocity.y += gravity * delta * 0.3 * gravity_factor
			if velocity.y > wall_slide_speed:
				velocity.y = wall_slide_speed
		else:
			velocity.y += gravity * delta * gravity_factor
	
	# 跳跃处理
	handle_jumping()
	
	# 移动处理 - 在弹反和下砸攻击时不允许移动
	if not is_parrying and not is_down_attacking:
		handle_movement()
	
	# 处理下砸攻击（只有主动跳跃后在空中状态下按下+攻击才可以触发）
	if Input.is_action_just_pressed("dig") and Input.is_action_pressed("down") and not is_on_floor() and not is_down_attacking and not is_attacking and can_down_attack:
		start_down_attack()
	# 检查是否停止下砸攻击（松开下键或攻击键）
	elif is_down_attacking and (not Input.is_action_pressed("down") or not Input.is_action_pressed("dig")):
		end_down_attack()
	
	# 处理防御
	if Input.is_action_just_pressed("defend") and not is_attacking:
		defend()
	
	# 处理防御释放
	if Input.is_action_just_released("defend"):
		release_defend()
	
	# 更新弹反计时器
	if is_defending:
		parry_timer += delta * 1000 # 转换为毫秒
		# 检查弹反窗口是否结束
		if parry_timer >= parry_window_duration:
			is_defending = false
			parry_timer = 0
	
	# 更新无敌时间
	if is_invulnerable:
		invulnerability_timer += delta * 1000
		if invulnerability_timer >= invulnerability_duration:
			is_invulnerable = false
			invulnerability_timer = 0
			# 恢复正常显示
			set_shader_blink_intensity(0.0)
		else:
			# 闪烁效果
			if int(invulnerability_timer / 100) % 2 == 0:
				set_shader_blink_intensity(0.8)
			else:
				set_shader_blink_intensity(0.0)
	
	move_and_slide()
	
	# 动画处理 - 在move_and_slide()之后检查实际移动速度
	update_animations()

func handle_jumping():
	"""处理跳跃逻辑"""
	if Input.is_action_just_pressed("jump"):
		# 墙跳优先级最高
		if is_wall_sliding and wall_direction != 0:
			# 墙跳：向墙的反方向跳跃
			velocity.x = - wall_direction * wall_jump_velocity.x
			velocity.y = wall_jump_velocity.y
			is_wall_jumping = true
			is_wall_sliding = false
			wall_jump_timer = wall_jump_time
			current_jumps = 1
			can_down_attack = true # 墙跳后可以使用下砸攻击
			play_anim("jump")
		# 普通跳跃
		elif is_on_floor() or coyote_timer > 0:
			# 第一段跳跃
			velocity.y = jump_velocity
			current_jumps = 1
			coyote_timer = 0
			can_down_attack = true # 主动跳跃后可以使用下砸攻击
			play_anim("jump")
		elif current_jumps < max_jumps:
			# 二段跳
			velocity.y = jump_velocity * 0.8
			current_jumps += 1
			can_down_attack = true # 二段跳后可以使用下砸攻击
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
	else:
		# 没有输入时减速
		if is_wall_sliding:
			# 贴墙时保持少量水平速度
			velocity.x = move_toward(velocity.x, wall_direction * 50, speed * 0.1)
		else:
			velocity.x = move_toward(velocity.x, 0, speed * 0.1)

func update_animations():
	"""更新玩家动画 - 基于实际移动速度"""
	# 动画处理 - 基于实际移动速度而不是输入
	if is_on_floor() and not is_digging and not is_wall_sliding:
		# 检查玩家是否真的在移动（速度阈值）
		if abs(velocity.x) > 50.0: # 如果水平速度大于阈值，播放走路动画
			if animated_sprite and animated_sprite.animation != "Walk":
				animated_sprite.play("Walk")
		else: # 如果基本静止，播放空闲动画
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

func handle_digging(_delta):
	print("[DEBUG] handle_digging 被调用")
	print("[DEBUG] dig_timer: ", dig_timer, ", is_digging: ", is_digging, ", is_dig_animation_playing: ", is_dig_animation_playing)
	
	# 多重检查：冷却时间、挖掘状态和动画播放状态
	if dig_timer > 0 or is_digging or is_dig_animation_playing:
		print("[DEBUG] 挖掘被阻止 - dig_timer: ", dig_timer, ", is_digging: ", is_digging, ", is_dig_animation_playing: ", is_dig_animation_playing)
		return
		
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
	
	# 先播放挖掘动画，动画结束后再销毁瓦片
	if animated_sprite and not is_digging and not is_dig_animation_playing:
		print("[DEBUG] 开始播放挖掘动画")
		is_digging = true
		is_dig_animation_playing = true
		play_anim("Dig")
		if dig_direction.x != 0:
			animated_sprite.flip_h = dig_direction.x < 0
		
		print("[DEBUG] 开始挖掘动画 - 方向: ", dig_direction)
		print("[DEBUG] 当前动画: ", animated_sprite.animation if animated_sprite else "null")
		print("[DEBUG] 动画长度: ", animated_sprite.sprite_frames.get_frame_count("Dig") if animated_sprite and animated_sprite.sprite_frames else "unknown")
		
		# 保存挖掘信息，在动画结束后执行实际挖掘
		var dig_info = {
			"direction": dig_direction,
			"position": global_position
		}
		
		# 设置挖掘冷却时间
		dig_timer = dig_cooldown
		
		# 断开之前可能存在的连接（防止内存泄漏）
		if animated_sprite.animation_finished.is_connected(_on_dig_animation_complete):
			print("[DEBUG] 断开之前的动画信号连接")
			animated_sprite.animation_finished.disconnect(_on_dig_animation_complete)
		
		# 使用动画完成信号而不是固定计时器
		print("[DEBUG] 连接动画完成信号")
		print("[DEBUG] 动画是否正在播放: ", animated_sprite.is_playing())
		animated_sprite.animation_finished.connect(_on_dig_animation_complete.bind(dig_info), CONNECT_ONE_SHOT)
		print("[DEBUG] 信号连接完成")
		
		# 添加后备计时器，以防动画信号失败
		var backup_timer = get_tree().create_timer(1.0) # 1秒后备时间
		backup_timer.timeout.connect(_on_dig_backup_timeout.bind(dig_info), CONNECT_ONE_SHOT)
		print("[DEBUG] 后备计时器已设置")
	else:
		print("[DEBUG] 无法播放挖掘动画 - animated_sprite: ", animated_sprite != null, ", is_digging: ", is_digging, ", is_dig_animation_playing: ", is_dig_animation_playing)


# 后备超时处理函数，以防动画信号失败
func _on_dig_backup_timeout(dig_info: Dictionary):
	"""当动画信号失败时的后备处理函数"""
	if is_digging or is_dig_animation_playing:
		print("[DEBUG] 后备计时器触发，强制完成挖掘动画")
		_on_dig_animation_complete(dig_info)
	else:
		print("[DEBUG] 后备计时器触发，但动画已正常完成")


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

# 新的动画完成信号处理函数
func _on_dig_animation_complete(dig_info: Dictionary):
	"""当挖掘动画完成时调用，执行实际的挖掘操作"""
	print("[DEBUG] 挖掘动画完成，执行实际挖掘操作")
	print("[DEBUG] 挖掘方向: ", dig_info.direction)
	print("[DEBUG] 挖掘位置: ", dig_info.position)
	
	# 只有在仍然处于挖掘状态时才执行挖掘操作
	if is_digging or is_dig_animation_playing:
		# 执行实际的挖掘操作
		perform_directional_dig(dig_info.direction)
		
		# 重置所有挖掘相关状态
		is_digging = false
		is_dig_animation_playing = false
		
		print("[DEBUG] 状态重置完成 - is_digging: ", is_digging, ", is_dig_animation_playing: ", is_dig_animation_playing)
		
		# 恢复动画
		if is_on_floor():
			if abs(velocity.x) > 50.0:
				play_anim("Walk")
			else:
				play_anim("Idle")
		
		print("[DEBUG] 挖掘完成，状态已重置")
	else:
		print("[DEBUG] 动画完成信号被调用，但状态已被重置")

# 受到伤害 - 处理弹反、防御和伤害逻辑
func take_damage(damage, attacker = null) -> bool:
	print("[DEBUG] 玩家受到攻击 - 伤害: ", damage, ", 攻击者: ", attacker)
	print("[DEBUG] 当前状态 - 弹反: ", is_parrying, ", 防御: ", is_defending, ", 无敌: ", is_invulnerable)
	print("[DEBUG] 弹反计时器: ", parry_timer, "ms")
	
	# 如果正在弹反，反弹伤害
	if is_parrying:
		print("[DEBUG] ⚡ 弹反状态中！反弹攻击")
		reflect_attack(damage, attacker)
		return true # 返回 true 表示成功格挡
	
	# 如果正在防御且在弹反窗口内，触发弹反
	if is_defending and parry_timer <= parry_window_duration:
		print("[DEBUG] ⚡ 完美弹反！触发反弹")
		parry() # 激活弹反状态
		reflect_attack(damage, attacker)
		return true # 返回 true 表示成功格挡
	
	# 如果处于无敌状态，不受伤害
	if is_invulnerable:
		print("[DEBUG] 💫 无敌状态，免疫伤害")
		return false # 返回 false 表示未受伤害但也未格挡
	
	# 应用伤害
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.damage_player(damage)

	
	# 设置短暂无敌时间
	is_invulnerable = true
	invulnerability_timer = 0
	
	# 播放受伤动画
	if animated_sprite:
		play_anim("Hurt")
		animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)
	
	return false # 返回 false 表示受到了伤害

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
		place_torch()

# 新增 - 放置火把
func place_torch():
	# 检查玩家是否有火把道具
	var game_manager = get_node("/root/GameManager")
	if not game_manager:
		return
	
	if game_manager.has_item("torch"):
		# 获取放置位置（就在玩家当前位置）
		var place_position = global_position
		# 获取矿场引用并尝试放置火把
		if try_place_torch_nearby(place_position):
			game_manager.remove_item("torch", 1)

# 新增：动画切换统一方法
func play_anim(anim_name: String):
	if animated_sprite and animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)

# 新增：统一输入处理
func handle_input(delta):
	# 挖掘输入检查 - 只在按键刚按下时检查一次
	if Input.is_action_just_pressed("dig"):
		print("[DEBUG] J键被按下，调用 handle_digging")
		handle_digging(delta)
	else:
		# 更新挖掘计时器
		if dig_timer > 0:
			dig_timer -= delta
	
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

# ========================= 防御系统 =========================

# 防御函数 - 开始防御状态，激活1秒弹反窗口
func defend():
	is_defending = true
	parry_timer = 0 # 重置弹反计时器
	print("[DEBUG] 玩家开始防御 - 激活1秒弹反窗口")
	
	# 可以添加防御动画或效果
	# ...

# 释放防御 - 手动结束防御状态
func release_defend():
	print("[DEBUG] 玩家手动释放防御 - 弹反计时器: ", parry_timer, "ms")
	is_defending = false
	parry_timer = 0

# 弹反函数 - 激活短暂的弹反状态
func parry():
	is_defending = false
	is_parrying = true
	parry_timer = 0
	print("[DEBUG] 🛡️ 弹反状态激活，持续0.3秒")
	
	# 播放弹反效果
	# 可以添加弹反动画或特效
	# ...
	
	# 弹反结束后恢复状态
	await get_tree().create_timer(0.3).timeout
	is_parrying = false
	print("[DEBUG] 弹反状态结束")

# 反弹攻击函数 - 处理远程和近战攻击的反弹
func reflect_attack(damage, attacker = null):
	print("[DEBUG] 🔄 开始处理攻击反弹")
	
	# 检查攻击者类型
	if attacker == null:
		print("[DEBUG] 无攻击者信息，无法反弹")
		return
	
	# 判断是否为子弹（远程攻击）
	if attacker.get_script() and attacker.get_script().get_path().ends_with("bullet.gd"):
		# 远程攻击：反弹子弹
		print("[DEBUG] 🏹 检测到远程攻击（子弹），执行子弹反弹")
		reflect_bullet(attacker)
	else:
		# 近战攻击：直接对攻击者造成伤害
		print("[DEBUG] ⚔️ 检测到近战攻击，直接反弹伤害")
		if attacker.has_method("take_damage"):
			attacker.take_damage(damage) # 反弹伤害
		else:
			print("[DEBUG] 攻击者无法接受反弹伤害")

# 反弹子弹函数 - 将子弹原路返回并重置射程
func reflect_bullet(bullet):
	print("[DEBUG] 🔄 开始反弹子弹")
	
	# 检查子弹是否有速度信息
	if bullet.has_meta("velocity"):
		# 反转子弹速度方向
		var original_velocity = bullet.get_meta("velocity")
		var reflected_velocity = - original_velocity
		bullet.set_meta("velocity", reflected_velocity)
		print("[DEBUG] 子弹速度已反转: ", original_velocity, " -> ", reflected_velocity)
		
		# 修改子弹的伤害目标（让子弹能伤害敌人而不是玩家）
		bullet.set_meta("reflected", true)
		print("[DEBUG] 子弹已标记为反弹状态")
		
		# 重置子弹的生命周期计时器，恢复完整射程
		reset_bullet_lifetime(bullet)
	else:
		print("[DEBUG] 子弹没有速度信息，无法反弹")

# 重置子弹生命周期计时器
func reset_bullet_lifetime(bullet):
	# 查找子弹的计时器并重置
	for child in bullet.get_children():
		if child is Timer:
			# 重新计算子弹生命周期（使用与gun.gd相同的参数）
			const BULLET_VELOCITY = 850.0
			const BULLET_RANGE = 500.0
			var bullet_lifetime = BULLET_RANGE / BULLET_VELOCITY
			
			# 重置计时器
			child.stop()
			child.wait_time = bullet_lifetime
			child.start()
			print("[DEBUG] 子弹生命周期已重置，新射程: ", BULLET_RANGE)
			break

# ========================= 下砸攻击系统 =========================

# 开始下砸攻击
func start_down_attack():
	"""开始下砸攻击 - 玩家快速向下移动并攻击 - 增强调试版本"""
	print("[DEBUG] 🔨 ===== 开始下砸攻击 =====")
	print("[DEBUG] 🔨 当前位置: ", global_position)
	print("[DEBUG] 🔨 当前速度: ", velocity)
	print("[DEBUG] 🔨 是否在地面: ", is_on_floor())
	
	# 防止重复激活
	if is_down_attacking:
		print("[DEBUG] 🚫 下砸攻击已在进行中，忽略重复请求")
		return
		
	is_down_attacking = true
	is_attacking = true
	print("[DEBUG] 🔨 下砸攻击状态已激活")
	
	# 设置向下的高速度
	var old_velocity = velocity
	velocity.y = down_attack_velocity
	velocity.x = 0 # 停止水平移动
	print("[DEBUG] 🔨 速度变化: ", old_velocity, " -> ", velocity)
	
	# 播放下砸攻击动画
	if animated_sprite:
		animated_sprite.play("Dig") # 使用挖掘动画作为下砸攻击动画
		print("[DEBUG] 🔨 播放下砸攻击动画")
	
	# 激活预创建的下砸攻击区域
	if down_attack_area:
		down_attack_area.monitoring = true
		print("[DEBUG] 🔨 下砸攻击区域已激活，monitoring = ", down_attack_area.monitoring)
		print("[DEBUG] 🔨 攻击区域位置: ", down_attack_area.global_position)
		print("[DEBUG] 🔨 攻击区域碰撞层: ", down_attack_area.collision_layer)
		print("[DEBUG] 🔨 攻击区域碰撞掩码: ", down_attack_area.collision_mask)
	else:
		print("[DEBUG] ❌ 错误：找不到下砸攻击区域！")
	
	print("[DEBUG] 🔨 ===== 下砸攻击开始完成 =====")
	

func _on_down_attack_area_body_entered(body):
	"""下砸攻击区域检测到碰撞体 - 增强调试版本"""
	print("[DEBUG] 🔨 下砸攻击检测到碰撞体: ", body.name, ", 类型: ", body.get_class())
	print("[DEBUG] 🔨 当前下砸攻击状态: ", is_down_attacking)
	print("[DEBUG] 🔨 当前玩家速度: ", velocity)
	print("[DEBUG] 🔨 玩家位置: ", global_position)
	print("[DEBUG] 🔨 碰撞体位置: ", body.global_position if body.has_method("get_global_position") else "N/A")
	
	if not is_down_attacking:
		print("[DEBUG] 🚫 不在下砸攻击状态，忽略碰撞")
		return
	
	var should_bounce = false
	
	# 如果击中敌人
	if body.has_method("take_damage") and body != self:
		print("[DEBUG] 🔨 下砸攻击击中敌人！造成伤害: ", attack_damage)
		body.take_damage(attack_damage, self)
		should_bounce = true
	# 如果击中地面、平台或瓦片地图
	elif (body.is_in_group("ground") or body.is_in_group("platform") or
		  body.name.to_lower().contains("ground") or body.name.to_lower().contains("floor") or
		  body.name.to_lower().contains("tile") or body is TileMapLayer or body is TileMap):
		print("[DEBUG] 🔨 下砸攻击击中地面/瓦片！")
		# 矿工下砸攻击：尝试挖掘击中位置的土块
		if perform_down_attack_dig():
			print("[DEBUG] ⛏️ 挖掘成功，触发反弹")
			should_bounce = true
		else:
			print("[DEBUG] ⛏️ 挖掘失败，仍然触发反弹")
			# 如果挖掘失败，仍然触发反弹（可能击中不可挖掘的物体）
			should_bounce = true
	# 如果是任何静态物体（StaticBody2D）也可以反弹
	elif body is StaticBody2D:
		print("[DEBUG] 🔨 下砸攻击击中静态物体！")
		should_bounce = true
	else:
		print("[DEBUG] 🔨 击中未识别物体类型，尝试反弹")
		should_bounce = true
	
	if should_bounce:
		print("[DEBUG] 🚀 准备触发反弹...")
		trigger_bounce()
	else:
		print("[DEBUG] 🚫 不满足反弹条件")

func _on_down_attack_area_area_entered(area):
	"""下砸攻击区域检测到其他Area2D"""
	print("[DEBUG] 下砸攻击检测到区域: ", area.name)
	# 可以用于检测特殊的可反弹区域

func trigger_bounce():
	"""触发反弹效果 - 增强版本，包含重力减免"""
	if not is_down_attacking:
		print("[DEBUG] 🚫 trigger_bounce被调用但不在下砸攻击状态，忽略")
		return
		
	print("[DEBUG] 🚀 触发增强反弹效果！")
	print("[DEBUG] 🚀 反弹前速度: ", velocity)
	
	# 设置强力向上的反弹速度
	velocity.y = bounce_velocity
	print("[DEBUG] 🚀 设置反弹速度: ", bounce_velocity)
	
	# 激活反弹状态，减少重力影响
	is_bouncing = true
	bounce_timer = bounce_gravity_reduction_time
	print("[DEBUG] 🚀 激活反弹重力减免，持续时间: ", bounce_gravity_reduction_time, "秒")
	
	# 结束当前下砸攻击状态，但保持可以立即再次下砸
	is_down_attacking = false
	is_attacking = false
	# 保持 can_down_attack = true，允许连续下砸攻击（无限弹跳）
	# can_down_attack 保持为 true，不重置
	
	# 使用统一的禁用函数
	disable_down_attack_area("反弹触发")
	
	# 播放反弹动画或效果
	if animated_sprite:
		animated_sprite.play("Idle") # 修正：使用正确的动画名称
	
	print("[DEBUG] 🚀 反弹后速度: ", velocity)
	print("[DEBUG] 🚀 反弹完成，玩家可以立即再次下砸攻击实现无限弹跳！")

# 结束下砸攻击
func end_down_attack():
	"""结束下砸攻击状态 - 玩家松开按键时调用"""
	print("[DEBUG] 🔨 结束下砸攻击状态")
	
	# 结束下砸攻击状态
	is_down_attacking = false
	is_attacking = false
	
	# 禁用下砸攻击区域
	disable_down_attack_area("手动结束")

func disable_down_attack_area(reason: String = "未知原因"):
	"""统一的下砸攻击区域禁用函数"""
	if down_attack_area and down_attack_area.monitoring:
		down_attack_area.set_deferred("monitoring", false)
		print("[DEBUG] ", reason, "时下砸攻击区域已禁用")
		
		# 隐藏调试可视化
		if down_attack_debug_visual and down_attack_debug_visual.visible:
			down_attack_debug_visual.set_deferred("visible", false)
			print("[DEBUG] ", reason, "时下砸攻击调试可视化已隐藏")
	
	print("[DEBUG] ", reason, "时下砸攻击区域已通过预创建方式禁用")

# ========================= 辅助函数 =========================


func set_shader_blink_intensity(intensity: float):
	"""设置玩家的Shader的闪烁强度"""
	if animated_sprite and animated_sprite.material:
		animated_sprite.material.set_shader_parameter("blink_intensity", intensity)


# 延迟执行挖掘操作的函数
func _execute_delayed_dig(dig_info: Dictionary):
	"""动画播放完成后执行实际的挖掘操作"""
	print("[DEBUG] 挖掘动画完成，执行实际挖掘操作")
	print("[DEBUG] 挖掘方向: ", dig_info.direction)
	print("[DEBUG] 挖掘位置: ", dig_info.position)
	
	# 执行实际的挖掘操作
	perform_directional_dig(dig_info.direction)
	
	# 结束挖掘状态
	_on_dig_animation_finished()

# 矿工下砸攻击挖掘函数
func perform_down_attack_dig() -> bool:
	"""矿工下砸攻击时尝试挖掘下方的土块"""
	if not is_down_attacking:
		return false
	
	print("[DEBUG] ⛏️ 矿工下砸攻击开始挖掘检测...")
	
	# 使用与普通挖掘相同的网格计算方法
	var tile_size = dig_range
	var player_grid = (global_position / tile_size).floor()
	var target_grid = player_grid + Vector2(0, 1) # 向下一格
	var dig_position = (target_grid + Vector2(0.5, 0.5)) * tile_size
	
	print("[DEBUG] ⛏️ 下砸攻击挖掘位置计算:")
	print("[DEBUG] ⛏️ - 瓦片大小: ", tile_size)
	print("[DEBUG] ⛏️ - 玩家网格位置: ", player_grid)
	print("[DEBUG] ⛏️ - 目标网格位置: ", target_grid)
	print("[DEBUG] ⛏️ - 最终挖掘位置: ", dig_position)
	
	# 尝试在下砸位置及周围挖掘
	var dig_success = try_dig_nearby(dig_position)
	
	if dig_success:
		print("[DEBUG] ⛏️ 下砸攻击挖掘成功！获得资源")
		
		return true
	else:
		print("[DEBUG] ⛏️ 下砸攻击挖掘失败，下方可能没有可挖掘的土块")
		return false
