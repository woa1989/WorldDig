extends CanvasLayer

# 改进版加载场景
# 支持进度条、提示文本、错误处理、音效等功能

@onready var animation_player = $AnimationPlayer
@onready var progress_bar = $UI/VBoxContainer/ProgressBar
@onready var loading_label = $UI/VBoxContainer/LoadingLabel
@onready var tip_label = $UI/VBoxContainer/TipLabel
@onready var audio_player = $AudioPlayer

# 场景管理
var current_scene = null

# 加载状态
var is_loading = false
var loading_progress = 0.0

# 配置选项
var show_tips = true
var play_sound_effects = true
var fade_duration = 0.3
var min_loading_time = 1.0 # 最小加载时间，避免闪烁

# 加载提示文本
var loading_tips = [
	"探索地下世界的奥秘...",
	"收集珍贵的矿物资源...",
	"升级你的装备...",
	"小心地下的危险生物...",
	"火把是你的好朋友...",
	"深度越深，宝藏越丰富...",
	"记得定期返回城镇补给...",
	"挖掘需要耐心和技巧...",
	"每个矿物都有其价值...",
	"准备好迎接冒险吧！"
]

# 信号
signal loading_started(scene_path: String)
signal loading_progress_updated(progress: float)
signal loading_completed(scene_path: String)
signal loading_failed(scene_path: String, error: String)

func _ready() -> void:
	# 初始化UI状态
	$ColorRect.modulate.a = 0
	if progress_bar:
		progress_bar.value = 0
		progress_bar.visible = false
	if loading_label:
		loading_label.text = ""
		loading_label.visible = false
	if tip_label:
		tip_label.text = ""
		tip_label.visible = false
	
	# 获取当前场景
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	print("[LoadingScene] 已初始化")

func switch_scene(res_path: String):
	"""切换场景的主入口函数"""
	if is_loading:
		print("[LoadingScene] 警告：正在加载中，忽略新的切换请求")
		return
	
	print("[LoadingScene] 开始切换场景到: ", res_path)
	call_deferred("_deferred_switch_scene", res_path)

func _deferred_switch_scene(res_path: String):
	"""延迟执行的场景切换"""
	if not ResourceLoader.exists(res_path):
		var error_msg = "场景文件不存在: " + res_path
		print("[LoadingScene] 错误: ", error_msg)
		loading_failed.emit(res_path, error_msg)
		return
	
	is_loading = true
	loading_progress = 0.0
	loading_started.emit(res_path)
	
	# 开始淡入动画
	await _start_fade_in()
	
	# 显示加载UI
	_show_loading_ui()
	
	# 显示随机提示
	if show_tips:
		_show_random_tip()
	
	# 记录加载开始时间
	var load_start_time = Time.get_time_dict_from_system()
	
	# 执行场景切换
	var success = await _load_and_switch_scene(res_path)
	
	# 确保最小加载时间
	await _ensure_min_loading_time(load_start_time)
	
	if success:
		loading_completed.emit(res_path)
		print("[LoadingScene] 场景切换成功: ", res_path)
	
	# 隐藏加载UI
	_hide_loading_ui()
	
	# 开始淡出动画
	await _start_fade_out()
	
	is_loading = false

func _start_fade_in() -> void:
	"""开始淡入动画"""
	if play_sound_effects and audio_player:
		# 这里可以播放淡入音效
		pass
	
	animation_player.play(&"start")
	await animation_player.animation_finished

func _start_fade_out() -> void:
	"""开始淡出动画"""
	if play_sound_effects and audio_player:
		# 这里可以播放淡出音效
		pass
	
	animation_player.play_backwards(&"start")
	await animation_player.animation_finished

func _show_loading_ui():
	"""显示加载UI元素"""
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
	
	if loading_label:
		loading_label.visible = true
		loading_label.text = "加载中..."
	
	if tip_label:
		tip_label.visible = true

func _hide_loading_ui():
	"""隐藏加载UI元素"""
	if progress_bar:
		progress_bar.visible = false
	
	if loading_label:
		loading_label.visible = false
	
	if tip_label:
		tip_label.visible = false

func _show_random_tip():
	"""显示随机提示"""
	if tip_label and loading_tips.size() > 0:
		var random_tip = loading_tips[randi() % loading_tips.size()]
		tip_label.text = random_tip

func _load_and_switch_scene(res_path: String) -> bool:
	# 加载并切换场景
	# 使用ResourceLoader进行异步加载
	var loader = ResourceLoader.load_threaded_request(res_path)
	if loader != OK:
		var error_msg = "无法开始加载场景: " + res_path
		print("[LoadingScene] 错误: ", error_msg)
		loading_failed.emit(res_path, error_msg)
		return false
	
	# 监控加载进度
	while true:
		var status = ResourceLoader.load_threaded_get_status(res_path)
		var progress = []
		ResourceLoader.load_threaded_get_status(res_path, progress)
		
		# 更新进度条
		var progress_value = progress[0] if progress.size() > 0 else 0.0
		_update_progress(progress_value)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var error_msg = "场景加载失败: " + res_path
			print("[LoadingScene] 错误: ", error_msg)
			loading_failed.emit(res_path, error_msg)
			return false
		
		await get_tree().process_frame
	
	# 获取加载的场景资源
	var scene_resource = ResourceLoader.load_threaded_get(res_path)
	if not scene_resource:
		var error_msg = "无法获取场景资源: " + res_path
		print("[LoadingScene] 错误: ", error_msg)
		loading_failed.emit(res_path, error_msg)
		return false
	
	# 实例化新场景
	var new_scene = scene_resource.instantiate()
	if not new_scene:
		var error_msg = "无法实例化场景: " + res_path
		print("[LoadingScene] 错误: ", error_msg)
		loading_failed.emit(res_path, error_msg)
		return false
	
	# 更新进度到100%
	_update_progress(1.0)
	
	# 切换场景
	if current_scene and is_instance_valid(current_scene):
		current_scene.queue_free()
	
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	current_scene = new_scene
	
	return true

func _update_progress(progress: float):
	"""更新加载进度"""
	loading_progress = progress
	loading_progress_updated.emit(progress)
	
	if progress_bar:
		progress_bar.value = progress * 100
	
	if loading_label:
		loading_label.text = "加载中... %d%%" % int(progress * 100)

func _ensure_min_loading_time(start_time: Dictionary):
	"""确保最小加载时间，避免加载过快造成的闪烁"""
	var current_time = Time.get_time_dict_from_system()
	var elapsed_seconds = (current_time.hour * 3600 + current_time.minute * 60 + current_time.second) - \
						 (start_time.hour * 3600 + start_time.minute * 60 + start_time.second)
	
	if elapsed_seconds < min_loading_time:
		var wait_time = min_loading_time - elapsed_seconds
		await get_tree().create_timer(wait_time).timeout

# 静态方法，方便其他脚本调用
static func switch_to_scene(scene_path: String):
	"""静态方法：切换到指定场景"""
	var loading_scene = preload("res://Scenes/LoadingScene/LoadingScene.tscn").instantiate()
	var tree = Engine.get_singleton("SceneTree") as SceneTree
	if tree:
		tree.root.add_child(loading_scene)
		loading_scene.switch_scene(scene_path)

# 配置方法
func set_fade_duration(duration: float):
	"""设置淡入淡出时长"""
	fade_duration = duration

func set_min_loading_time(time: float):
	"""设置最小加载时间"""
	min_loading_time = time

func enable_tips(enabled: bool):
	"""启用/禁用提示文本"""
	show_tips = enabled

func enable_sound_effects(enabled: bool):
	"""启用/禁用音效"""
	play_sound_effects = enabled

func add_loading_tip(tip: String):
	"""添加自定义加载提示"""
	loading_tips.append(tip)

func clear_loading_tips():
	"""清空加载提示"""
	loading_tips.clear()
