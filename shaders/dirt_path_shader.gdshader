//Info: Este shader debe usarse con boxMesh 1m x 1m x 1m y modificar el tamaño con scale

shader_type spatial;
// depth_test_disabled: Evita que el motor oculte las caras traseras cuando el suelo está dentro del cubo.
// depth_draw_never: Evita conflictos de profundidad con otros materiales transparentes.
// unshaded: Desactiva por completo las luces y sombras, garantizando un color plano, idéntico y perfecto en cualquier terreno.
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_front, unshaded;

// --- TEXTURA DEL CAMINO ---
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 path_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- AJUSTE DE ILUMINACIÓN GLOBAL (MULTIPLICADOR) ---
// Usa este color para mimetizar el camino con la iluminación de tu mundo (ej. azulado para la noche, amarillento para el atardecer).
uniform vec4 global_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- RUIDO ORGÁNICO ---
uniform sampler2D noise_texture : hint_default_white, repeat_enable; 
uniform float noise_scale : hint_range(0.1, 20.0, 0.1) = 1.0;

// --- CONTROL DE BORDES (ANCHO Y DESVANECIDO) ---
uniform float path_width : hint_range(0.0, 1.0, 0.01) = 0.8; 
uniform float edge_softness : hint_range(0.01, 1.0, 0.01) = 0.2; 
uniform float edge_distortion : hint_range(0.0, 1.0, 0.01) = 0.3; 

// --- HUECOS / PARCHES ---
uniform float patch_holes : hint_range(0.0, 1.0, 0.01) = 0.1; 

// --- CURVATURA MATEMÁTICA ---
group_uniforms Curvatura_Camino;
// Activa esto para convertir el bloque en una esquina curva de 90 grados
uniform bool use_90_deg_bend = false;
// Si está activo gira a la derecha. Si está apagado gira a la izquierda
uniform bool bend_right = true;

// Parámetros para la onda Seno (Solo se usan si "use_90_deg_bend" está desactivado)
uniform float curve_amplitude : hint_range(-10.0, 10.0, 0.05) = 0.0;
uniform float curve_frequency : hint_range(0.01, 1.0, 0.001) = 0.1;
uniform float curve_phase : hint_range(-6.28, 6.28, 0.01) = 0.0;

// --- INTEGRACIÓN VOLUMÉTRICA ---
uniform sampler2D depth_texture : hint_depth_texture;
// Determina qué tan rápido se difumina el camino si el terreno sale por el techo o el piso del cubo
uniform float intersection_fade : hint_range(0.01, 0.5, 0.01) = 0.1; 

// --- UVs ---
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);


// Variables que se calculan en Vertex y se envían a Fragment
varying mat4 inv_modelview_matrix;
varying vec3 world_scale;

void vertex() {
	// MODELVIEW_MATRIX nos lleva de Local a Vista. Su inversa nos lleva directo de Vista a Local.
	inv_modelview_matrix = inverse(MODELVIEW_MATRIX);
	
	// Obtenemos la escala del nodo en el mundo para el auto-tiling de la textura
	world_scale = vec3(
		length(MODEL_MATRIX[0].xyz), 
		length(MODEL_MATRIX[1].xyz), 
		length(MODEL_MATRIX[2].xyz)
	);
}

void fragment() {
	// 1. Obtener la profundidad del terreno de fondo
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	
	// 2. Reconstruir NDC (Normalized Device Coordinates)
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	
	// 3. Pasar de NDC a Espacio de Vista (View Space)
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	
	// 4. Pasar de Vista a Espacio Local del Cubo
	vec3 local_pos = (inv_modelview_matrix * vec4(view_pos.xyz, 1.0)).xyz;
	
	// 5. Comprobar si el terreno está dentro de los límites del cubo (de -0.5 a 0.5 en ejes locales)
	vec3 bounds = step(abs(local_pos), vec3(0.5));
	float in_bounds = bounds.x * bounds.y * bounds.z;
	
	// Si el terreno está fuera de las dimensiones del cubo, no dibujamos nada
	if (in_bounds < 0.5) {
		discard;
	}

	// Variables para la proyección plana y distancia
	vec2 projected_uv;
	float dist_center;

	if (use_90_deg_bend) {
		// === MÁGICA CURVA DE 90 GRADOS (Giro Modular) ===
		vec2 U;
		
		// Calculamos vectores locales asegurándonos de que queden en cuadrantes positivos para simplificar
		if (bend_right) {
			U = vec2(0.5 - local_pos.x, 0.5 - local_pos.z);
		} else {
			U = vec2(local_pos.x + 0.5, 0.5 - local_pos.z);
		}
		
		float dist_to_pivot = length(U);
		
		// Si el píxel está más allá del límite exterior del giro, lo descartamos
		if (dist_to_pivot > 1.0) {
			discard;
		}
		
		// Obtenemos el ángulo del arco y calculamos la progresión t [0.0, 1.0]
		float theta = atan(U.y, U.x);
		float t = theta / (0.5 * PI);
		
		// Proyectamos las UVs adaptándolas a la circunferencia del arco
		float curve_x = (dist_to_pivot - 0.5) * world_scale.x;
		float curve_z = t * (0.5 * PI * world_scale.z);
		
		projected_uv = vec2(curve_x, curve_z);
		
		// El centro de nuestro camino circular siempre está en el radio 0.5
		dist_center = abs(dist_to_pivot - 0.5) * 2.0;
		
	} else {
		// === ONDA SINUSOIDAL / CAMINO RECTO TRADICIONAL ===
		float world_x = local_pos.x * world_scale.x;
		float world_z = local_pos.z * world_scale.z;
		
		float curve_offset = sin(world_z * curve_frequency + curve_phase) * curve_amplitude;
		
		projected_uv = vec2(world_x - curve_offset, world_z);
		
		float dist_center_world = abs(world_x - curve_offset);
		dist_center = dist_center_world / (world_scale.x * 0.5);
	}

	// 6. Mapear coordenadas finales
	vec2 final_uv = projected_uv * uv1_scale.xy + uv1_offset.xy;

	// 7. Muestreo de Texturas
	vec4 albedo_tex = texture(texture_albedo, final_uv);
	float noise = texture(noise_texture, final_uv * noise_scale).r;
	
	// 8. Deformar el borde sumando ruido
	float distorted_dist = dist_center + (noise - 0.5) * edge_distortion;
	
	// 9. Generar máscaras (Bordes orgánicos y parches)
	float edge_mask = 1.0 - smoothstep(path_width - edge_softness, path_width, distorted_dist);
	float hole_mask = smoothstep(patch_holes - 0.1, patch_holes + 0.1, noise);
	
	// 10. Desvanecido suave en los límites verticales (Techo y Piso del cubo)
	float edge_y = 0.5 - abs(local_pos.y);
	float vertical_fade = smoothstep(0.0, intersection_fade, edge_y);
	
	// 11. Mezcla y Salida final
	// Multiplicamos por global_tint para integrar el color de iluminación global de tu escena.
	ALBEDO = albedo_tex.rgb * path_color.rgb * global_tint.rgb;
	
	// Fusionamos todas las máscaras para controlar la opacidad (también multiplicando por el alfa de global_tint)
	ALPHA = edge_mask * hole_mask * vertical_fade * albedo_tex.a * path_color.a * global_tint.a;
	ROUGHNESS = 1.0;
}