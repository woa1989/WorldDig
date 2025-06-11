// 简化版本的着色器，用于故障排除
shader_type light;

// 基础参数
uniform int light_count: hint_range(1, 8) = 4;
uniform bool apply_distance_fade = true;
uniform float light_radius: hint_range(50.0, 1000.0) = 300.0;

// 阴影参数（简化）
uniform bool shadows = false; // 暂时禁用阴影以测试基本功能
uniform float ambient_amount: hint_range(0.0, 1.0) = 0.3;

void light() {
    // 计算光源方向和距离
    vec2 light_vec = LIGHT_POSITION - FRAGCOORD.xy;
    float light_distance = length(light_vec);
    
    // 距离衰减
    float attenuation = 1.0;
    if (apply_distance_fade) {
        attenuation = 1.0 - smoothstep(0.0, light_radius, light_distance);
    }
    
    // 简单的漫反射光照
    float ndotl = 1.0;
    
    // 最终光照计算（简化版）
    vec3 diffuse = LIGHT_COLOR.rgb * ndotl * attenuation;
    vec3 ambient = LIGHT_COLOR.rgb * ambient_amount / float(light_count);
    
    // 输出最终颜色
    LIGHT = vec4(diffuse + ambient, 1.0);
}
