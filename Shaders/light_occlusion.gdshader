shader_type canvas_item;

uniform sampler2D occlusion_map;
uniform vec2 occlusion_map_size = vec2(1024.0, 1024.0);
uniform vec2 world_offset = vec2(0.0, 0.0);
uniform float occlusion_strength : hint_range(0.0, 1.0) = 0.8;

varying vec2 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // 将世界坐标转换为遮挡贴图坐标
    vec2 occlusion_uv = (world_position + world_offset) / occlusion_map_size;
    occlusion_uv = clamp(occlusion_uv, vec2(0.0), vec2(1.0));
    
    // 采样遮挡贴图
    float occlusion = texture(occlusion_map, occlusion_uv).r;
    
    // 应用遮挡
    vec4 original_color = texture(TEXTURE, UV);
    float light_multiplier = 1.0 - (occlusion * occlusion_strength);
    
    COLOR = vec4(original_color.rgb * light_multiplier, original_color.a);
}