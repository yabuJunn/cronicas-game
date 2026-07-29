// Fog Shader Animado con Olas, Profundidad Orgánica y Color Secundario

shader_type fog;

uniform float density : hint_range(0, 1, 0.0001) = 1.0;
uniform vec4 albedo : source_color = vec4(1.0);
// NUEVAS variables para el Color Secundario
uniform vec4 albedo_secundario : source_color = vec4(0.2, 0.5, 0.8, 1.0);
uniform float color_mix_scale : hint_range(0.0, 5.0) = 1.0; // Controla qué tanto influyen las olas en el cambio de color
uniform float color_mix_contrast : hint_range(0.1, 10.0) = 1.5; // Contraste/Nitidez de la transición entre colores
uniform float color_mix_offset : hint_range(-1.0, 1.0) = 0.0; // Desplazamiento del punto medio de mezcla

uniform vec4 emission : source_color = vec4(0, 0, 0, 1);
uniform float height_falloff = 0.0;
uniform float edge_fade = 0.1;

// Variables para el cuerpo principal
uniform vec3 movement_speed = vec3(0.05, 0.0, 0.05); 
uniform float noise_scale = 1.0; 

// Variables para romper los bordes
uniform float edge_distortion_strength : hint_range(0.0, 10.0) = 2.0; 
uniform vec3 edge_speed_multiplier = vec3(2.0, 3.0, 2.0); 
uniform float edge_detail_scale = 3.0; 

// Variables para las olas direccionales base
uniform float wave_amplitude = 0.25;
uniform float wave_speed = 1.5; 
uniform vec2 wave_direction = vec2(1.0, 0.5); 
uniform float wave_frequency = 1.5;

// Variables para la Profundidad Orgánica (Curvas aleatorias)
uniform float organic_amplitude : hint_range(0.0, 10.0) = 1.5;
uniform float organic_scale = 0.05;
uniform float organic_speed = 0.2;

uniform sampler3D density_texture: hint_default_white;

void fog() {
    // --- 0. Profundidad Orgánica y Olas ---
    
    // 0.1. Mapa de altura orgánico
    vec3 organic_uv = vec3(WORLD_POSITION.x * organic_scale, TIME * organic_speed, WORLD_POSITION.z * organic_scale);
    float organic_noise = (texture(density_texture, organic_uv).r - 0.5) * 2.0;
    
    // 0.2. Distorsión adicional
    vec3 distortion_uv = (UVW * 0.2) + (movement_speed * TIME * 0.5);
    float wave_distortion = (texture(density_texture, distortion_uv).r - 0.5) * 2.0;
    
    vec2 pos_xz = vec2(WORLD_POSITION.x, WORLD_POSITION.z) + (wave_distortion * 1.5) + (organic_noise * 3.0);
    
    // 0.3. Olas Matemáticas (A y B)
    float wave_a = sin(dot(pos_xz, wave_direction * wave_frequency) + (TIME * wave_speed));
    vec2 cross_direction = vec2(-wave_direction.y, wave_direction.x); 
    float wave_b = sin(dot(pos_xz, cross_direction * (wave_frequency * 1.3)) + (TIME * wave_speed * 0.7));
    float directional_waves = wave_amplitude * (wave_a + wave_b) * 0.5;

    // 0.4. Mezcla final de movimiento
    float combined_wave = directional_waves + (organic_noise * organic_amplitude);

    // --- Aplicamos la onda a la altura virtual (Y) ---
    float waved_y = WORLD_POSITION.y + combined_wave;
    
    // 1. Calculamos la densidad base
    DENSITY = density * clamp(exp2(-height_falloff * (waved_y - OBJECT_POSITION.y)), 0.0, 1.0);
    
    vec3 waved_uvw = UVW;
    waved_uvw.y += combined_wave * 0.05; 
    
    // 2. Ruido principal
    vec3 animated_uvw = (waved_uvw * noise_scale) + (movement_speed * TIME);
    float main_noise = texture(density_texture, animated_uvw).r;
    DENSITY *= main_noise;
    
    // 3. Ruido secundario (bordes)
    vec3 edge_uvw = (waved_uvw * noise_scale * edge_detail_scale) + (movement_speed * edge_speed_multiplier * TIME);
    float edge_noise = texture(density_texture, edge_uvw).r;
    
    // 4. Distorsión del SDF
    float distorted_sdf = SDF + ((edge_noise - 0.5) * edge_distortion_strength) + combined_wave;
    
    // 5. Suavizado de bordes
    float fade = clamp(-2.0 * distorted_sdf / min(min(SIZE.x, SIZE.y), SIZE.z), 0.0, 1.0);
    DENSITY *= pow(fade, edge_fade);
    
    // --- 6. Aplicación Dinámica de Colores ---
    // Mezclamos el ruido volumétrico interno con la altura de las olas
    float color_blend = main_noise + (combined_wave * 0.1 * color_mix_scale);
    
    // Ajustamos el contraste y punto medio del gradiente entre ambos colores
    color_blend = clamp((color_blend - 0.5 + color_mix_offset) * color_mix_contrast + 0.5, 0.0, 1.0);
    
    // Interpolamos entre el Albedo principal y el Secundario
    ALBEDO = mix(albedo.rgb, albedo_secundario.rgb, color_blend);
    EMISSION = emission.rgb;
}