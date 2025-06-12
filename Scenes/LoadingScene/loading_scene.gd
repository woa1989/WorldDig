extends CanvasLayer

# 简化版LoadingScene - 专注于可靠的场景切换
# 解决挂起问题的版本

@onready var animation_player = $AnimationPlayer
@onready var progress_bar = $UI/VBoxContainer/ProgressBar
@onready var loading_label = $UI/VBoxContainer/LoadingLabel
@onready var tip_label = $UI/VBoxContainer/TipLabel

# 信号
signal loading_completed(scene_path: String)
signal loading_failed(scene_path: String, error: String)

# 状态
var is_loading = false

# 简化的提示文本
var loading_tips = [
	"加载中，请稍候...",
	"正在准备场景...",
	"即将完成...",
]

func _ready():
	print("[LoadingScene] 简化版初始化")

func switch_scene(scene_path: String):
	"""主要的场景切换方法"""
	if is_loading:
		print("[LoadingScene] 已在加载中，忽略重复请求")
		return
	
	print("[LoadingScene] 开始切换到: ", scene_path)
	is_loading = true
	
	# 异步执行加载
	_perform_loading(scene_path)

func _perform_loading(scene_path: String):
	"""执行实际的加载过程"""
	# 1. 显示加载界面
	_show_ui()
	
	# 2. 等待一帧确保UI显示
	await get_tree().process_frame
	
	# 3. 执行场景加载
	var success = await _load_scene(scene_path)
	
	# 4. 发送信号
	if success:
		loading_completed.emit(scene_path)
		print("[LoadingScene] 场景加载成功")
	else:
		loading_failed.emit(scene_path, "加载失败")
		print("[LoadingScene] 场景加载失败")
	
	# 5. 隐藏UI并清理
	_hide_ui()
	
	# 6. 等待一帧后清理自身
	await get_tree().process_frame
	print("[LoadingScene] 清理LoadingScene")
	queue_free()

func _show_ui():
	"""显示加载UI"""
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
	
	if loading_label:
		loading_label.visible = true
		loading_label.text = "加载中..."
	
	if tip_label:
		tip_label.visible = true
		var tip = loading_tips[randi() % loading_tips.size()]
		tip_label.text = tip

func _hide_ui():
	"""隐藏加载UI"""
	if progress_bar:
		progress_bar.visible = false
	
	if loading_label:
		loading_label.visible = false
	
	if tip_label:
		tip_label.visible = false

func _load_scene(scene_path: String) -> bool:
	"""加载场景的核心逻辑"""
	print("[LoadingScene] 开始加载: ", scene_path)
	
	# 检查文件是否存在
	if not ResourceLoader.exists(scene_path):
		print("[LoadingScene] 错误: 场景文件不存在")
		return false
	
	# 模拟加载进度
	for i in range(4):
		await get_tree().create_timer(0.2).timeout
		var progress = (i + 1) * 25
		if progress_bar:
			progress_bar.value = progress
		if loading_label:
			loading_label.text = "加载中... %d%%" % progress
		print("[LoadingScene] 加载进度: ", progress, "%")
	
	# 加载场景资源
	var scene_resource = load(scene_path)
	if not scene_resource:
		print("[LoadingScene] 错误: 无法加载场景资源")
		return false
	
	# 实例化场景
	var new_scene = scene_resource.instantiate()
	if not new_scene:
		print("[LoadingScene] 错误: 无法实例化场景")
		return false
	
	# 切换场景
	var current_scene = get_tree().current_scene
	if current_scene and is_instance_valid(current_scene):
		print("[LoadingScene] 移除当前场景: ", current_scene.name)
		current_scene.queue_free()
	
	print("[LoadingScene] 添加新场景: ", new_scene.name)
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	
	return true
