extends CharacterBody2D

# 主玩家控制器 - 清理重构版本
# 使用模块化系统，移除重复逻辑

# 节点引用
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var point_light = $PointLight2D
@onready var health_bar = $HealthBar
@onready var hit_box = $HitBox
@onready var down_attack_area = $DownAttackArea

# 玩家状态
var is_dead = false

# 子系统模块
var player_health: PlayerHealth
var player_movement: PlayerMovement
var player_combat: PlayerCombat
var player_dig: PlayerDig
var player_collision: Node

# 游戏模式
var is_rpg_mode = false

func _ready():
	setup_game_mode()
	setup_modules()
	setup_connections()

func _input(event):
	# 处理ESC键返回城镇
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("[DEBUG] ESC键被按下，返回城镇...")
		# 临时注释掉GameManager调用
		# GameManager.change_scene_with_loading("res://Scenes/TownScene/TownScene.tscn")
		get_tree().quit()

func _physics_process(_delta):
	handle_unified_input()

func setup_game_mode():
	"""设置游戏模式"""
	var scene_tree = get_tree()
	if scene_tree and scene_tree.current_scene:
		var scene_name = scene_tree.current_scene.name
		var scene_path = scene_tree.current_scene.scene_file_path
		
		is_rpg_mode = (scene_name == "Game" or
					   scene_path.contains("RPG") or
					   scene_name.to_lower().contains("rpg"))
		
		print("[DEBUG] 场景名称: ", scene_name)
		print("[DEBUG] 检测到游戏模式: ", "RPG模式" if is_rpg_mode else "挖掘模式")
	
	# RPG模式下禁用火把照明
	if is_rpg_mode and point_light:
		point_light.visible = false
		point_light.enabled = false
		print("[DEBUG] RPG模式：已禁用火把照明")
	else:
		if point_light:
			point_light.visible = true
			point_light.enabled = true
			print("[DEBUG] 挖掘模式：已启用火把照明")

func setup_modules():
	"""设置子模块"""
	# 创建健康模块
	player_health = PlayerHealth.new()
	player_health.name = "PlayerHealth"
	add_child(player_health)
	
	# 创建移动模块
	player_movement = PlayerMovement.new()
	player_movement.name = "PlayerMovement"
	add_child(player_movement)
	
	# 创建战斗模块
	player_combat = PlayerCombat.new()
	player_combat.name = "PlayerCombat"
	add_child(player_combat)
	
	# 创建挖掘模块
	player_dig = PlayerDig.new()
	player_dig.name = "PlayerDig"
	add_child(player_dig)
	
	# 创建碰撞模块
	player_collision = Node.new()
	player_collision.set_script(preload("res://Player/player_collision.gd"))
	player_collision.name = "PlayerCollision"
	add_child(player_collision)

func setup_connections():
	"""设置信号连接"""
	if player_health:
		player_health.health_changed.connect(_on_health_changed)
		player_health.died.connect(_on_player_died)
	
	if player_movement:
		player_movement.movement_state_changed.connect(_on_movement_state_changed)
	
	if player_combat:
		player_combat.attack_performed.connect(_on_attack_performed)
		player_combat.parry_triggered.connect(_on_parry_triggered)
	
	if player_dig:
		player_dig.dig_performed.connect(_on_dig_performed)

func handle_unified_input():
	"""统一输入处理"""
	# 如果玩家已死亡，不处理任何输入
	if is_dead:
		return
	
	# 铲子骑士式下砸攻击：只有在DownAttackArea检测到碰撞时才能触发
	# 这里不再直接处理下砸攻击输入，而是交给PlayerCombat处理
	
	# 模式特定输入
	if is_rpg_mode:
		handle_rpg_input()
	else:
		handle_dig_input()
	
	# 通用防御系统
	if player_combat:
		player_combat.handle_combat_input()

func handle_rpg_input():
	"""RPG模式输入"""
	if Input.is_action_just_pressed("dig") and player_combat and not player_combat.is_attacking and not player_combat.is_defending:
		print("[DEBUG] RPG模式攻击输入")
		player_combat.perform_attack()

func handle_dig_input():
	"""挖掘模式输入"""
	if Input.is_action_just_pressed("dig"):
		# 地面近战攻击
		if (is_on_floor() and not has_direction_input() and
			player_combat and not player_combat.is_attacking):
			print("[DEBUG] 挖掘模式地面近战攻击")
			player_combat.perform_melee_attack()
		elif player_dig:
			print("[DEBUG] 挖掘模式，调用挖掘")
			player_dig.handle_dig_input(get_physics_process_delta_time())

func has_direction_input() -> bool:
	"""检查是否有方向键输入"""
	return (Input.is_action_pressed("up") or Input.is_action_pressed("down") or
			Input.is_action_pressed("left") or Input.is_action_pressed("right"))

func play_anim(anim_name: String):
	"""播放动画 - 保护重要动画不被打断"""
	if not animated_sprite:
		print("[ERROR] animated_sprite为空")
		return
		
	# 如果玩家已死亡，强制播放死亡动画
	if is_dead:
		if anim_name != "Dying":
			print("[DEBUG] 玩家已死亡，忽略其他动画请求: ", anim_name)
			animated_sprite.play("Dying")
		return
	
	var current_anim = animated_sprite.animation
	
	# 保护重要动画不被一般动画打断
	var absolutely_protected_anims = ["Hurt", "Dying"]
	if current_anim in absolutely_protected_anims and anim_name != current_anim:
		print("[DEBUG] 绝对保护动画播放中，忽略: ", current_anim, " 请求: ", anim_name)
		return
	
	# Dig动画的条件保护 - 只在实际使用时保护
	if current_anim == "Dig" and anim_name != "Dig":
		var combat_module = get_node_or_null("PlayerCombat")
		var dig_module = get_node_or_null("PlayerDig")
		
		var is_attacking = combat_module and combat_module.is_attacking
		var is_digging = dig_module and (dig_module.is_digging or dig_module.is_dig_animation_playing)
		
		if is_attacking or is_digging:
			print("[DEBUG] Dig动画使用中，忽略: ", current_anim, " 请求: ", anim_name)
			return
		else:
			print("[DEBUG] Dig动画已结束，允许切换到: ", anim_name)
	
	# 如果动画相同，不重复播放
	if current_anim == anim_name:
		return
	
	# 直接播放动画
	print("[DEBUG] 执行动画切换: ", current_anim, " -> ", anim_name)
	animated_sprite.play(anim_name)

func take_damage(damage: int, attacker = null) -> bool:
	"""接受伤害（委托给战斗系统）"""
	if player_combat:
		return player_combat.take_damage(damage, attacker)
	return false

# 信号回调函数
func _on_health_changed(new_health: int, max_health: int):
	"""血量变化回调"""
	print("[DEBUG] 血量变化: ", new_health, "/", max_health)

func _on_player_died():
	"""玩家死亡回调"""
	print("[DEBUG] 玩家死亡回调 - 设置死亡状态")
	is_dead = true
	# 死亡动画已经在player_health.die()中播放了，这里不需要重复播放
	# 不立即禁用物理处理，让死亡动画和重力继续工作
	# 输入处理在 handle_unified_input() 中通过 is_dead 检查来阻止

func _on_movement_state_changed(state: String):
	"""移动状态变化回调"""
	print("[DEBUG] 移动状态变化: ", state)

func _on_attack_performed():
	"""攻击执行回调"""
	print("[DEBUG] 攻击执行")

func _on_parry_triggered():
	"""弹反触发回调"""
	print("[DEBUG] 弹反触发")

func _on_dig_performed(dig_position: Vector2):
	"""挖掘执行回调"""
	print("[DEBUG] 挖掘执行，位置: ", dig_position)

# 兼容性方法（保持与现有代码的兼容）
func get_facing_direction() -> int:
	"""获取面向方向"""
	return player_movement.facing_direction if player_movement else 1

func get_current_health() -> int:
	"""获取当前血量"""
	return player_health.current_health if player_health else 0

func heal(amount: int):
	"""治疗"""
	if player_health:
		player_health.heal(amount)

# 兼容旧版本的方法
func get_surrounding_offsets() -> Array:
	return [
		Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0),
		Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1),
		Vector2(1, -1), Vector2(-1, -1)
	]

func try_dig_nearby(world_position: Vector2) -> bool:
	for offset in get_surrounding_offsets():
		var mine_scene = get_parent()
		if mine_scene and mine_scene.has_method("dig_at_position") and mine_scene.dig_at_position(world_position + offset):
			return true
	return false
