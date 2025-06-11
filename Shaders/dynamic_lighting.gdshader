shader_type canvas_item;

uniform float light_radius : hint_range(50.0, 500.0) = 200.0;
uniform vec4 light_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float light_intensity : hint_range(0.1, 5.0) = 2.0;
uniform vec2 light_position;
uniform float falloff : hint_range(0.5, 3.0) = 1.5;
uniform float ambient_light : hint_range(0.0, 1.0) = 0.1;

// 多光源支持
uniform int max_lights = 32;
uniform vec2 light_positions[32];
uniform float light_radii[32];
uniform vec4 light_colors[32];
uniform float light_intensities[32];
uniform int active_light_count = 0;

varying vec2 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float calculate_light_attenuation(vec2 light_pos, float radius, float intensity, vec2 world_pos) {
    vec2 distance_vec = world_pos - light_pos;
    float distance = length(distance_vec);
    
    if (distance > radius) {
        return 0.0;
    }
    
    float normalized_distance = distance / radius;
    float attenuation = 1.0 - pow(normalized_distance, falloff);
    return attenuation * intensity;
}

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);
    
    // 测试：显示原始颜色加上红色tint来验证着色器生效
    if (active_light_count > 0) {
        COLOR = vec4(original_color.r + 0.2, original_color.g, original_color.b, original_color.a);
    } else {
        COLOR = original_color;
    }
}