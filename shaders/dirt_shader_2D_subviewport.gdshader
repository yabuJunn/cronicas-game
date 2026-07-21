// Info: Generador dinámico de caminos con fusión limpia en mundo global
shader_type canvas_item;

// --- TEXTURA DEL CAMINO ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 path_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- RUIDO ORGÁNICO ---
uniform sampler2D noise_texture : hint_default_white, repeat_enable; 
uniform float noise_scale : hint_range(0.1, 20.0, 0.1) = 1.0;

// --- CONTROL DE BORDES (ANCHO Y DESVANECIDO) ---
uniform float path_width : hint_range(0.0, 1.0, 0.01) = 0.8; 
uniform float edge_softness : hint_range(0.01, 1.0, 0.01) = 0.2; 
uniform float edge_distortion : hint_range(0.0, 1.0, 0.01) = 0.3; 

// --- HUECOS / PARCHES ---
uniform float patch_holes : hint_range(0.0, 1.0, 0.01) = 0.1; 

// --- MODOS DE CURVATURA ---
group_uniforms Modos_De_Camino;
uniform bool use_circle_mode = false;
uniform bool use_90_deg_bend = false;
uniform bool bend_right = true;

group_uniforms Parametros_Curva_Sinaudal;
uniform float curve_amplitude : hint_range(-10.0, 10.0, 0.05) = 0.0;
uniform float curve_frequency : hint_range(0.01, 1.0, 0.001) = 0.1;
uniform float curve_phase : hint_range(-6.28, 6.28, 0.01) = 0.0;

group_uniforms Parametros_Circulo;
uniform float circle_radius = 6.0; 

// --- COORDENADAS GLOBALES (MÁGICA DE FUSIÓN) ---
group_uniforms Alineacion_Global;
uniform bool lock_to_world_grid = true; // Activa la fusión invisible entre piezas
uniform vec2 global_pos = vec2(0.0);    // Posición X y Z del Decal en el mundo 3D
uniform float global_rot = 0.0;   // Rotación Y del Decal en el mundo 3D

// Variables de mapeo global
uniform float track_width = 4.0;  
uniform vec2 virtual_scale = vec2(5.0, 5.0);
uniform vec2 uv1_scale = vec2(1.0, 1.0);
uniform vec2 uv1_offset = vec2(0.0, 0.0);

void fragment() {
	vec2 local_pos = UV - vec2(0.5);
	
	// Calculamos los metros locales relativos al centro del Decal
	float world_x = local_pos.x * virtual_scale.x;
	float world_y = local_pos.y * virtual_scale.y;
	
	vec2 projected_uv;
	float dist_center;

	if (use_circle_mode) {
		// --- MODO PLAZA CÍRCULO LLENO ---
		vec2 world_pos = vec2(world_x, world_y);
		float dist_to_center = length(world_pos);
		projected_uv = world_pos;
		float max_radius = circle_radius + (track_width * 0.5);
		dist_center = (dist_to_center / max_radius) * path_width;
		
	} else if (use_90_deg_bend) {
		// --- MODO GIRO 90 GRADOS ---
		vec2 U;
		if (bend_right) {
			U = vec2(0.5 - local_pos.x, 0.5 - local_pos.y);
		} else {
			U = vec2(local_pos.x + 0.5, 0.5 - local_pos.y);
		}
		
		float dist_to_pivot = length(U);
		if (dist_to_pivot > 1.0 || dist_to_pivot < 0.0) {
			COLOR = vec4(0.0);
		}
		
		float theta = atan(U.y, U.x);
		float t = theta / (0.5 * PI);
		
		float curve_x = (dist_to_pivot - 0.5) * virtual_scale.x;
		float curve_y = t * (0.5 * PI * virtual_scale.y);
		
		projected_uv = vec2(curve_x, curve_y);
		dist_center = abs(dist_to_pivot - 0.5) / (track_width * 0.5);
		
	} else {
		// --- MODO RECTO / LINEAL SINUSOIDAL ---
		float curve_offset = sin(world_y * curve_frequency + curve_phase) * curve_amplitude;
		projected_uv = vec2(world_x - curve_offset, world_y);
		float dist_center_world = abs(world_x - curve_offset);
		dist_center = dist_center_world / (track_width * 0.5);
	}

	// MÁGICA: Si está activo, recalculamos la UV usando la posición del mundo real en 3D
	vec2 final_uv;
	if (lock_to_world_grid) {
		float cos_b = cos(global_rot);
		float sin_b = sin(global_rot);
		// Matriz de rotación 2D para acompañar el giro del Decal en el mapa
		vec2 world_space_coords = vec2(
			world_x * cos_b - world_y * sin_b,
			world_x * sin_b + world_y * cos_b
		) + global_pos;
		
		final_uv = world_space_coords * uv1_scale + uv1_offset;
	} else {
		final_uv = projected_uv * uv1_scale + uv1_offset;
	}

	vec4 albedo_tex = texture(texture_albedo, final_uv);
	float noise = texture(noise_texture, final_uv * noise_scale).r;
	
	float distorted_dist = dist_center + (noise - 0.5) * edge_distortion;
	
	float edge_mask = 1.0 - smoothstep(path_width - edge_softness, path_width, distorted_dist);
	float hole_mask = smoothstep(patch_holes - 0.1, patch_holes + 0.1, noise);
	
	COLOR.rgb = albedo_tex.rgb * path_color.rgb;
	COLOR.a = edge_mask * hole_mask * albedo_tex.a * path_color.a;
}