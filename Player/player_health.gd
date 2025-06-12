class_name PlayerHealth
extends Node

# 血量系统管理
signal health_changed(new_health: int, max_health: int)
signal died

var max_health = 3
var current_health = 3
var health_bar_show_timer = 0.0
var health_bar_show_duration = 3.0
var is_invulnerable = false
var invulnerability_timer = 0
var invulnerability_duration = 600 # 毫秒
var skip_hurt_animation = false # 在某些情况下跳过受伤动画（如碰撞敌人时）

# 闪烁相关变量
var blink_count = 0
var max_blink_count = 4 # 闪烁2次需要4个状态切换（显示->隐藏->显示->隐藏）
var blink_interval = 100 # 毫秒

@onready var health_bar = get_parent().get_node("HealthBar")
var animated_sprite: AnimatedSprite2D

func _ready():
	# 确保在player完全初始化后获取animated_sprite引用
	animated_sprite = get_parent().get_node("AnimatedSprite2D")
	print("[DEBUG] PlayerHealth获取动画精灵引用: ", animated_sprite)
	update_health_bar()

func _process(delta):
	# 处理无敌时间
	if is_invulnerable:
		invulnerability_timer += delta * 1000
		if invulnerability_timer >= invulnerability_duration:
			end_invulnerability()
		else:
			# 闪烁效果
			update_blink_effect()
	
	# 处理血条显示逻辑
	handle_health_bar_display()

func take_damage(damage: int) -> bool:
	"""接受伤害，返回是否成功受伤"""
	if is_invulnerable:
		print("[DEBUG] 💫 无敌状态，免疫伤害")
		return false
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# 发送血量变化信号
	health_changed.emit(current_health, max_health)
	
	# 更新血条并显示
	update_health_bar()
	show_health_bar()
	
	# 设置无敌状态
	start_invulnerability()
	
	# 不播放受伤动画，只使用闪烁效果
	print("[DEBUG] 😵 玩家受伤，使用闪烁效果而非动画")
	
	# 检查是否死亡
	if current_health <= 0:
		die()
		return true
	
	return true

func heal(amount: int):
	"""治疗"""
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	update_health_bar()
	show_health_bar()

func start_invulnerability():
	"""开始无敌状态"""
	is_invulnerable = true
	invulnerability_timer = 0
	blink_count = 0
	print("[DEBUG] 💫 开始无敌状态和闪烁效果")

func end_invulnerability():
	"""结束无敌状态"""
	is_invulnerable = false
	invulnerability_timer = 0
	set_shader_blink_intensity(0.0)
	print("[DEBUG] 💫 无敌状态结束")

func update_blink_effect():
	"""更新闪烁效果 - 只闪烁两次"""
	var current_blink_phase = int(invulnerability_timer / blink_interval)
	
	# 只在前4个阶段进行闪烁（2次完整的显示/隐藏循环）
	if current_blink_phase < max_blink_count:
		if current_blink_phase % 2 == 0:
			set_shader_blink_intensity(0.8) # 显示（闪烁）
		else:
			set_shader_blink_intensity(0.0) # 正常显示
	else:
		# 闪烁完成后保持正常显示
		set_shader_blink_intensity(0.0)

func set_shader_blink_intensity(intensity: float):
	"""设置闪烁强度"""
	if animated_sprite and animated_sprite.material:
		animated_sprite.material.set_shader_parameter("blink_intensity", intensity)

func update_health_bar():
	"""更新血条显示"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		# 设置血条颜色
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color.RED
		health_bar.add_theme_stylebox_override("fill", style_box)

func show_health_bar():
	"""显示血条"""
	health_bar_show_timer = 0.0
	if health_bar:
		health_bar.visible = true

func handle_health_bar_display():
	"""处理血条显示逻辑"""
	if health_bar:
		# 血量不足时持续显示
		if current_health < max_health:
			health_bar.visible = true
		else:
			# 满血时显示一段时间后隐藏
			health_bar_show_timer += get_process_delta_time()
			if health_bar_show_timer >= health_bar_show_duration:
				health_bar.visible = false

func play_hurt_animation():
	"""播放受伤动画"""
	# 如果设置了跳过动画标志，则不播放受伤动画
	if skip_hurt_animation:
		print("[DEBUG] 🚫 跳过受伤动画（skip_hurt_animation=true）")
		skip_hurt_animation = false # 重置标志
		return
		
	var player = get_parent()
	if player.has_method("play_anim"):
		print("[DEBUG] 😵 播放受伤动画")
		player.play_anim("Hurt")
		# 连接动画完成信号
		if animated_sprite and not animated_sprite.animation_finished.is_connected(_on_hurt_animation_finished):
			animated_sprite.animation_finished.connect(_on_hurt_animation_finished, CONNECT_ONE_SHOT)

func _on_hurt_animation_finished():
	"""受伤动画完成"""
	print("[DEBUG] 受伤动画播放完毕，恢复正常动画")
	var player = get_parent()
	# 让movement系统重新评估当前状态并设置正确的动画
	var player_movement = player.get_node_or_null("PlayerMovement")
	if player_movement and player_movement.has_method("update_animations"):
		# 延迟一帧让动画系统处理
		await get_tree().process_frame
		player_movement.update_animations()

func die():
	"""玩家死亡"""
	print("[DEBUG] 💀 玩家死亡")
	
	# 播放死亡动画
	var player = get_parent()
	if player.has_method("play_anim"):
		player.play_anim("Dying")
		
	# 发送死亡信号（注意：不要在player.gd的回调中再次播放死亡动画）
	died.emit()
	
	# 取消无敌状态以确保死亡动画显示正常
	is_invulnerable = false
	set_shader_blink_intensity(0.0)
