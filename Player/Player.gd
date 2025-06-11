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

# 子系统模块
var player_health: PlayerHealth
var player_movement: PlayerMovement
var player_combat: PlayerCombat
var player_dig: PlayerDig

# 游戏模式
var is_rpg_mode = false

func _ready():
	setup_game_mode()
	setup_modules()
	setup_connections()

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
	# 下砸攻击（两种模式都支持）
	if (Input.is_action_just_pressed("dig") and Input.is_action_pressed("down") and
		not is_on_floor() and player_movement and player_movement.can_down_attack and
		not player_movement.is_down_attacking and not player_combat.is_attacking):
		print("[DEBUG] 触发下砸攻击 - 模式: ", "RPG" if is_rpg_mode else "挖掘")
		player_movement.start_down_attack()
		player_combat.is_attacking = true
		
	elif (player_movement and player_movement.is_down_attacking and
		  (not Input.is_action_pressed("down") or not Input.is_action_pressed("dig"))):
		player_movement.end_down_attack()
		player_combat.is_attacking = false
	
	# 模式特定输入
	elif is_rpg_mode:
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
		return
	
	# 保护重要动画不被一般动画打断
	var protected_anims = ["Dig", "Hurt", "Dying"]
	var current_anim = animated_sprite.animation
	
	# 如果当前是保护动画，且要播放的不是同一个动画，则不切换
	if current_anim in protected_anims and anim_name != current_anim:
		return
	
	# 如果动画相同，不重复播放
	if current_anim == anim_name:
		return
		
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
	print("[DEBUG] 玩家死亡")

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
