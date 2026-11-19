// Info: Funciona con cualquier PlaneMesh (sin importar su Size ni su Scale).
shader_type spatial;

render_mode blend_mix, depth_draw_never, cull_disabled;

// --- FORMA DEL CAMINO ---
group_uniforms Forma_Camino;
// 0 = Recto u Onda Seno | 1 = Curva de 90° | 2 = Circular / Claro de bosque
uniform int path_mode : hint_enum("Recto / Onda", "Curva 90 Grados", "Circular (Claro)") = 0;
uniform bool bend_right = true;
// Desactivado = textura plana sin estiramientos. Activado = la textura gira siguiendo la curva.
uniform bool follow_curve_uv = false;

// Parámetros para la onda Seno (Solo en modo "Recto / Onda")
uniform float curve_amplitude : hint_range(-10.0, 10.0, 0.05) = 0.0;
uniform float curve_frequency : hint_range(0.01, 1.0, 0.001) = 0.1;
uniform float curve_phase : hint_range(-6.28, 6.28, 0.01) = 0.0;

// Parámetros para el Claro Irregular (Solo en modo "Circular (Claro)")
uniform float clearing_irregularity : hint_range(0.0, 1.5, 0.01) = 0.45;
uniform float clearing_lobes : hint_range(2.0, 8.0, 1.0) = 3.0;
uniform float clearing_seed : hint_range(0.0, 20.0, 0.1) = 0.0;

// --- TEXTURA DEL CAMINO ---
group_uniforms Textura_y_Color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 path_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 global_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

// --- ANTI-REPETICIÓN (ROMPER TILING) ---
group_uniforms Anti_Repeticion;
// Qué tanto se mezcla una segunda capa rotada de la textura para ocultar repeticiones
uniform float anti_tiling_strength : hint_range(0.0, 1.0, 0.01) = 0.65;
// Tamaño de los parches de variación (valores bajos = parches más grandes y naturales)
uniform float macro_noise_scale : hint_range(0.01, 2.0, 0.01) = 0.15;
// Variación sutil de brillo/oscuridad para que el camino no se vea uniforme
uniform float color_variation : hint_range(0.0, 0.5, 0.01) = 0.12;

// --- RUIDO Y DESBASTADO DE BORDES ---
group_uniforms Bordes_y_Ruido;
uniform sampler2D noise_texture : hint_default_white, repeat_enable;
uniform float noise_scale : hint_range(0.05, 10.0, 0.05) = 0.5;
uniform float path_width : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float edge_softness : hint_range(0.01, 1.0, 0.01) = 0.2;
uniform float edge_distortion : hint_range(0.0, 1.5, 0.01) = 0.4;
uniform float patch_holes : hint_range(0.0, 1.0, 0.01) = 0.1;

varying vec2 world_pos_xz;

// Función auxiliar para rotar UVs y romper el patrón de cuadrícula
vec2 rotate_uv(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
}

void vertex() {
	vec3 world_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	world_pos_xz = vec2(VERTEX.x * world_scale.x, VERTEX.z * world_scale.z);
}

void fragment() {
	vec2 norm_pos = UV - vec2(0.5);

	float total_size_x = length(vec2(dFdx(world_pos_xz.x), dFdy(world_pos_xz.x))) / max(length(vec2(dFdx(UV.x), dFdy(UV.x))), 0.00001);
	float total_size_z = length(vec2(dFdx(world_pos_xz.y), dFdy(world_pos_xz.y))) / max(length(vec2(dFdx(UV.y), dFdy(UV.y))), 0.00001);

	vec2 projected_uv;
	float dist_center;

	if (path_mode == 1) {
		// === 1. CURVA DE 90 GRADOS ===
		vec2 U = bend_right
			? vec2(0.5 - norm_pos.x, 0.5 - norm_pos.y)
			: vec2(norm_pos.x + 0.5, 0.5 - norm_pos.y);

		float dist_to_pivot = length(U);
		if (dist_to_pivot > 1.0) {
			discard;
		}

		dist_center = abs(dist_to_pivot - 0.5) * 2.0;

		if (follow_curve_uv) {
			float theta = atan(U.y, U.x);
			float t = theta / (0.5 * PI);
			float avg_size = (total_size_x + total_size_z) * 0.5;
			float curve_x = (dist_to_pivot - 0.5) * avg_size;
			float curve_z = t * (0.25 * PI * avg_size);
			projected_uv = vec2(curve_x, curve_z);
		} else {
			projected_uv = world_pos_xz;
		}

	} else if (path_mode == 2) {
		// === 2. CIRCULAR / CLARO DEL BOSQUE ORGÁNICO ===
		projected_uv = world_pos_xz;
		float raw_dist = length(norm_pos) * 2.0;
		float angle = atan(norm_pos.y, norm_pos.x);

		// Suma de ondas angulares para crear lóbulos naturales sin costuras
		float lobe_wave = sin(angle * clearing_lobes + clearing_seed) * 0.5
						+ cos(angle * (clearing_lobes * 2.0 - 1.0) - clearing_seed * 1.7) * 0.3
						+ sin(angle * (clearing_lobes + 2.0) + clearing_seed * 2.3) * 0.2;

		// Ruido de baja frecuencia para romper la simetría de la silueta
		float shape_noise = texture(noise_texture, norm_pos * 1.2 + vec2(clearing_seed * 0.13)).r - 0.5;

		// Deformamos la distancia radial
		float shape_offset = (lobe_wave * 0.3 + shape_noise * 0.5) * clearing_irregularity;
		dist_center = raw_dist + shape_offset;

	} else {
		// === 0. RECTO / ONDA SINUSOIDAL ===
		float curve_offset = sin(world_pos_xz.y * curve_frequency + curve_phase) * curve_amplitude;
		projected_uv = follow_curve_uv
			? vec2(world_pos_xz.x - curve_offset, world_pos_xz.y)
			: world_pos_xz;

		float dist_center_world = abs(world_pos_xz.x - curve_offset);
		dist_center = dist_center_world / max(total_size_x * 0.5, 0.0001);
	}

	// --- MUESTREO DE TEXTURA CON ANTI-REPETICIÓN ---
	vec2 final_uv = projected_uv * uv1_scale.xy + uv1_offset.xy;
	float macro_noise = texture(noise_texture, projected_uv * macro_noise_scale).r;

	vec4 tex_a = texture(texture_albedo, final_uv);
	vec2 uv_b = rotate_uv(final_uv, 1.15) * 1.13 + vec2(0.37, 0.71);
	vec4 tex_b = texture(texture_albedo, uv_b);

	float blend_factor = smoothstep(0.25, 0.75, macro_noise) * anti_tiling_strength;
	vec4 albedo_tex = mix(tex_a, tex_b, blend_factor);

	float var_tint = mix(1.0 - color_variation, 1.0 + color_variation, macro_noise);

	// --- RUIDO DE BORDES Y HUECOS ---
	float noise = texture(noise_texture, projected_uv * noise_scale).r;

	float distorted_dist = dist_center + (noise - 0.5) * edge_distortion;
	float edge_mask = 1.0 - smoothstep(max(0.0, path_width - edge_softness), path_width, distorted_dist);

	// Protección de borde: en modo Claro protege contra los límites del cuadrado para dejar crecer los lóbulos
	float guard_dist = (path_mode == 2) ? max(abs(norm_pos.x), abs(norm_pos.y)) * 2.0 : dist_center;
	float border_guard = 1.0 - smoothstep(0.92, 1.0, guard_dist);

	float hole_mask = smoothstep(patch_holes - 0.1, patch_holes + 0.1, noise);

	// --- SALIDA FINAL ---
	ALBEDO = albedo_tex.rgb * path_color.rgb * global_tint.rgb * var_tint;
	ALPHA = edge_mask * border_guard * hole_mask * albedo_tex.a * path_color.a * global_tint.a;
	ROUGHNESS = 1.0;
}