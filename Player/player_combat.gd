class_name PlayerCombat
extends Node

# 战斗系统管理
signal attack_performed
signal defense_started
signal defense_ended
signal parry_triggered

# 战斗参数
var attack_damage = 1
var is_attacking = false
var is_defending = false
var is_parrying = false
var parry_window_duration = 1000 # 毫秒
var parry_timer = 0

# 下砸攻击相关
var is_in_down_attack_area = false # 玩家是否在下砸攻击区域内
var down_attack_targets = [] # 当前在下砸攻击区域内的目标

@onready var player: CharacterBody2D = get_parent()
@onready var hit_box = player.get_node("HitBox")
@onready var down_attack_area = player.get_node("DownAttackArea")
@onready var animated_sprite = player.get_node("AnimatedSprite2D")

var player_movement: PlayerMovement
var player_health: PlayerHealth

func _ready():
	# 获取其他模块的引用
	player_movement = player.get_node("PlayerMovement")
	player_health = player.get_node("PlayerHealth")
	
	# 连接攻击区域信号
	if hit_box:
		hit_box.body_entered.connect(_on_attack_area_body_entered)
	
	if down_attack_area:
		down_attack_area.body_entered.connect(_on_down_attack_area_body_entered)
		down_attack_area.body_exited.connect(_on_down_attack_area_body_exited)
		# 启用下砸攻击区域监听（铲子骑士式需要持续监听）
		down_attack_area.monitoring = true
		print("[DEBUG] DownAttackArea设置完成 - monitoring: ", down_attack_area.monitoring,
			  " collision_mask: ", down_attack_area.collision_mask,
			  " position: ", down_attack_area.position)
	else:
		print("[ERROR] DownAttackArea节点未找到！")

func _process(delta):
	update_parry_timer(delta)
	
	# 定期输出DownAttackArea状态（每秒一次）
	if Engine.get_physics_frames() % 60 == 0:
		if down_attack_targets.size() > 0:
			print("[DEBUG] DownAttackArea状态 - 目标数: ", down_attack_targets.size(),
				  " 区域激活: ", is_in_down_attack_area,
				  " monitoring: ", down_attack_area.monitoring if down_attack_area else "null")

func update_parry_timer(delta):
	"""更新弹反计时器"""
	if is_defending:
		parry_timer += delta * 1000
		if parry_timer >= parry_window_duration:
			is_defending = false
			parry_timer = 0
			end_defend()

func handle_combat_input():
	"""处理战斗输入"""
	# 防御输入
	if Input.is_action_just_pressed("defend") and not is_attacking:
		start_defend()
	
	if Input.is_action_just_released("defend"):
		end_defend()
	
	# 调试下砸攻击输入
	if Input.is_action_just_pressed("dig"):
		print("[DEBUG] 下砸攻击输入检测:")
		print("  - dig键按下: ", Input.is_action_just_pressed("dig"))
		print("  - 在下砸攻击区域: ", is_in_down_attack_area)
		print("  - 未在攻击中: ", not is_attacking)
		print("  - 不在地面: ", not player.is_on_floor())
		print("  - 区域内目标数: ", down_attack_targets.size())
		if down_attack_targets.size() > 0:
			print("  - 目标列表: ", down_attack_targets.map(func(target): return target.name))
	
	# 临时简化条件：只要按下dig键且在空中就触发（用于调试）
	if (Input.is_action_just_pressed("dig") and not player.is_on_floor()):
		print("[DEBUG] 简化条件下砸攻击触发")
		if is_in_down_attack_area and down_attack_targets.size() > 0:
			print("[DEBUG] 触发铲子骑士式下砸攻击 - 区域内目标数量: ", down_attack_targets.size())
			perform_down_attack()
			# 立即触发反弹
			if player_movement:
				player_movement.trigger_bounce()
		else:
			print("[DEBUG] 下砸攻击条件不满足 - 区域:", is_in_down_attack_area, " 目标数:", down_attack_targets.size())

func start_defend():
	"""开始防御"""
	is_defending = true
	parry_timer = 0
	defense_started.emit()
	print("[DEBUG] 开始防御 - 激活弹反窗口")

func end_defend():
	"""结束防御"""
	is_defending = false
	parry_timer = 0
	defense_ended.emit()
	print("[DEBUG] 结束防御")

func perform_attack():
	"""执行攻击（RPG模式）"""
	if is_attacking:
		return
	
	is_attacking = true
	update_hitbox_position()
	
	if hit_box:
		hit_box.monitoring = true
	
	if animated_sprite:
		animated_sprite.play("Dig")
	
	attack_performed.emit()
	
	# 攻击持续时间
	await get_tree().create_timer(0.4).timeout
	
	is_attacking = false
	if hit_box:
		hit_box.monitoring = false
	
	# 攻击结束后恢复正常动画状态
	restore_normal_animation()

func restore_normal_animation():
	"""攻击结束后恢复正常动画状态"""
	if not player or not player_movement:
		return
	
	# 标记攻击动画结束，让movement系统重新控制动画
	if animated_sprite and animated_sprite.animation == "Dig":
		print("[COMBAT DEBUG] 攻击动画结束，恢复正常动画状态")
		# 根据当前状态设置正确的动画
		if player.is_on_floor():
			if abs(player.velocity.x) > 30.0:
				player.play_anim("Walk")
			else:
				player.play_anim("Idle")
		else:
			player.play_anim("jump")

func perform_melee_attack():
	"""执行近战攻击（挖掘模式）"""
	if is_attacking:
		return
	
	is_attacking = true
	update_hitbox_position()
	
	if hit_box:
		hit_box.monitoring = true
	
	if animated_sprite:
		animated_sprite.play("Dig")
	
	attack_performed.emit()
	
	# 攻击持续时间
	await get_tree().create_timer(0.3).timeout
	
	is_attacking = false
	if hit_box:
		hit_box.monitoring = false
	
	# 攻击结束后恢复正常动画状态
	restore_normal_animation()

func update_hitbox_position():
	"""更新攻击盒子位置"""
	if not hit_box or not player_movement:
		return
	
	var base_offset_x = 180.0
	var base_offset_y = -10.0
	var attack_offset = Vector2(base_offset_x * player_movement.facing_direction, base_offset_y)
	
	hit_box.position = attack_offset

func take_damage(damage: int, attacker = null) -> bool:
	"""处理受到伤害"""
	print("[DEBUG] 玩家受到攻击 - 伤害: ", damage, ", 攻击者: ", attacker)
	
	# 弹反检查
	if is_parrying:
		print("[DEBUG] ⚡ 弹反状态中！反弹攻击")
		reflect_attack(damage, attacker)
		return true
	
	# 完美弹反检查
	if is_defending and parry_timer <= parry_window_duration:
		print("[DEBUG] ⚡ 完美弹反！触发反弹")
		trigger_parry()
		reflect_attack(damage, attacker)
		return true
	
	# 传递给血量系统处理
	if player_health:
		return player_health.take_damage(damage)
	
	return false

func trigger_parry():
	"""触发弹反"""
	is_defending = false
	is_parrying = true
	parry_timer = 0
	parry_triggered.emit()
	
	print("[DEBUG] 🛡️ 弹反状态激活")
	
	# 弹反持续时间
	await get_tree().create_timer(0.3).timeout
	is_parrying = false

func reflect_attack(damage: int, attacker = null):
	"""反弹攻击"""
	if attacker == null:
		return
	
	# 判断攻击类型并反弹
	if attacker.get_script() and attacker.get_script().get_path().ends_with("bullet.gd"):
		reflect_bullet(attacker)
	else:
		# 近战攻击反弹
		if attacker.has_method("take_damage"):
			attacker.take_damage(damage * 2, player)

func reflect_bullet(bullet):
	"""反弹子弹"""
	if bullet.has_meta("velocity"):
		var original_velocity = bullet.get_meta("velocity")
		var reflected_velocity = - original_velocity
		bullet.set_meta("velocity", reflected_velocity)
		bullet.set_meta("reflected", true)
		reset_bullet_lifetime(bullet)

func reset_bullet_lifetime(bullet):
	"""重置子弹生命周期"""
	for child in bullet.get_children():
		if child is Timer:
			const BULLET_VELOCITY = 850.0
			const BULLET_RANGE = 500.0
			var bullet_lifetime = BULLET_RANGE / BULLET_VELOCITY
			
			child.stop()
			child.wait_time = bullet_lifetime
			child.start()
			print("[DEBUG] 子弹生命周期已重置，新射程: ", BULLET_RANGE)
			break
	"""重置子弹生命周期"""
	for child in bullet.get_children():
		if child is Timer:
			const BULLET_VELOCITY = 850.0
			const BULLET_RANGE = 500.0
			var bullet_lifetime = BULLET_RANGE / BULLET_VELOCITY
			
			child.stop()
			child.wait_time = bullet_lifetime
			child.start()
			break

func _on_attack_area_body_entered(body):
	"""攻击区域检测"""
	if body == player:
		return
	
	if body.has_method("take_damage"):
		print("[DEBUG] ⚔️ 对敌人造成伤害: ", attack_damage)
		body.take_damage(attack_damage, player)

func _on_down_attack_area_body_entered(body):
	"""下砸攻击区域检测 - 铲子骑士式"""
	if body == player:
		return
	
	print("[DEBUG] DownAttackArea检测到物体进入:")
	print("  - 物体名称: ", body.name)
	print("  - 物体类型: ", body.get_class())
	print("  - 物体脚本: ", body.get_script().get_path() if body.get_script() else "无脚本")
	if body is CharacterBody2D or body is StaticBody2D or body is RigidBody2D:
		print("  - 碰撞层: ", body.collision_layer)
		print("  - 碰撞掩码: ", body.collision_mask)
	
	# 添加目标到下砸攻击区域
	if body not in down_attack_targets:
		down_attack_targets.append(body)
		is_in_down_attack_area = true
		print("[DEBUG] 进入下砸攻击区域 - 目标: ", body.name, " 总目标数: ", down_attack_targets.size())

func _on_down_attack_area_body_exited(body):
	"""目标离开下砸攻击区域"""
	if body == player:
		return
	
	# 从下砸攻击区域移除目标
	if body in down_attack_targets:
		down_attack_targets.erase(body)
		if down_attack_targets.size() == 0:
			is_in_down_attack_area = false
		print("[DEBUG] 离开下砸攻击区域 - 目标: ", body.name, " 剩余目标数: ", down_attack_targets.size())

func perform_down_attack():
	"""执行铲子骑士式下砸攻击"""
	is_attacking = true
	
	# 对区域内的所有目标造成伤害
	for target in down_attack_targets:
		if target and target.has_method("take_damage"):
			print("[DEBUG] ⚔️ 下砸攻击对目标造成伤害: ", attack_damage)
			target.take_damage(attack_damage, player)
		elif target and (target.is_in_group("ground") or target.is_in_group("platform") or
			target.name.to_lower().contains("ground") or target.name.to_lower().contains("floor") or
			target.name.to_lower().contains("tile") or target is TileMapLayer or target is TileMap):
			# 检查挖掘模式下的地面挖掘
			if not player.is_rpg_mode:
				var player_dig = player.get_node_or_null("PlayerDig")
				if player_dig:
					player_dig.perform_down_attack_dig()
	
	# 播放攻击动画
	if animated_sprite:
		animated_sprite.play("Dig")
	
	attack_performed.emit()
	
	# 短暂的攻击持续时间
	await get_tree().create_timer(0.2).timeout
	
	is_attacking = false
	restore_normal_animation()
