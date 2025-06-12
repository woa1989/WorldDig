class_name PlayerDig
extends Node

# 挖掘系统管理
signal dig_performed(position: Vector2)
signal dig_animation_started
signal dig_animation_finished

# 挖掘参数
var dig_range = 128.0
var dig_timer = 0.0
var dig_cooldown = 0.3
var is_digging = false
var is_dig_animation_playing = false

@onready var player: CharacterBody2D = get_parent()
var animated_sprite: AnimatedSprite2D

var player_movement: PlayerMovement

func _ready():
	player_movement = player.get_node("PlayerMovement")
	# 确保在player完全初始化后获取animated_sprite引用
	animated_sprite = player.get_node("AnimatedSprite2D")
	print("[DEBUG] PlayerDig获取动画精灵引用: ", animated_sprite)

func _process(delta):
	if dig_timer > 0:
		dig_timer -= delta

func handle_dig_input(_delta):
	"""处理挖掘输入"""
	if dig_timer > 0 or is_digging or is_dig_animation_playing:
		return
	
	var dig_direction = get_dig_direction()
	
	if dig_direction != Vector2.ZERO:
		start_dig_animation(dig_direction)

func get_dig_direction() -> Vector2:
	"""获取挖掘方向"""
	if Input.is_action_pressed("up"):
		return Vector2(0, -1)
	elif Input.is_action_pressed("down"):
		return Vector2(0, 1)
	elif Input.is_action_pressed("left"):
		return Vector2(-1, 0)
	elif Input.is_action_pressed("right"):
		return Vector2(1, 0)
	else:
		# 默认朝向前方
		return Vector2(player_movement.facing_direction, 0) if player_movement else Vector2(1, 0)

func start_dig_animation(direction: Vector2):
	"""开始挖掘动画"""
	if not animated_sprite:
		print("[DEBUG] animated_sprite 为空")
		return
	
	is_digging = true
	is_dig_animation_playing = true
	
	# 保存挖掘信息
	var dig_info = {
		"direction": direction,
		"position": player.global_position
	}
	
	print("[DEBUG] 开始播放挖掘动画")
	player.play_anim("Dig")
	
	if direction.x != 0:
		animated_sprite.flip_h = direction.x < 0
	
	dig_timer = dig_cooldown
	dig_animation_started.emit()
	
	# 清理旧的信号连接
	if animated_sprite.animation_finished.is_connected(_on_dig_animation_complete):
		animated_sprite.animation_finished.disconnect(_on_dig_animation_complete)
	
	# 连接新的信号
	animated_sprite.animation_finished.connect(_on_dig_animation_complete.bind(dig_info), CONNECT_ONE_SHOT)
	print("[DEBUG] 信号已连接，等待动画完成")
	
	# 后备计时器（缩短时间）
	var backup_timer = get_tree().create_timer(0.6) # 从1.0秒减少到0.6秒
	backup_timer.timeout.connect(_on_dig_backup_timeout.bind(dig_info), CONNECT_ONE_SHOT)

func _on_dig_animation_complete(dig_info: Dictionary):
	"""挖掘动画完成"""
	print("[DEBUG] 动画完成信号触发")
	if is_digging or is_dig_animation_playing:
		print("[DEBUG] 通过动画完成信号执行挖掘")
		perform_dig(dig_info)
		end_dig_animation()
	else:
		print("[DEBUG] 动画完成但挖掘状态已重置")

func _on_dig_backup_timeout(dig_info: Dictionary):
	"""后备超时处理"""
	if is_digging or is_dig_animation_playing:
		print("[DEBUG] 后备计时器触发，强制完成挖掘")
		perform_dig(dig_info)
		end_dig_animation()

func perform_dig(dig_info: Dictionary):
	"""执行实际挖掘"""
	var direction = dig_info.direction
	var tile_size = dig_range
	var player_grid = (player.global_position / tile_size).floor()
	var target_grid = player_grid + direction
	var dig_position = (target_grid + Vector2(0.5, 0.5)) * tile_size
	
	if try_dig_nearby(dig_position):
		dig_performed.emit(dig_position)
		print("[DEBUG] 挖掘成功，位置: ", dig_position)
	else:
		print("[DEBUG] 挖掘失败")

func end_dig_animation():
	"""结束挖掘动画"""
	print("[DEBUG] 结束挖掘动画状态")
	is_digging = false
	is_dig_animation_playing = false
	dig_animation_finished.emit()
	
	# 等待一帧后恢复动画，让挖掘动画自然结束
	await get_tree().process_frame
	
	# 恢复正常动画状态
	restore_normal_animation_after_dig()

func restore_normal_animation_after_dig():
	"""挖掘结束后恢复正常动画状态"""
	if not player or not animated_sprite:
		return
	
	# 让movement系统重新评估并设置正确的动画
	if animated_sprite.animation == "Dig":
		if player.is_on_floor():
			if abs(player.velocity.x) > 30.0:
				player.play_anim("Walk")
			else:
				player.play_anim("Idle")
		else:
			player.play_anim("jump")

func try_dig_nearby(world_position: Vector2) -> bool:
	"""尝试在附近挖掘"""
	var offsets = [
		Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0),
		Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1),
		Vector2(1, -1), Vector2(-1, -1)
	]
	
	for offset in offsets:
		var mine_scene = player.get_parent()
		if mine_scene and mine_scene.has_method("dig_at_position"):
			if mine_scene.dig_at_position(world_position + offset):
				return true
	return false

func perform_down_attack_dig() -> bool:
	"""下砸攻击时的挖掘"""
	if player.is_rpg_mode:
		return false
	
	var tile_size = dig_range
	var player_grid = (player.global_position / tile_size).floor()
	var target_grid = player_grid + Vector2(0, 1) # 向下一格
	var dig_position = (target_grid + Vector2(0.5, 0.5)) * tile_size
	
	return try_dig_nearby(dig_position)
