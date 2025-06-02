# Scenes/Torch/Torch.gd
extends Node2D

@onready var torch_light: Light2D
@onready var visual_placeholder: ColorRect

func _ready():
    # Create and configure Light2D
    torch_light = Light2D.new()
    torch_light.name = "TorchLight"
    torch_light.color = Color(1.0, 0.7, 0.3) # Yellow-orange
    torch_light.energy = 0.8
    torch_light.range = 180.0 # Moderate range
    torch_light.texture_scale = 0.35 # Soften default texture
    torch_light.shadow_enabled = true
    add_child(torch_light)

    # Create and configure ColorRect for visual representation
    visual_placeholder = ColorRect.new()
    visual_placeholder.name = "VisualPlaceholder"
    visual_placeholder.size = Vector2(10, 20)
    visual_placeholder.color = Color(0.6, 0.3, 0.1) # Brownish/dark orange
    # Position it so the light appears to emanate from its top
    # Assuming (0,0) of Node2D is the base of the torch, light is centered above it.
    # ColorRect itself is centered horizontally, with its bottom at Node2D's origin.
    visual_placeholder.position = Vector2(-visual_placeholder.size.x / 2, -visual_placeholder.size.y)
    add_child(visual_placeholder)
