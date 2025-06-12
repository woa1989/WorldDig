class_name PlayerMovement
extends Node

# 移动系统管理
signal movement_state_changed(state: String)

# 移动参数
var speed = 346.0
var jump_velocity = -560.0
var gravity = 1200.0

# 跳跃相关
var max_jumps = 1
var current_jumps = 0
var coyote_time = 0.05
var coyote_timer = 0.0

# 墙跳相关
var wall_jump_velocity = Vector2(200.0, -500.0)
var wall_slide_speed = 100.0
var wall_jump_time = 0.2
var wall_jump_timer = 0.0

# 状态变量
var facing_direction = 1
var is_wall_sliding = false
var is_wall_jumping = false
var wall_direction = 0
var can_down_attack = false
var previous_on_floor = false

# 下砸攻击相关
var is_down_attacking = false
var down_attack_velocity = 600.0
var bounce_velocity = -648.0
var bounce_gravity_reduction_time = 0.15
var bounce_gravity_factor = 0.3
var is_bouncing = false
var bounce_timer = 0.0

@onready var player: CharacterBody2D = get_parent()
var animated_sprite: AnimatedSprite2D

func _ready():
	bounce_gravity_factor = 0.3
	# 确保在player完全初始化后获取animated_sprite引用
	animated_sprite = player.get_node("AnimatedSprite2D")
	print("[DEBUG] PlayerMovement获取动画精灵引用: ", animated_sprite)

func _physics_process(delta):
	# 即使玩家死亡，也更新计时器和应用重力，以确保死亡动画可以正确下落
	update_timers(delta)
	
	# 检查玩家是否已死亡
	if "is_dead" in player and player.is_dead:
		# 死亡时只应用重力和移动，不处理任何输入
		handle_gravity(delta)
		# 让玩家慢慢停下来
		player.velocity.x = move_toward(player.velocity.x, 0, speed * 0.5)
		player.move_and_slide()
		return
	
	# 正常的物理处理流程
	detect_wall()
	handle_gravity(delta)
	handle_jumping()
	handle_movement()
	
	player.move_and_slide()
	
	# 在调用更新动画前记录当前速度（减少日志输出）
	if abs(player.velocity.x) > 10.0 or player.is_on_floor() != previous_on_floor:
		print("[ANIM DEBUG] 移动速度 X: ", round(player.velocity.x), " 在地面: ", player.is_on_floor())
		previous_on_floor = player.is_on_floor()
	
	update_animations()
	update_ground_state()

func update_timers(delta):
	"""更新各种计时器"""
	if coyote_timer > 0:
		coyote_timer -= delta
	
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	
	if is_bouncing and bounce_timer > 0:
		bounce_timer -= delta
		if bounce_timer <= 0:
			is_bouncing = false

func handle_gravity(delta):
	"""处理重力"""
	if not player.is_on_floor():
		var gravity_multiplier = bounce_gravity_factor if is_bouncing else 1.0
		player.velocity.y += gravity * gravity_multiplier * delta

func handle_jumping():
	"""处理跳跃逻辑"""
	# 死亡后不能跳跃
	if "is_dead" in player and player.is_dead:
		return
		
	if Input.is_action_just_pressed("jump"):
		if player.is_on_floor() or (coyote_timer > 0 and current_jumps == 0):
			# 普通跳跃或土狼时间跳跃
			perform_jump()
		elif is_wall_sliding and wall_direction != 0:
			# 墙跳
			perform_wall_jump()
		elif current_jumps < max_jumps:
			# 二段跳
			perform_jump()

func perform_jump():
	"""执行跳跃"""
	player.velocity.y = jump_velocity
	current_jumps += 1
	coyote_timer = 0.0
	can_down_attack = true # 主动跳跃后可以下砸攻击
	movement_state_changed.emit("jump")

func perform_wall_jump():
	"""执行墙跳"""
	is_wall_jumping = true
	wall_jump_timer = wall_jump_time
	
	# 设置墙跳速度
	player.velocity.x = wall_jump_velocity.x * -wall_direction
	player.velocity.y = wall_jump_velocity.y
	
	# 更新面向方向
	facing_direction = - wall_direction
	if animated_sprite:
		animated_sprite.flip_h = (facing_direction < 0)
	
	# 结束贴墙状态
	is_wall_sliding = false
	wall_direction = 0
	can_down_attack = true
	movement_state_changed.emit("wall_jump")

func handle_movement():
	"""处理水平移动"""
	var direction = Input.get_axis("left", "right")
	
	# 检查是否正在被击退
	var player_collision = player.get_node_or_null("PlayerCollision")
	if player_collision and player_collision.has_method("is_knockback_active") and player_collision.is_knockback_active():
		# 正在被击退时，减少玩家的控制力
		if direction != 0:
			# 击退期间玩家输入只有很小的影响
			player.velocity.x = move_toward(player.velocity.x, player.velocity.x + direction * speed * 0.1, speed * 0.05)
		return
	
	# 墙跳期间限制控制
	if is_wall_jumping and wall_jump_timer > 0:
		if direction != 0:
			player.velocity.x = move_toward(player.velocity.x, direction * speed, speed * 0.05)
		return
	
	# 正常移动
	if direction != 0:
		player.velocity.x = move_toward(player.velocity.x, direction * speed, speed * 0.2)
		
		# 更新面向方向（非贴墙状态）
		if not is_wall_sliding:
			facing_direction = sign(direction)
		
		# 翻转精灵
		if animated_sprite:
			animated_sprite.flip_h = (facing_direction < 0)
	else:
		# 减速
		if is_wall_sliding:
			player.velocity.x = move_toward(player.velocity.x, wall_direction * 50, speed * 0.1)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, speed * 0.3)

func detect_wall():
	"""检测墙壁"""
	wall_direction = 0
	is_wall_sliding = false
	
	if player.is_on_floor():
		return
	
	if player.is_on_wall_only() and player.velocity.y > 0:
		var direction = Input.get_axis("left", "right")
		
		if direction < 0 and check_wall_collision(-1):
			is_wall_sliding = true
			wall_direction = -1
		elif direction > 0 and check_wall_collision(1):
			is_wall_sliding = true
			wall_direction = 1
		
		# 贴墙时限制下落速度
		if is_wall_sliding:
			player.velocity.y = min(player.velocity.y, wall_slide_speed)

func check_wall_collision(direction: int) -> bool:
	"""检查墙壁碰撞"""
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		player.global_position + Vector2(direction * 20, 0)
	)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	return result != null

func update_animations():
	"""更新动画"""
	# 检查玩家是否已死亡，死亡后不更新动画
	if "is_dead" in player and player.is_dead:
		return
	
	# 检查animated_sprite是否存在
	if not animated_sprite:
		print("[ERROR] AnimatedSprite2D引用丢失")
		return
	
	# 检查是否在击退状态
	var player_collision = player.get_node_or_null("PlayerCollision")
	if player_collision and player_collision.has_method("is_knockback_active") and player_collision.is_knockback_active():
		# 击退状态下使用跳跃动画
		if animated_sprite.animation != "jump":
			print("[DEBUG] 击退状态中，强制使用跳跃动画")
			player.play_anim("jump")
		return
		
	# 检查是否有其他系统正在播放动画（如挖掘动画）
	var protected_anims = ["Hurt", "Dying"]
	if animated_sprite.animation in protected_anims:
		# 受伤和死亡动画绝对不能被打断
		print("[ANIM DEBUG] 高优先级动画播放中: ", animated_sprite.animation)
		return
	
	# 检查Dig动画是否仍在使用中
	if animated_sprite.animation == "Dig":
		var player_combat = player.get_node_or_null("PlayerCombat")
		var player_dig = player.get_node_or_null("PlayerDig")
		
		var is_attacking = player_combat and player_combat.is_attacking
		var is_digging = player_dig and (player_dig.is_digging or player_dig.is_dig_animation_playing)
		
		if is_attacking or is_digging:
			print("[ANIM DEBUG] Dig动画保护中 - 攻击:", is_attacking, " 挖掘:", is_digging)
			return
		else:
			print("[ANIM DEBUG] Dig动画结束，允许切换动画")
	
	var current_anim = animated_sprite.animation
	var new_anim = ""
	
	if player.is_on_floor() and not is_wall_sliding:
		if abs(player.velocity.x) > 30.0:
			new_anim = "Walk"
		else:
			new_anim = "Idle"
	elif is_wall_sliding:
		# 贴墙时使用闲置动画（没有专门的贴墙动画）
		new_anim = "Idle"
	elif not player.is_on_floor():
		# 空中时使用跳跃动画
		new_anim = "jump"
	
	# 只在动画需要改变时才播放
	if new_anim != "" and current_anim != new_anim:
		print("[DEBUG] 请求切换动画: ", current_anim, " -> ", new_anim, " (速度:", round(player.velocity.x), " 地面:", player.is_on_floor(), ")")
		player.play_anim(new_anim)

func update_ground_state():
	"""更新地面状态"""
	if player.is_on_floor():
		current_jumps = 0
		# 铲子骑士式无限下砸攻击：只有在非反弹状态着地时才禁用下砸攻击
		if not is_bouncing:
			can_down_attack = false
		coyote_timer = coyote_time
	elif was_on_floor() and coyote_timer <= 0:
		current_jumps = 1

func was_on_floor() -> bool:
	"""检查上一帧是否在地面"""
	return coyote_timer > 0

# 下砸攻击相关方法
func start_down_attack():
	"""开始下砸攻击"""
	if is_down_attacking:
		return
	
	is_down_attacking = true
	player.velocity.y = down_attack_velocity
	player.velocity.x = 0
	movement_state_changed.emit("down_attack")

func end_down_attack():
	"""结束下砸攻击"""
	is_down_attacking = false
	movement_state_changed.emit("end_down_attack")

func trigger_bounce():
	"""触发反弹 - 铲子骑士式"""
	print("[DEBUG] 触发反弹 - 向上弹起")
	player.velocity.y = bounce_velocity
	is_bouncing = true
	bounce_timer = bounce_gravity_reduction_time
	is_down_attacking = false
	can_down_attack = true # 铲子骑士式无限下砸攻击：反弹后可以再次下砸
	movement_state_changed.emit("bounce")
