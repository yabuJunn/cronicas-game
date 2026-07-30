// Shader de Niebla Pintoresca Multicolor (Mezcla Orgánica Balanceada de 4 Colores)
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

group_uniforms Colores_Pintura;
uniform vec4 color_base : source_color = vec4(0.12, 0.18, 0.28, 1.0);
uniform vec4 color_retazo_1 : source_color = vec4(0.85, 0.45, 0.65, 1.0); // Pincelada A
uniform vec4 color_retazo_2 : source_color = vec4(0.25, 0.75, 0.85, 1.0); // Pincelada B
uniform vec4 color_brillo : source_color = vec4(0.95, 0.95, 1.00, 1.0);   // Crestas/Campos de Energía

group_uniforms Emision_Energia;
// Controla la luz emitida por los colores base y los retazos
uniform float intensidad_emision_colores : hint_range(0.0, 10.0) = 1.0; 
// Controla la intensidad del brillo máximo en las crestas
uniform float intensidad_emision_brillo : hint_range(0.0, 10.0) = 3.0;

group_uniforms Direcciones_y_Movimiento;
uniform vec2 velocidad_capa_base = vec2(0.015, -0.010);
uniform vec2 velocidad_retazo_1 = vec2(-0.025, 0.020);
uniform vec2 velocidad_retazo_2 = vec2(0.020, 0.030);

group_uniforms Texturas_y_Forma;
uniform sampler2D noise_pincelada_1 : hint_default_white, repeat_enable;
uniform sampler2D noise_pincelada_2 : hint_default_white, repeat_enable;
uniform float escala_mundo = 0.2; // Escala global continua
uniform float deformacion_vertices : hint_range(0.0, 20.0) = 0.15;
// Controla qué tan orgánicas y curvadas son las nubes de los retazos (elimina líneas rectas)
uniform float distorsion_organica_nubes : hint_range(0.0, 1.0) = 0.5;

group_uniforms Disolucion_y_Mezcla;
uniform sampler2D depth_texture : hint_depth_texture;
uniform float suavizado_proximidad = 1.0; // Integración suave contra paredes/suelo
uniform float fade_dissolve : hint_range(0.0, 1.0) = 1.0; // Controlado por GDScript

varying vec3 world_pos_var;

void vertex() {
	// 1. Guardamos la posición global real del vértice
	world_pos_var = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Ondulación de vértices con deformación continua
	vec2 uv_v1 = (world_pos_var.xz * escala_mundo) + (TIME * velocidad_capa_base);
	vec2 uv_v2 = (world_pos_var.xy * escala_mundo * 1.5) + (TIME * velocidad_retazo_1);
	
	float n1 = texture(noise_pincelada_1, uv_v1).r;
	float n2 = texture(noise_pincelada_2, uv_v2).r;
	float desplazamiento_ondulado = (n1 - 0.5) + (n2 - 0.5);

	VERTEX += NORMAL * desplazamiento_ondulado * deformacion_vertices;
}

void fragment() {
	// --- 1. Muestreo de Ruido Semilla para Deformación Fluida ---
	vec2 uv_semilla = (world_pos_var.xz * escala_mundo) + (TIME * velocidad_capa_base);
	float ruido_semilla = texture(noise_pincelada_1, uv_semilla).r;

	// Distorsión tridimensional (curvada, sin rectas)
	vec2 distorsion_uv = vec2(
		sin(world_pos_var.y * 0.4 + TIME * 0.2) + (ruido_semilla - 0.5),
		cos(world_pos_var.x * 0.4 - TIME * 0.25) + (ruido_semilla - 0.5)
	) * distorsion_organica_nubes;

	// --- 2. Coordenadas Únicas y Continuas para Cada Capa ---
	vec2 uv_base = (vec2(world_pos_var.x, world_pos_var.z + world_pos_var.y * 0.3) * escala_mundo) + (TIME * velocidad_capa_base) + distorsion_uv;
	vec2 uv_retazo1 = (vec2(world_pos_var.x * 0.85 + world_pos_var.y * 0.5, world_pos_var.z * 0.85 + world_pos_var.y * 0.5) * escala_mundo * 1.1) + (TIME * velocidad_retazo_1) - distorsion_uv * 1.2;
	vec2 uv_retazo2 = (vec2(world_pos_var.z * 0.9 - world_pos_var.y * 0.6, world_pos_var.x * 0.9 + world_pos_var.y * 0.4) * escala_mundo * 0.95) + (TIME * velocidad_retazo_2) + distorsion_uv.yx;

	float n_base = texture(noise_pincelada_1, uv_base).r;
	float n_ret1 = texture(noise_pincelada_2, uv_retazo1).r;
	float n_ret2 = texture(noise_pincelada_1, uv_retazo2).r;

	// --- 3. Cálculo de Pesos Balanceados (Ningún color se opaca) ---
	float w_base = smoothstep(0.7, 0.1, n_base);    // Presente en valles de ruido
	float w_ret1 = smoothstep(0.2, 0.8, n_ret1);    // Presente en picos del retazo 1
	float w_ret2 = smoothstep(0.2, 0.8, n_ret2);    // Presente en picos del retazo 2

	// Normalizamos la suma para que siempre sumen 100% de color
	float peso_total = max(w_base + w_ret1 + w_ret2, 0.001);

	// Mezcla suave y fluida de los 3 colores principales
	vec3 color_tricolor = (color_base.rgb * w_base + color_retazo_1.rgb * w_ret1 + color_retazo_2.rgb * w_ret2) / peso_total;

	// --- 4. Vetas incandescentes (Color Brillo) ---
	float peak_energy = (n_base * 0.35) + (n_ret1 * 0.35) + (n_ret2 * 0.35);
	float zonas_brillo = smoothstep(0.58, 0.82, peak_energy);
	
	vec3 color_mezclado = mix(color_tricolor, color_brillo.rgb, zonas_brillo);

	// --- 5. Cálculo de Emisión Independiente ---
	// Separamos el brillo de los colores base y el brillo de las crestas
	vec3 emision_base = color_tricolor * intensidad_emision_colores;
	vec3 emision_crestas = color_brillo.rgb * intensidad_emision_brillo;
	
	// Mezclamos ambas emisiones según las zonas de brillo
	vec3 emision_final = mix(emision_base, emision_crestas, zonas_brillo);

	// --- 6. Proximity Fade ---
	float depth_tex = texture(depth_texture, SCREEN_UV).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	world_pos.xyz /= world_pos.w;
	float prox_fade = clamp(1.0 - smoothstep(world_pos.z + suavizado_proximidad, world_pos.z, VERTEX.z), 0.0, 1.0);

	// --- 7. Resultado Final (Albedo, Emisión y Opacidad) ---
	ALBEDO = color_mezclado;
	EMISSION = emision_final * prox_fade * fade_dissolve;
	ALPHA = prox_fade * fade_dissolve;
}