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
var invulnerability_duration = 1000 # 受伤后无敌时间(毫秒)

# 获取节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var health_bar = $HealthBar

# 物理引擎相关
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# 初始化玩家
	current_health = max_health
	update_health_bar()
	# 默认播放正面站立动画
	animated_sprite.play("front_idle")
	
	# 调试信息：打印初始化参数
	print("[DEBUG] 玩家初始化完成")
	print("[DEBUG] gravity: ", gravity)
	print("[DEBUG] jump_velocity: ", jump_velocity)

# 处理输入和物理更新
func _physics_process(delta):
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
		print("[DEBUG] 跳跃执行！设置velocity.y为: ", jump_velocity)
	
	# 处理移动
	if not is_attacking and not is_parrying:
		handle_movement()
	
	# 处理攻击
	if Input.is_action_just_pressed("dig") and not is_attacking and not is_defending:
		print("[DEBUG] 🗡️ 攻击输入检测到！开始攻击")
		attack()
	elif Input.is_action_just_pressed("dig"):
		print("[DEBUG] 攻击输入检测到，但状态不允许 - 攻击中: ", is_attacking, ", 防御中: ", is_defending)
	
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
			animated_sprite.modulate.a = 1.0
		else:
			# 闪烁效果
			if int(invulnerability_timer / 100) % 2 == 0:
				animated_sprite.modulate.a = 0.5
			else:
				animated_sprite.modulate.a = 1.0
	
	# 应用移动（确保节点已准备好）
	if is_inside_tree() and get_physics_process_delta_time() > 0:
		move_and_slide()
	
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
	
	velocity.x = direction.x * move_speed
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
	shape.size = Vector2(40, 60)
	collision.shape = shape
	
	# 设置碰撞检测层和掩码
	# 假设敌人在第2层(collision_layer = 2)
	area.collision_mask = 2  # 检测第2层的物体
	area.monitoring = true   # 启用监控
	
	# 根据朝向设置攻击区域位置
	# 整体位置下降一半，向下攻击时额外向下20
	if facing_direction == "front":
		area.position = Vector2(0, 40 + 20 + 20)  # 原位置 + 下降一半 + 额外向下20
	elif facing_direction == "back":
		area.position = Vector2(0, -40 + 20)  # 原位置 + 下降一半
	elif facing_direction == "left":
		area.position = Vector2(-40, 0 + 20)  # 原位置 + 下降一半
	else: # right
		area.position = Vector2(40, 0 + 20)  # 原位置 + 下降一半
	
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
	print("[DEBUG] 🔄 开始反弹子弹")
	
	# 检查子弹是否有速度信息
	if bullet.has_meta("velocity"):
		# 反转子弹速度方向
		var original_velocity = bullet.get_meta("velocity")
		var reflected_velocity = -original_velocity
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

# 受到伤害 - 处理弹反、防御和伤害逻辑
func take_damage(damage, attacker = null):
	print("[DEBUG] 玩家受到攻击 - 伤害: ", damage, ", 攻击者: ", attacker)
	print("[DEBUG] 当前状态 - 弹反: ", is_parrying, ", 防御: ", is_defending, ", 无敌: ", is_invulnerable)
	print("[DEBUG] 弹反计时器: ", parry_timer, "ms")
	
	# 如果正在弹反，反弹伤害
	if is_parrying:
		print("[DEBUG] ⚡ 弹反状态中！反弹攻击")
		reflect_attack(damage, attacker)
		return
	
	# 如果正在防御且在弹反窗口内，触发弹反
	if is_defending and parry_timer <= parry_window_duration:
		print("[DEBUG] ⚡ 完美弹反！触发反弹")
		parry() # 激活弹反状态
		reflect_attack(damage, attacker)
		return
	
	# 如果处于无敌状态，不受伤害
	if is_invulnerable:
		print("[DEBUG] 💫 无敌状态，免疫伤害")
		return
	
	# 应用伤害
	current_health -= damage
	current_health = max(0, current_health) # 确保生命值不为负
	
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
	parry_timer = 0
	invulnerability_timer = 0
	velocity = Vector2.ZERO
	
	# 重置动画状态
	animated_sprite.modulate.a = 1.0
	animated_sprite.play("front_idle")
	
	# 更新血量显示
	update_health_bar()
	
	# 直接重新加载当前场景
	get_tree().reload_current_scene()
	print("[DEBUG] RPG游戏重置完成")
