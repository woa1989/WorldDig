extends VBoxContainer

@onready var StartBtn: Button = $StartButton
@onready var QuitBtn: Button = $QuitButton

func _ready() -> void:
	StartBtn.pressed.connect(_on_start_btn_pressed)
	QuitBtn.pressed.connect(_on_quit_btn_pressed)

func _on_start_btn_pressed() -> void:
	# 使用改进版LoadingScene切换场景
	var loading_scene = preload("res://Scenes/LoadingScene/LoadingScene.tscn").instantiate()
	get_tree().root.add_child(loading_scene)
	
	# 可选：连接加载事件
	loading_scene.loading_completed.connect(_on_scene_loaded)
	loading_scene.loading_failed.connect(_on_scene_load_failed)
	
	# 开始切换到矿井场景
	loading_scene.switch_scene("res://Scenes/MineScene/MineScene.tscn")

func _on_quit_btn_pressed() -> void:
	get_tree().quit()

func _on_scene_loaded(scene_path: String):
	print("成功切换到场景: ", scene_path)

func _on_scene_load_failed(scene_path: String, error: String):
	print("场景切换失败: ", scene_path, " 错误: ", error)
	# 可以在这里显示错误提示
