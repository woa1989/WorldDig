extends Button

@onready var AudioPlayer = $AudioStreamPlayer

@export var ClickSound:Resource = preload("res://Scenes/ActiveButton/Audios/rollover1.wav")# 点击音效
@export var FlitInSound:Resource = preload("res://Scenes/ActiveButton/Audios/click3.wav")# 鼠标掠入音效
@export var FlitOutSound:Resource = preload("res://Scenes/ActiveButton/Audios/click5.wav")# 鼠标掠出音效

var tween:Tween

func _ready() -> void:
	#priot_offset = size/2
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_button_pressed)
	pass
	

func _on_mouse_entered() -> void:
	# 检查节点是否在场景树中再播放音频
	if is_inside_tree() and AudioPlayer:
		AudioPlayer.stream = FlitInSound
		AudioPlayer.play()
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, ^"scale", Vector2(1.1, 1.1), 0.2)
	pass

func  _on_mouse_exited() -> void:
	# 检查节点是否在场景树中再播放音频
	if is_inside_tree() and AudioPlayer:
		AudioPlayer.stream = FlitOutSound
		AudioPlayer.play()
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(self, ^"scale", Vector2(1, 1), 0.1)
	pass
	
func _on_button_pressed():
	# 检查节点是否在场景树中再播放音频
	if is_inside_tree() and AudioPlayer:
		AudioPlayer.stream = ClickSound
		AudioPlayer.play()
	print("Button pressed")
	pass
