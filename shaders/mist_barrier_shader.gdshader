// Shader de Niebla Pintoresca Multicolor (Opaco y Sin Costuras Rectangulares)
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

group_uniforms Colores_Pintura;
uniform vec4 color_base : source_color = vec4(0.12, 0.18, 0.28, 1.0);
uniform vec4 color_retazo_1 : source_color = vec4(0.85, 0.45, 0.65, 1.0); // Pincelada A
uniform vec4 color_retazo_2 : source_color = vec4(0.25, 0.75, 0.85, 1.0); // Pincelada B
uniform vec4 color_brillo : source_color = vec4(0.95, 0.95, 1.00, 1.0);   // Crestas/Bordes

group_uniforms Direcciones_y_Movimiento;
uniform vec2 velocidad_capa_base = vec2(0.015, -0.010);
uniform vec2 velocidad_retazo_1 = vec2(-0.025, 0.020);
uniform vec2 velocidad_retazo_2 = vec2(0.020, 0.030);

group_uniforms Texturas_y_Forma;
uniform sampler2D noise_pincelada_1 : hint_default_white, repeat_enable;
uniform sampler2D noise_pincelada_2 : hint_default_white, repeat_enable;
uniform float escala_mundo = 0.2; // Escala global continua (sustituye al UV del BoxMesh)
uniform float deformacion_vertices : hint_range(0.0, 10) = 0.15;

group_uniforms Disolucion_y_Mezcla;
uniform sampler2D depth_texture : hint_depth_texture;
uniform float suavizado_proximidad = 1.0; // Integración suave contra paredes/suelo
uniform float fade_dissolve : hint_range(0.0, 1.0) = 1.0; // Controlado por GDScript

varying vec3 world_pos_var;

void vertex() {
	// 1. Guardamos la posición global real del vértice
	world_pos_var = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Usamos la posición del mundo para mover los vértices de forma continua sin marcar caras
	vec2 uv_v1 = (world_pos_var.xz * escala_mundo) + (TIME * velocidad_capa_base);
	vec2 uv_v2 = (world_pos_var.xy * escala_mundo * 1.5) + (TIME * velocidad_retazo_1);
	
	float n1 = texture(noise_pincelada_1, uv_v1).r;
	float n2 = texture(noise_pincelada_2, uv_v2).r;
	float desplazamiento_ondulado = (n1 - 0.5) + (n2 - 0.5);

	VERTEX += NORMAL * desplazamiento_ondulado * deformacion_vertices;
}

void fragment() {
	// --- 1. Muestreo continuo usando Posición de Mundo ---
	// Cruzamos los ejes XZ, XY y ZY para que el patrón fluya sin importar el lado del cubo
	vec2 uv_1 = (world_pos_var.xz * escala_mundo) + (TIME * velocidad_capa_base);
	vec2 uv_2 = (world_pos_var.xy * escala_mundo * 1.3) + (TIME * velocidad_retazo_1);
	vec2 uv_3 = (world_pos_var.zy * escala_mundo * 0.8) + (TIME * velocidad_retazo_2);

	float ruido_base = texture(noise_pincelada_1, uv_1).r;
	float ruido_retazo1 = texture(noise_pincelada_2, uv_2).r;
	float ruido_retazo2 = texture(noise_pincelada_1, uv_3).r;

	// --- 2. Mezcla de Retazos de Color ---
	vec3 color_mezclado = mix(color_base.rgb, color_retazo_1.rgb, smoothstep(0.3, 0.7, ruido_retazo1));
	color_mezclado = mix(color_mezclado, color_retazo_2.rgb, smoothstep(0.35, 0.75, ruido_retazo2));
	
	float zonas_brillo = smoothstep(0.6, 0.9, ruido_base * ruido_retazo1 * 2.0);
	color_mezclado = mix(color_mezclado, color_brillo.rgb, zonas_brillo);

	// --- 3. Proximity Fade (Suavizado contra paredes/suelo) ---
	float depth_tex = texture(depth_texture, SCREEN_UV).r;
	vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	world_pos.xyz /= world_pos.w;
	float prox_fade = clamp(1.0 - smoothstep(world_pos.z + suavizado_proximidad, world_pos.z, VERTEX.z), 0.0, 1.0);

	// --- 4. Resultado Final ---
	ALBEDO = color_mezclado;
	
	// OPACIDAD SÓLIDA: El cuerpo de la niebla es 100% opaco.
	// Solo se suaviza en el contacto con las paredes (prox_fade) o al abrir la puerta (fade_dissolve).
	ALPHA = prox_fade * fade_dissolve;
}