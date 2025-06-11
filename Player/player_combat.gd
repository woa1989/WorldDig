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

func _process(delta):
	update_parry_timer(delta)

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
	"""下砸攻击区域检测"""
	if not player_movement or not player_movement.is_down_attacking:
		return
	
	if body == player:
		return
	
	var should_bounce = false
	
	# 检查敌人
	if body.has_method("take_damage"):
		body.take_damage(attack_damage, player)
		should_bounce = true
	# 检查地面
	elif (body.is_in_group("ground") or body.is_in_group("platform") or
		  body.name.to_lower().contains("ground") or body.name.to_lower().contains("floor") or
		  body.name.to_lower().contains("tile") or body is TileMapLayer or body is TileMap):
		# 检查是否是RPG模式
		if player.is_rpg_mode:
			should_bounce = true
		else:
			# 挖掘模式下尝试挖掘
			var player_dig = player.get_node_or_null("PlayerDig")
			if player_dig and player_dig.perform_down_attack_dig():
				should_bounce = true
			else:
				should_bounce = true
	else:
		should_bounce = true
	
	if should_bounce and player_movement:
		player_movement.trigger_bounce()
