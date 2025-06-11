// 基于 godot-better-lighting-2d 项目的改进光照着色器
// 参考: https://github.com/Oman395/godot-better-lighting-2d
shader_type canvas_item;

// 光源数量
uniform int light_count : hint_range(1, 32) = 4;

// 基础光照参数
uniform float light_falloff : hint_range(0.1, 10.0) = 1.0;
uniform bool apply_distance_fade = true;
uniform float object_height : hint_range(0.0, 100.0) = 1.0;

// 阴影参数
uniform bool shadows = true;
uniform bool soft_shadows = true;
uniform float light_radius : hint_range(50.0, 1000.0) = 300.0;
uniform int shadow_march_count : hint_range(1, 64) = 16;
uniform float shadow_march_min_step : hint_range(0.01, 1.0) = 0.1;
uniform float shadow_march_step_scale : hint_range(0.1, 2.0) = 1.0;

// 环境光参数
uniform float ambient_amount : hint_range(0.0, 1.0) = 0.3;
uniform bool use_directional_light_as_ambient = false;

// 环境遮蔽参数
uniform bool ambient_occlusion = true;
uniform int ao_step_count : hint_range(1, 16) = 8;
uniform float ao_step_size : hint_range(0.1, 5.0) = 1.0;
uniform float ao_influence : hint_range(0.0, 1.0) = 0.5;

varying mat4 inv_canvas_matrix;
varying mat4 canvas_matrix;
varying vec2 screen_pix_size;
varying vec2 world_pos;
varying vec2 screen_offset;
varying vec2 screen_scale;
varying float ao;

// Beckmann分布函数用于镜面反射
float kSpec(vec3 N, vec3 H, float m) {
    float alpha = acos(dot(N, H));
    float mSquared = m * m;
    return (exp(-pow(tan(alpha) / mSquared, 2.0)) / (PI * mSquared * pow(cos(alpha), 4.0)));
}

void vertex() {
    inv_canvas_matrix = inverse(CANVAS_MATRIX);
    canvas_matrix = CANVAS_MATRIX;
    world_pos = VERTEX;
    
    // 计算屏幕缩放
    vec2 minP = (vec4(vec2(0), 0, 1) * inverse(CANVAS_MATRIX)).xy;
    vec2 maxP = (vec4(100, 100, 0, 1) * inverse(CANVAS_MATRIX)).xy;
    screen_scale = (maxP - minP) / 100.0;
}

void fragment() {
    screen_pix_size = SCREEN_PIXEL_SIZE;
    vec2 world_pos_without_offset = (vec4(VERTEX, 0, 1) * inv_canvas_matrix).xy;
    screen_offset = world_pos_without_offset - world_pos;
    
    ao = 1.0;
    if (ambient_occlusion) {
        // 简化的环境遮蔽计算
        vec2 marchPos = FRAGCOORD.xy;
        vec2 norm = vec2(0.0, 1.0); // 简化的法线
        float res = 0.0;
        vec2 rp;
        
        for (int i = 1; i < ao_step_count; i++) {
            rp = marchPos + ao_step_size * float(i) * norm * screen_pix_size;
            res += (1.0 / pow(2.0, float(i))) * (ao_step_size * float(i) - 0.5);
        }
        
        if (res >= 0.0) {
            ao = 1.0 - ao_influence * clamp(1.0 - ao_step_size / res, 0.0, 1.0);
        }
    }
}

vec2 UVtoWorld(vec2 uv) {
    return (vec4((uv) / screen_pix_size, 0, 1) * inv_canvas_matrix).xy - screen_offset;
}

vec2 worldToUV(vec2 coord) {
    return (vec4((coord + screen_offset) * screen_pix_size, 0, 1) * canvas_matrix).xy;
}

void light() {
    // 计算世界空间缩放
    vec2 worldspaceScaleCalcA = UVtoWorld(vec2(0));
    vec2 worldspaceScaleCalcB = UVtoWorld((1.0 / screen_scale) * screen_pix_size);
    float worldspaceDistanceScale = distance(vec2(0), vec2(screen_scale)) / distance(worldspaceScaleCalcA, worldspaceScaleCalcB);
    
    // 软阴影计算
    vec2 marchPos = world_pos;
    vec2 lightPos = UVtoWorld(LIGHT_POSITION.xy * screen_pix_size);
    vec2 toLight = normalize(lightPos - marchPos);
    
    vec2 screenPos = LIGHT_VERTEX.xy;
    vec2 lightPosScreen = LIGHT_POSITION.xy;
    vec2 toLightScreen = normalize(lightPosScreen - screenPos);
    float distToLight = distance(vec2(0), (lightPos - marchPos) * screen_scale);
    
    float d, t = 0.0;
    float obs = 1.0;
    
    // 简化的阴影计算
    if (shadows && !LIGHT_IS_DIRECTIONAL) {
        obs = 0.0;
        for (int i = 0; i < shadow_march_count; i++) {
            // 简化的距离场计算
            d = max(0.1, distToLight - t) * worldspaceDistanceScale;
            
            if (!soft_shadows && d <= 0.0001) {
                obs = 1.0;
                break;
            }
            
            if (soft_shadows) {
                obs = max(0.5 - length(1.0 / screen_scale) * d * distToLight / (2.0 * light_radius * t), obs);
            }
            
            if (obs > 0.99) break;
            
            d = max(d * shadow_march_step_scale, screen_scale.x * shadow_march_min_step * light_radius * t / distToLight);
            t += d;
            
            if (t >= distToLight) break;
            
            marchPos += d * toLight;
            screenPos += (d / worldspaceDistanceScale) * toLightScreen / screen_scale;
        }
        obs = 1.0 - clamp(obs, 0.0, 1.0);
    }
    
    // 改进的光照计算，使用累加而不是覆盖
    if (!LIGHT_IS_DIRECTIONAL) {
        // 计算世界距离
        vec2 worldPos = UVtoWorld(SCREEN_UV);
        vec3 worldPosLight = vec3(UVtoWorld(LIGHT_POSITION.xy * screen_pix_size), LIGHT_POSITION.z * screen_scale.x);
        vec3 worldDelta = worldPosLight - vec3(worldPos, object_height);
        float worldDist = distance(vec3(0), worldDelta);
        
        // PBR光照
        float roughness = clamp(SPECULAR_SHININESS.r, 0.1, 1.0);
        float specular = clamp(1.0 - SPECULAR_SHININESS.g, 0.0, 1.0);
        float metallic = clamp(SPECULAR_SHININESS.b, 0.0, 1.0);
        
        // 改进的距离衰减
        float distance_fade = 1.0 / (1.0 + pow(worldDist / light_falloff, 2.0));
        
        // 光照强度
        float intensity = LIGHT_ENERGY * distance_fade * obs;
        
        // 漫反射
        float ndotl = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
        vec4 diffuse = COLOR * LIGHT_COLOR * intensity * ndotl * roughness;
        
        // 镜面反射
        vec3 halfVector = normalize(LIGHT_DIRECTION + vec3(0, 0, 1));
        float spec = max(kSpec(NORMAL, halfVector, specular), 0.0);
        vec4 specularColor = mix(vec4(1), COLOR, metallic);
        vec4 specularContrib = specularColor * LIGHT_COLOR * intensity * spec;
        
        if (apply_distance_fade) {
            diffuse *= distance_fade;
            specularContrib *= distance_fade;
        }
        
        // 使用加法混合来融合多个光源
        LIGHT += diffuse + specularContrib;
    } else {
        // 方向光作为环境光
        LIGHT += COLOR * LIGHT_COLOR * ambient_amount * ao / float(light_count);
    }
    
    LIGHT.a = 1.0;
}
