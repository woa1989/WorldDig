class_name PlayerCollision
extends Node

# 玩家碰撞系统管理
# signal enemy_collision_detected(enemy)

# 后退参数
var knockback_force = 64.0 # 准确的64像素击退距离
var knockback_duration = 0.3
var is_being_knocked_back = false
var knockback_timer = 0.0

@onready var player: CharacterBody2D = get_parent()
@onready var enemy_detection_area = player.get_node("EnemyDetectionArea")

var player_health: PlayerHealth
var player_movement: PlayerMovement

func _ready():
	# 获取其他模块的引用
	player_health = player.get_node("PlayerHealth")
	player_movement = player.get_node("PlayerMovement")
	
	# 连接敌人检测信号
	if enemy_detection_area:
		enemy_detection_area.body_entered.connect(_on_enemy_entered)
		enemy_detection_area.body_exited.connect(_on_enemy_exited)

func _process(delta):
	# 处理后退计时器
	if is_being_knocked_back:
		knockback_timer += delta
		if knockback_timer >= knockback_duration:
			end_knockback()

func _on_enemy_entered(body):
	"""敌人进入检测区域"""
	print("[DEBUG] 玩家检测区域进入的物体: ", body.name, ", 类型: ", body.get_class())
	if body.get_script():
		print("[DEBUG] 物体脚本路径: ", body.get_script().get_path())
	
	if body.name == "Enemy" or (body.get_script() and body.get_script().get_path().ends_with("enemy.gd")):
		print("[DEBUG] 玩家检测到敌人，触发后退和闪烁")
		trigger_knockback(body)
		trigger_damage_effect()

func _on_enemy_exited(body):
	"""敌人离开检测区域"""
	print("[DEBUG] 玩家检测区域离开的物体: ", body.name, ", 类型: ", body.get_class())
	if body.name == "Enemy" or (body.get_script() and body.get_script().get_path().ends_with("enemy.gd")):
		print("[DEBUG] 敌人离开玩家检测区域")

func trigger_knockback(enemy):
	"""触发后退效果"""
	if is_being_knocked_back:
		return
	
	is_being_knocked_back = true
	knockback_timer = 0.0
	
	# 计算后退方向（远离敌人）
	var knockback_direction = (player.global_position - enemy.global_position).normalized()
	
	# 应用固定距离的后退速度
	if player_movement:
		# 转换为速度以在指定时间内移动固定距离
		# 基于公式: 距离 = 速度 * 时间
		var velocity_required = knockback_force / knockback_duration
		
		# 水平后退
		player.velocity.x = knockback_direction.x * velocity_required
		
		# 增加向上跳跃力，模拟跳跃效果
		player.velocity.y = -300.0
		
		# 直接播放Jump动画，使用player的play_anim方法
		print("[DEBUG] 击退时播放跳跃动画")
		player.play_anim("jump")
	
	print("[DEBUG] 触发后退，方向: ", knockback_direction, " 距离: ", knockback_force, " 像素")

func trigger_damage_effect():
	"""触发伤害效果（闪烁和无敌时间）"""
	if player_health:
		# 触发无敌时间和闪烁效果，但不实际减少血量
		player_health.start_invulnerability()
		player_health.show_health_bar()
		
		# 允许受伤动画播放，增强视觉反馈
		player_health.skip_hurt_animation = false
		
		print("[DEBUG] 触发伤害效果 - 无敌时间，闪烁效果，允许受伤动画")

func end_knockback():
	"""结束后退状态"""
	is_being_knocked_back = false
	knockback_timer = 0.0
	print("[DEBUG] 后退效果结束")
	
	# 更新动画状态，确保恢复正确动画
	if player and player_movement and player_movement.has_method("update_animations"):
		print("[DEBUG] 击退结束后强制更新动画")
		player_movement.update_animations()

func is_knockback_active() -> bool:
	"""检查是否正在后退"""
	return is_being_knocked_back
