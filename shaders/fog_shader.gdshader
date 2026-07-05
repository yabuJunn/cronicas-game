// Fog Shader Animado con Olas y Profundidad Orgánica

shader_type fog;

uniform float density : hint_range(0, 1, 0.0001) = 1.0;
uniform vec4 albedo : source_color = vec4(1.0);
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

// NUEVAS variables para la Profundidad Orgánica (Curvas aleatorias)
uniform float organic_amplitude : hint_range(0.0, 10.0) = 1.5; // Qué tan altas son las diferencias de profundidad
uniform float organic_scale = 0.05; // Tamaño de las curvas (valores más bajos = curvas más grandes y suaves)
uniform float organic_speed = 0.2; // Qué tan rápido mutan las curvas aleatorias

uniform sampler3D density_texture: hint_default_white;

void fog() {
    // --- 0. Profundidad Orgánica y Olas ---
    
    // 0.1. Generamos un mapa de altura orgánico leyendo la textura en los ejes X y Z del mundo
    // Multiplicamos el TIEMPO por la velocidad para que estas "colinas" muten lentamente
    vec3 organic_uv = vec3(WORLD_POSITION.x * organic_scale, TIME * organic_speed, WORLD_POSITION.z * organic_scale);
    
    // Le restamos 0.5 y multiplicamos por 2 para que el ruido vaya de -1 a 1 (valles hacia abajo, colinas hacia arriba)
    float organic_noise = (texture(density_texture, organic_uv).r - 0.5) * 2.0;
    
    // 0.2. Distorsión adicional para retorcer las olas direccionales
    vec3 distortion_uv = (UVW * 0.2) + (movement_speed * TIME * 0.5);
    float wave_distortion = (texture(density_texture, distortion_uv).r - 0.5) * 2.0;
    
    // Sumamos la distorsión base Y nuestro nuevo ruido orgánico a la posición de las olas
    // Esto hace que las olas no viajen en línea recta, sino que sigan la forma del ruido
    vec2 pos_xz = vec2(WORLD_POSITION.x, WORLD_POSITION.z) + (wave_distortion * 1.5) + (organic_noise * 3.0);
    
    // 0.3. Olas Matemáticas (A y B) distorsionadas
    float wave_a = sin(dot(pos_xz, wave_direction * wave_frequency) + (TIME * wave_speed));
    vec2 cross_direction = vec2(-wave_direction.y, wave_direction.x); 
    float wave_b = sin(dot(pos_xz, cross_direction * (wave_frequency * 1.3)) + (TIME * wave_speed * 0.7));
    float directional_waves = wave_amplitude * (wave_a + wave_b) * 0.5;

    // 0.4. ¡La mezcla final de movimiento!
    // Sumamos las olas direccionales (detalle) con el ruido orgánico (macro estructura)
    float combined_wave = directional_waves + (organic_noise * organic_amplitude);

    // --- Aplicamos la onda a la altura virtual (Y) ---
    float waved_y = WORLD_POSITION.y + combined_wave;
    
    // 1. Calculamos la densidad base usando nuestra nueva altura ondulada
    DENSITY = density * clamp(exp2(-height_falloff * (waved_y - OBJECT_POSITION.y)), 0.0, 1.0);
    
    // Hacemos que la textura interna también se mueva con todo este caos
    vec3 waved_uvw = UVW;
    waved_uvw.y += combined_wave * 0.05; 
    
    // 2. Ruido principal
    vec3 animated_uvw = (waved_uvw * noise_scale) + (movement_speed * TIME);
    float main_noise = texture(density_texture, animated_uvw).r;
    DENSITY *= main_noise;
    
    // 3. Ruido secundario (bordes)
    vec3 edge_uvw = (waved_uvw * noise_scale * edge_detail_scale) + (movement_speed * edge_speed_multiplier * TIME);
    float edge_noise = texture(density_texture, edge_uvw).r;
    
    // 4. Distorsionamos el SDF sumando el ruido irregular Y nuestra mega-ola orgánica combinada
    float distorted_sdf = SDF + ((edge_noise - 0.5) * edge_distortion_strength) + combined_wave;
    
    // 5. Suavizamos los bordes
    float fade = clamp(-2.0 * distorted_sdf / min(min(SIZE.x, SIZE.y), SIZE.z), 0.0, 1.0);
    DENSITY *= pow(fade, edge_fade);
    
    // 6. Aplicamos los colores
    ALBEDO = albedo.rgb;
    EMISSION = emission.rgb;
}