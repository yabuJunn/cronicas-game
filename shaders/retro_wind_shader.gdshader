shader_type spatial;
// specular_disabled elimina cualquier reflejo plástico o destello de luz
render_mode cull_disabled, depth_draw_opaque, specular_disabled; 

uniform sampler2D albedo_tex : source_color, filter_nearest; // Filtro Nearest para el look pixelado PSX
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

group_uniforms Viento;
uniform float velocidad_viento = 2.0;
uniform float fuerza_viento = 0.15;
uniform float frequency_viento = 0.5;
uniform bool desincronizar_arboles = true;

group_uniforms Filtro_Hojas;
uniform float altura_minima_hojas = 2.0;  
uniform float radio_minimo_hojas = 0.15;  

group_uniforms Sombreado_Retro;
uniform int niveles_sombra : hint_range(2, 6) = 3; 
uniform float nitidez_sombra : hint_range(0.0, 1.0) = 0.5; // 0.0 = Duro, 1.0 = Difuminado sutil
uniform vec4 tinte_sombra : source_color = vec4(0.5, 0.55, 0.6, 1.0); // <-- Sube este color para aclarar las sombras

group_uniforms Ajustes_Color_Estilo;
uniform float desaturacion : hint_range(0.0, 1.0) = 0.25; // <-- Controla qué tan vivos/lavados se ven los colores
uniform float aclarar_textura : hint_range(0.0, 1.0) = 0.15; // <-- Levanta el brillo general de la textura plana

uniform bool activar_depuracion_visual = false; 

void vertex() {
	float distancia_al_centro = length(VERTEX.xz);
	float mascara_altura = smoothstep(altura_minima_hojas, altura_minima_hojas + 0.5, VERTEX.y);
	float mascara_radio = smoothstep(radio_minimo_hojas, radio_minimo_hojas + 0.1, distancia_al_centro);
	float peso_viento = mascara_altura * mascara_radio;
	
	float desfase_mundo = 0.0;
	float factor_velocidad = 1.0;
	
	if (desincronizar_arboles) {
		float pseudo_random = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
		desfase_mundo = pseudo_random * 6.283185;
		factor_velocidad = 0.8 + (pseudo_random * 0.4);
	}
	
	float tiempo_modificado = TIME * velocidad_viento * factor_velocidad;
	float ola = sin(tiempo_modificado + (VERTEX.y * frequency_viento) + (VERTEX.x * 0.3) + desfase_mundo) * fuerza_viento;
	
	VERTEX.x += ola * peso_viento;
	VERTEX.z += ola * 0.5 * peso_viento;
}

void fragment() {
	vec4 color_textura = texture(albedo_tex, UV);
	vec3 rgb = color_textura.rgb;
	
	// 1. DESATURACIÓN: Convertimos sutilmente a escala de grises según el valor de 'desaturacion'
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(rgb, vec3(luma), desaturacion);
	
	// 2. ACLARADO BASE: Mezclamos ligeramente con blanco para suavizar la dureza del color puro
	rgb = mix(rgb, vec3(1.0), aclarar_textura * 0.4);
	
	ALBEDO = rgb;
	
	// Forzamos al material a ser completamente mate en el renderizado base
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	
	ALPHA = color_textura.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	
	if (activar_depuracion_visual) {
		float distancia_al_centro = length(VERTEX.xz);
		float mascara_altura = smoothstep(altura_minima_hojas, altura_minima_hojas + 0.5, VERTEX.y);
		float mascara_radio = smoothstep(radio_minimo_hojas, radio_minimo_hojas + 0.1, distancia_al_centro);
		float peso_viento = mascara_altura * mascara_radio;
		ALBEDO = mix(rgb, vec3(1.0, 0.0, 0.0), peso_viento * 0.8);
	}
}

void light() {
	// Cálculo Lambert suavizado
	float lambert = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	
	// Cuantización para el look retro escalonado
	float pasos = float(niveles_sombra);
	float luz_pixelada = floor(lambert * pasos) / (pasos - 1.0);
	
	// Combinación de dureza de la sombra
	float iluminacion_final = mix(luz_pixelada, lambert, nitidez_sombra);
	
	// FACTOR DE SOMBRA PROYECTADA: Evitamos que la atenuación rompa el color multiplicando por 0
	float factor_luz_total = iluminacion_final * ATTENUATION;
	
	// 3. INTERPOLACIÓN LINEAL: En lugar de multiplicar el ALBEDO de forma destructiva,
	// viajamos suavemente entre el Tinte de la Sombra (luz ambiental) y el color del Sol (LIGHT_COLOR).
	// Esto mantiene los colores limpios y te permite aclarar las zonas oscuras por completo.
	vec3 iluminacion_combinada = mix(tinte_sombra.rgb, LIGHT_COLOR, factor_luz_total);
	
	DIFFUSE_LIGHT += ALBEDO * iluminacion_combinada;
}