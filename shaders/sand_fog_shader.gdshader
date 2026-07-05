shader_type fog;

uniform sampler2D noise_tex : repeat_enable;
uniform float noise_scale : hint_range(0.0, 1.0, 0.0001) = 0.05; // Ajustado por defecto para coordenadas de mundo
uniform float flatness : hint_range(0.0, 50.0, 0.1) = 4.0;
uniform float density : hint_range(0.0, 6.0, 0.0001) = 1.0;
uniform sampler2D grad_tex;
uniform vec3 emision : source_color;
uniform float fog_speed : hint_range(-5.0, 5.0, 0.001) = 1.0;

// NUEVAS variables para controlar el polvillo y los bordes
uniform float dust_particles_sharpness : hint_range(1.0, 10.0) = 3.0; // Controla qué tan separados/definidos están los granos de polvo
uniform float edge_softness : hint_range(0.1, 5.0) = 2.5; // Valores más altos = bordes MUCHO más invisibles y desvanecidos

void fog() {
    // 1. Movimiento del viento (El polvillo se mueve más rápido arriba que abajo)
    float wind_gradient = mix(1.0, 1.8, UVW.y); 
    vec2 move_uv = vec2(0.15, 0.08) * TIME * fog_speed * wind_gradient;
    
    // 2. Lectura de ruido doble para romper patrones direccionales
    float detail_noise = texture(noise_tex, WORLD_POSITION.xz * noise_scale + move_uv * 0.4).r;
    float noise = texture(noise_tex, WORLD_POSITION.xz * noise_scale + move_uv + detail_noise * 0.2).r;
    
    // 3. Convertir la niebla suave en granos de polvillo dispersos
    // Usamos pow() sobre el ruido para aislar los puntos más brillantes (granos de polvo)
    float dust_granularity = pow(noise, dust_particles_sharpness);
    
    // 4. Dispersión vertical (se desvanece y se separa hacia el techo)
    DENSITY = mix(dust_granularity, 0.0, UVW.y * flatness);
    
    // 5. Desvanecimiento de bordes EXTREMO (SDF mejorado)
    // Usamos edge_softness como exponente alto. Esto hace que la caja desaparezca por completo
    float sdf_fade = clamp(-2.0 * SDF / min(min(SIZE.x, SIZE.y), SIZE.z), 0.0, 1.0);
    DENSITY *= pow(sdf_fade, edge_softness) * density;
    
    // 6. Color y emisión
    vec3 col = texture(grad_tex, vec2(DENSITY, 0.5)).rgb;
    ALBEDO = vec3(col);
    EMISSION = emision;
}