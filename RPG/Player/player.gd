extends CharacterBody2D

# 玩家属性
var max_health = 3 # 最大生命值
var current_health = 3 # 当前生命值
var move_speed = 400.0 # 移动速度
var jump_velocity = -850.0 # 跳跃速度
var attack_damage = 1 # 攻击伤害
var is_attacking = false # 是否正在攻击
var is_defending = false # 是否正在防御
var is_parrying = false # 是否正在弹反
var parry_window_duration = 1000 # 弹反窗口持续时间(毫秒) - 按下防御键后1秒内
var parry_timer = 0 # 弹反计时器
var facing_direction = "front" # 面朝方向：front, back, left, right
var is_invulnerable = false # 无敌状态
var invulnerability_timer = 0 # 无敌时间计时器
var invulnerability_duration = 600 # 受伤后无敌时间(毫秒)

# 下砸攻击相关属性
var is_down_attacking = false # 是否正在下砸攻击
var down_attack_velocity = 600.0 # 下砸攻击速度（减少50%）
var bounce_velocity = -880.0 # 反弹速度
var has_jumped = false # 是否通过跳跃进入空中状态

# 防卡住机制相关属性
var stuck_timer = 0.0 # 卡住计时器
var last_position = Vector2.ZERO # 上一帧位置
var stuck_threshold = 100.0 # 卡住判定阈值(毫秒)

# 获取节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $HealthBar

# 物理引擎相关
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# 初始化玩家
	current_health = max_health
	has_jumped = false # 确保初始状态下玩家未跳跃
	update_health_bar()
	# 默认播放正面站立动画
	animated_sprite.play("front_idle")
	
	# 调试信息：打印初始化参数
	print("[DEBUG] 玩家初始化完成")
	print("[DEBUG] gravity: ", gravity)
	print("[DEBUG] jump_velocity: ", jump_velocity)

# 处理输入和物理更新
func _physics_process(delta):
	# 检查着陆状态 - 如果玩家着陆了，重置跳跃状态
	if is_on_floor() and has_jumped:
		has_jumped = false
		print("[DEBUG] 🛬 玩家着陆，重置has_jumped状态")
	
	# 处理重力
	if not is_on_floor():
		velocity.y += gravity * delta
		# 每60帧打印一次重力调试信息（避免日志过多）
		if Engine.get_process_frames() % 60 == 0:
			print("[DEBUG] 重力应用中 - gravity: ", gravity, ", velocity.y: ", velocity.y)
	
	# 处理跳跃
	# 调试日志：检查跳跃条件
	if Input.is_action_just_pressed("jump"):
		print("[DEBUG] 跳跃键被按下")
		print("[DEBUG] is_on_floor(): ", is_on_floor())
		print("[DEBUG] 当前velocity.y: ", velocity.y)
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		has_jumped = true # 标记玩家通过跳跃进入空中
		print("[DEBUG] 跳跃执行！设置velocity.y为: ", jump_velocity, ", has_jumped=true")
	
	# 处理移动 - 允许在攻击时移动，但下砸攻击和弹反时不允许
	if not is_parrying and not is_down_attacking:
		handle_movement()
	
	# 处理下砸攻击（必须先跳跃才能在空中使用下砸攻击）
	if Input.is_action_just_pressed("dig") and Input.is_action_pressed("down") and not is_on_floor() and has_jumped and not is_down_attacking and not is_attacking:
		print("[DEBUG] 🔨 下砸攻击输入检测到！开始下砸攻击（玩家已跳跃）")
		start_down_attack()
	elif Input.is_action_just_pressed("dig") and Input.is_action_pressed("down") and not is_on_floor() and not has_jumped:
		print("[DEBUG] ❌ 下砸攻击被拒绝：玩家未通过跳跃进入空中（可能是从高处掉落）")
	# 检查是否停止下砸攻击（松开下键或攻击键）
	elif is_down_attacking and (not Input.is_action_pressed("down") or not Input.is_action_pressed("dig")):
		print("[DEBUG] 🔨 玩家松开下砸攻击键，结束下砸攻击")
		end_down_attack()
	# 处理普通攻击
	elif Input.is_action_just_pressed("dig") and not is_attacking and not is_defending and not is_down_attacking:
		print("[DEBUG] 🗡️ 攻击输入检测到！开始攻击")
		attack()
	elif Input.is_action_just_pressed("dig"):
		print("[DEBUG] 攻击输入检测到，但状态不允许 - 攻击中: ", is_attacking, ", 防御中: ", is_defending, ", 下砸中: ", is_down_attacking, ", 已跳跃: ", has_jumped, ", 在地面: ", is_on_floor())
	
	# 处理防御
	if Input.is_action_just_pressed("defend") and not is_attacking:
		defend()
	
	# 处理防御释放
	if Input.is_action_just_released("defend"):
		release_defend()
	
	# 处理重新开始游戏（R键）
	if Input.is_action_just_pressed("reset"):
		print("[DEBUG] 🔄 R键被按下，重新开始游戏")
		restart_game()
	
	# 更新弹反计时器
	if is_defending:
		parry_timer += delta * 1000 # 转换为毫秒
		# 检查弹反窗口是否结束
		if parry_timer >= parry_window_duration:
			is_defending = false
			parry_timer = 0
			print("[DEBUG] 弹反窗口结束，自动结束防御")
	
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
	
	# 应用移动（确保节点已准备好）
	if is_inside_tree() and get_physics_process_delta_time() > 0:
		move_and_slide()
	
	# 防卡住检测机制
	check_stuck_state(delta)
	
	# 更新动画
	update_animation()

# 处理移动逻辑
func handle_movement():
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("left"):
		direction.x -= 1
		facing_direction = "left"
	if Input.is_action_pressed("right"):
		direction.x += 1
		facing_direction = "right"
	# if Input.is_action_pressed("up"):
	# 	direction.y -= 1
	# 	facing_direction = "back"
	if Input.is_action_pressed("down"):
		direction.y += 1
		facing_direction = "front"
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	# 在攻击时移动速度减半，避免玩家卡住
	var current_speed = move_speed
	if is_attacking:
		current_speed = move_speed * 0.5
	
	# 改进的卡住检测和处理
	if direction.x != 0:
		# 检测是否真的卡住了：有输入但速度很小，且不是刚开始移动
		if abs(velocity.x) < 30.0 and Engine.get_process_frames() % 10 == 0:
			# 应用强力推进
			var push_force = direction.x * move_speed * 2.0
			velocity.x = push_force
			
			# 智能跳跃检测：只有在检测到前方有障碍物时才跳跃
			if is_on_floor() and abs(velocity.x) < 50.0:
				# 使用射线检测前方是否有障碍物
				var space_state = get_world_2d().direct_space_state
				var query = PhysicsRayQueryParameters2D.create(
					global_position,
					global_position + Vector2(direction.x * 50, 0),
					32769 # 检测墙壁图层（layers 1 + 16）
				)
				var result = space_state.intersect_ray(query)
				
				if result:
					# 前方有障碍物，需要小跳跃
					velocity.y = jump_velocity * 0.25 # 更小的跳跃高度
					print("[DEBUG] 🦘 检测到前方障碍，辅助小跳脱离")
				else:
					# 前方无障碍，可能是地形问题，只水平推进
					print("[DEBUG] ➡️ 前方无障碍，强化水平推进")
			
			print("[DEBUG] 🚀 应用强力推进脱离卡住 - 推力: ", push_force)
		else:
			velocity.x = direction.x * current_speed
	else:
		velocity.x = 0
	
	# 不再处理velocity.y，跳跃和重力已在主流程处理

# 更新动画状态
func update_animation():
	var animation_name = ""
	
	# 处理攻击动画
	if is_attacking:
		if facing_direction == "front":
			animation_name = "front_attack"
		elif facing_direction == "back":
			animation_name = "back_attack"
		else: # left or right
			animation_name = "side_attack"
			animated_sprite.flip_h = (facing_direction == "left")
	# 处理防御/弹反动画
	elif is_defending or is_parrying:
		# 这里可以添加防御/弹反的动画，如果有的话
		# 暂时使用idle动画
		if facing_direction == "front":
			animation_name = "front_idle"
		elif facing_direction == "back":
			animation_name = "back_idle"
		else:
			animation_name = "side_idle"
			animated_sprite.flip_h = (facing_direction == "left")
	# 处理移动/站立动画
	elif velocity.length() > 0:
		if abs(velocity.x) > abs(velocity.y):
			# 水平移动
			animation_name = "side_walk"
			animated_sprite.flip_h = (velocity.x < 0)
			facing_direction = "right" if velocity.x > 0 else "left"
		elif velocity.y < 0:
			# 向上移动
			animation_name = "back_walk"
			facing_direction = "back"
		else:
			# 向下移动
			animation_name = "front_walk"
			facing_direction = "front"
	else:
		# 站立动画
		if facing_direction == "front":
			animation_name = "front_idle"
		elif facing_direction == "back":
			animation_name = "back_idle"
		else:
			animation_name = "side_idle"
			animated_sprite.flip_h = (facing_direction == "left")
	
	# 应用动画
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

# 攻击函数
func attack():
	print("[DEBUG] ⚔️ 攻击函数开始执行")
	is_attacking = true
	
	# 播放攻击动画
	if facing_direction == "front":
		animated_sprite.play("front_attack")
	elif facing_direction == "back":
		animated_sprite.play("back_attack")
	else:
		animated_sprite.play("side_attack")
		animated_sprite.flip_h = (facing_direction == "left")
	
	print("[DEBUG] 攻击动画播放: ", animated_sprite.animation, ", 朝向: ", facing_direction)
	
	# 创建攻击区域
	var attack_area = create_attack_area()
	print("[DEBUG] 攻击区域已创建")
	
	# 攻击结束后恢复状态
	await get_tree().create_timer(0.4).timeout
	print("[DEBUG] 攻击结束，清理攻击区域")
	is_attacking = false
	if is_instance_valid(attack_area):
		attack_area.queue_free()

# 创建攻击区域
func create_attack_area():
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# 设置碰撞形状大小
	shape.size = Vector2(30, 50)
	collision.shape = shape
	
	# 设置碰撞检测层和掩码
	# 假设敌人在第2层(collision_layer = 2)
	area.collision_mask = 2 # 检测第2层的物体
	area.monitoring = true # 启用监控
	
	# 根据朝向设置攻击区域位置
	# 整体位置下降一半，向下攻击时额外向下20
	if facing_direction == "front":
		area.position = Vector2(0, 40 + 20) # 原位置 + 下降一半
	elif facing_direction == "back":
		area.position = Vector2(0, -40 + 20) # 原位置 + 下降一半
	elif facing_direction == "left":
		area.position = Vector2(-20, 0 + 20) # 原位置 + 下降一半
	else: # right
		area.position = Vector2(30, 0 + 20) # 原位置 + 下降一半
	
	# 添加到场景
	add_child(area)
	area.add_child(collision)
	
	# 连接信号
	area.body_entered.connect(_on_attack_area_body_entered)
	
	print("[DEBUG] 创建攻击区域 - 位置: ", area.position, ", 碰撞掩码: ", area.collision_mask)
	return area

# 攻击区域检测到敌人
func _on_attack_area_body_entered(body):
	print("[DEBUG] 攻击区域检测到碰撞体: ", body.name)
	if body.has_method("take_damage") and body != self:
		print("[DEBUG] ⚔️ 玩家攻击敌人 - 伤害: ", attack_damage)
		body.take_damage(attack_damage, self)
	else:
		print("[DEBUG] 碰撞体无法受到伤害或是玩家自身")

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
			attacker.take_damage(damage) # 双倍反弹伤害
		else:
			print("[DEBUG] 攻击者无法接受反弹伤害")

# 反弹子弹函数 - 将子弹原路返回并重置射程
func reflect_bullet(bullet):
	# 检查子弹是否有速度信息
	if bullet.has_meta("velocity"):
		# 反转子弹速度方向
		var original_velocity = bullet.get_meta("velocity")
		var reflected_velocity = - original_velocity
		bullet.set_meta("velocity", reflected_velocity)
		
		# 修改子弹的伤害目标（让子弹能伤害敌人而不是玩家）
		bullet.set_meta("reflected", true)
		
		# 重置子弹的生命周期计时器，恢复完整射程
		reset_bullet_lifetime(bullet)

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
			break

# 受到伤害 - 处理弹反、防御和伤害逻辑
func take_damage(damage, attacker = null) -> bool:
	# 如果正在弹反，反弹伤害
	if is_parrying:
		reflect_attack(damage, attacker)
		return true # 返回 true 表示成功格挡
	
	# 如果正在防御且在弹反窗口内，触发弹反
	if is_defending and parry_timer <= parry_window_duration:
		parry() # 激活弹反状态
		reflect_attack(damage, attacker)
		return true # 返回 true 表示成功格挡
	
	# 如果处于无敌状态，不受伤害
	if is_invulnerable:
		return false # 返回 false 表示未受伤害但也未格挡
	
	# 应用伤害
	current_health -= damage
	current_health = max(0, current_health) # 确保生命值不为负
	
	# 添加击退效果，帮助玩家脱离碰撞
	if attacker != null:
		add_knockback(attacker)
	
	# 更新血量显示
	update_health_bar()
	
	# 设置短暂无敌时间
	is_invulnerable = true
	invulnerability_timer = 0
	
	# 检查是否死亡
	if current_health <= 0:
		die()
	else:
		# 播放受伤动画/效果
		# ...
		pass
	
	return false # 返回 false 表示受到了伤害

# 死亡函数
func die():
	# 播放死亡动画
	animated_sprite.play("death")
	
	# 禁用输入
	set_physics_process(false)
	
	# 等待动画播放完毕
	await animated_sprite.animation_finished
	
	restart_game()

# 更新血量显示
func update_health_bar():
	# 如果满血，隐藏血条
	if current_health >= max_health:
		health_bar.visible = false
	else:
		health_bar.visible = true
		health_bar.value = float(current_health) / max_health * 100

# 升级生命值
func upgrade_health(amount):
	max_health += amount
	current_health = max_health
	update_health_bar()

# 恢复生命值
func heal(amount):
	current_health += amount
	current_health = min(current_health, max_health)
	update_health_bar()

# 重新开始游戏函数
func restart_game():
	"""重新开始游戏 - 重置玩家状态并切换到城镇场景"""
	print("[DEBUG] 开始重新开始游戏流程")
	
	# 重置玩家状态
	current_health = max_health
	is_attacking = false
	is_defending = false
	is_parrying = false
	is_invulnerable = false
	is_down_attacking = false
	has_jumped = false # 重置跳跃状态
	parry_timer = 0
	invulnerability_timer = 0
	velocity = Vector2.ZERO
	
	# 重置动画状态
	set_shader_blink_intensity(0.0)
	animated_sprite.play("front_idle")
	
	# 更新血量显示
	update_health_bar()
	
	# 直接重新加载当前场景
	get_tree().reload_current_scene()
	print("[DEBUG] RPG游戏重置完成")

# 开始下砸攻击
func start_down_attack():
	"""开始下砸攻击 - 玩家快速向下移动并攻击"""
	print("[DEBUG] 🔨 开始下砸攻击")
	is_down_attacking = true
	is_attacking = true
	
	# 设置向下的高速度
	velocity.y = down_attack_velocity
	velocity.x = 0 # 停止水平移动
	
	# 播放下砸攻击动画
	animated_sprite.play("front_attack") # 可以后续添加专门的下砸动画
	
	# 创建下砸攻击区域
	create_down_attack_area()

func create_down_attack_area():
	"""创建下砸攻击的碰撞检测区域"""
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# 设置碰撞形状大小（宽度与普通攻击一致，高度稍大）
	shape.size = Vector2(18, 20)
	collision.shape = shape
	
	# 设置碰撞检测层和掩码
	area.collision_mask = 2 # 检测第2层的物体（敌人）
	area.collision_mask |= 16 # 检测第16层（地面瓦片）
	area.monitoring = true
	
	# 设置攻击区域位置（在玩家下方）
	area.position = Vector2(4, 50)
	
	# 添加到场景
	add_child(area)
	area.add_child(collision)
	
	# 连接信号
	area.body_entered.connect(_on_down_attack_area_body_entered)
	area.area_entered.connect(_on_down_attack_area_area_entered)
	
	print("[DEBUG] 下砸攻击区域已创建")
	return area

func _on_down_attack_area_body_entered(body):
	"""下砸攻击区域检测到碰撞体"""
	print("[DEBUG] 下砸攻击检测到碰撞体: ", body.name, ", 类型: ", body.get_class())
	
	# 如果击中敌人
	if body.has_method("take_damage") and body != self:
		print("[DEBUG] 🔨 下砸攻击击中敌人！")
		body.take_damage(attack_damage, self)
		trigger_bounce()
	# 如果击中地面、平台或瓦片地图
	elif (body.is_in_group("ground") or body.is_in_group("platform") or
		  body.name.to_lower().contains("ground") or body.name.to_lower().contains("floor") or
		  body.name.to_lower().contains("tile") or body is TileMapLayer or body is TileMap):
		print("[DEBUG] 🔨 下砸攻击击中地面/瓦片！")
		trigger_bounce()
	# 如果是任何静态物体（StaticBody2D）也可以反弹
	elif body is StaticBody2D:
		print("[DEBUG] 🔨 下砸攻击击中静态物体！")
		trigger_bounce()

func _on_down_attack_area_area_entered(area):
	"""下砸攻击区域检测到其他Area2D"""
	print("[DEBUG] 下砸攻击检测到区域: ", area.name)
	# 可以用于检测特殊的可反弹区域

func trigger_bounce():
	"""触发反弹效果"""
	if not is_down_attacking:
		return
		
	print("[DEBUG] 🚀 触发反弹效果！")
	
	# 设置向上的反弹速度
	velocity.y = bounce_velocity
	
	# 结束当前下砸攻击状态，但保持可以立即再次下砸
	is_down_attacking = false
	is_attacking = false
	
	# 保持has_jumped为true，允许连续下砸攻击（无限弹跳）
	# has_jumped = true  # 已经是true，不需要重新设置
	
	# 清理下砸攻击区域
	for child in get_children():
		if child is Area2D and child.has_method("queue_free"):
			# 检查是否是下砸攻击区域（通过位置判断）
			if child.position.y > 30: # 下砸攻击区域在下方
				child.queue_free()
				break
	
	# 播放反弹动画或效果
	animated_sprite.play("front_idle") # 可以后续添加专门的反弹动画
	
	print("[DEBUG] 反弹完成，玩家保持跳跃状态，可以立即再次下砸攻击实现无限弹跳！")

# 结束下砸攻击
func end_down_attack():
	"""结束下砸攻击状态 - 玩家松开按键时调用"""
	print("[DEBUG] 🔨 结束下砸攻击状态")
	
	# 结束下砸攻击状态
	is_down_attacking = false
	is_attacking = false
	
	# 清理下砸攻击区域
	for child in get_children():
		if child is Area2D and child.has_method("queue_free"):
			# 检查是否是下砸攻击区域（通过位置判断）
			if child.position.y > 30: # 下砸攻击区域在下方
				child.queue_free()
				break
	
	# 恢复正常动画
	animated_sprite.play("front_idle")
	
	print("[DEBUG] 下砸攻击结束，玩家可以继续操作")

# 检测卡住状态并自动脱离
func check_stuck_state(delta):
	"""检测玩家是否卡住，并自动应用脱离机制"""
	# 只在有水平输入时检测
	var has_horizontal_input = Input.is_action_pressed("left") or Input.is_action_pressed("right")
	if not has_horizontal_input:
		stuck_timer = 0.0
		last_position = global_position
		return
	
	# 检测位置变化
	var position_change = global_position.distance_to(last_position)
	
	# 如果位置变化很小，增加卡住计时器
	if position_change < 5.0: # 5像素的移动阈值
		stuck_timer += delta * 1000 # 转换为毫秒
		
		# 如果卡住时间超过阈值，强制脱离
		if stuck_timer >= stuck_threshold:
			apply_unstuck_force()
			stuck_timer = 0.0 # 重置计时器
	else:
		stuck_timer = 0.0 # 重置计时器
	
	last_position = global_position

# 应用强制脱离力
func apply_unstuck_force():
	"""当检测到玩家卡住时，应用智能强制脱离力"""
	print("[DEBUG] 💥 检测到玩家卡住，应用智能脱离机制")
	
	# 确定脱离方向
	var unstuck_direction = Vector2.ZERO
	if Input.is_action_pressed("left"):
		unstuck_direction.x = -1
	elif Input.is_action_pressed("right"):
		unstuck_direction.x = 1
	
	# 应用强力推进
	if unstuck_direction.x != 0:
		velocity.x = unstuck_direction.x * move_speed * 3.0 # 3倍速度推进
		
		# 智能跳跃脱离：只在真正需要时跳跃
		if is_on_floor():
			# 检测前方是否有障碍物来决定是否需要跳跃
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + Vector2(unstuck_direction.x * 60, 0),
				32769 # 检测墙壁图层（layers 1 + 16）
			)
			var result = space_state.intersect_ray(query)
			
			if result:
				# 前方有障碍，需要跳跃
				velocity.y = jump_velocity * 0.3 # 适中的跳跃高度
				print("[DEBUG] 🦘 检测到前方障碍，应用跳跃脱离")
			else:
				# 前方无障碍，只水平推进
				print("[DEBUG] ➡️ 前方无障碍，纯水平脱离")
		
		print("[DEBUG] 💥 智能脱离力已应用 - 方向: ", unstuck_direction, ", 推力: ", velocity.x)

# 添加击退效果
func add_knockback(attacker):
	"""当玩家受到攻击时，添加智能击退效果帮助脱离碰撞"""
	if attacker == null:
		return
	
	# 计算击退方向（从攻击者到玩家）
	var knockback_direction = (global_position - attacker.global_position).normalized()
	
	# 如果方向计算失败，使用默认方向
	if knockback_direction.length() < 0.1:
		knockback_direction = Vector2(-1, 0) if facing_direction == "left" else Vector2(1, 0)
	
	# 应用水平击退力
	var knockback_force = 450.0 # 稍微减少水平击退力
	velocity.x = knockback_direction.x * knockback_force
	
	# 智能垂直击退逻辑
	if is_on_floor():
		# 在地面上：只有当水平击退不足时才跳跃
		if abs(knockback_direction.x) < 0.3: # 如果主要是垂直攻击
			# 小幅跳跃，避免跳得太高
			velocity.y = jump_velocity * 0.25 # 降低跳跃高度
			print("[DEBUG] 🦘 地面垂直击退：小幅跳跃脱离")
		else:
			# 水平攻击：不跳跃，只水平推开
			print("[DEBUG] ➡️ 地面水平击退：纯水平推开")
	else:
		# 在空中：根据攻击方向调整
		if knockback_direction.y < -0.5: # 从下方攻击，向上推
			velocity.y = min(velocity.y, jump_velocity * 0.3) # 轻微向上推
			print("[DEBUG] ⬆️ 空中向上击退")
		elif knockback_direction.y > 0.5: # 从上方攻击，向下推
			velocity.y = max(velocity.y, -jump_velocity * 0.2) # 轻微向下推
			print("[DEBUG] ⬇️ 空中向下击退")
		# 水平空中攻击：只水平推开，不改变垂直速度
	
	# 短暂减少重力影响，确保击退效果
	await get_tree().create_timer(0.08).timeout
	
	print("[DEBUG] 🔄 智能击退效果应用 - 方向: ", knockback_direction, ", 水平力度: ", knockback_force)

func set_shader_blink_intensity(intensity: float):
		"""设置玩家的Shader的闪烁强度"""
		animated_sprite.material.set_shader_parameter("blink_intensity", intensity)
