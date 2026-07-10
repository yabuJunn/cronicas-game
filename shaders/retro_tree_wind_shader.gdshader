shader_type spatial;
render_mode cull_disabled, depth_draw_opaque; // cull_disabled es vital para ver las hojas por ambos lados

uniform sampler2D albedo_tex : source_color, filter_nearest; // Filtro Nearest para el look pixelado PSX
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

group_uniforms Viento;
uniform float velocidad_viento = 2.0;
uniform float fuerza_viento = 0.15;
uniform float frequency_viento = 0.5;
uniform bool desincronizar_arboles = true; // Interruptor On/Off para el randomizador

group_uniforms Filtro_Hojas;
uniform float altura_minima_hojas = 2.0;  // Altura (Y) donde empiezan las hojas
uniform float radio_minimo_hojas = 0.15;  // Qué tan lejos del centro (X,Z) deben estar para moverse

group_uniforms Sombreado_Retro;
uniform int niveles_sombra : hint_range(2, 6) = 3; // Cuántos "escalones" de color tendrá el sombreado
uniform float nitidez_sombra : hint_range(0.0, 1.0) = 0.5; // 0.0 = Borde totalmente duro, 1.0 = Degradado suave
uniform vec4 tinte_sombra : source_color = vec4(0.35, 0.38, 0.45, 1.0); // <-- NUEVO: Evita el efecto "multiplicar" feo

uniform bool activar_depuracion_visual = false; // Te ayuda a ver en rojo qué se va a mover

void vertex() {
	// 1. Calculamos la distancia horizontal (X, Z) desde el centro del tronco
	float distancia_al_centro = length(VERTEX.xz);
	
	// 2. Creamos las máscaras usando un degradado suave (smoothstep)
	float mascara_altura = smoothstep(altura_minima_hojas, altura_minima_hojas + 0.5, VERTEX.y);
	float mascara_radio = smoothstep(radio_minimo_hojas, radio_minimo_hojas + 0.1, distancia_al_centro);
	
	// El peso final del viento: Solo afecta si está alto Y lejos del centro del tronco
	float peso_viento = mascara_altura * mascara_radio;
	
	// --- SISTEMA DE CAOS POR POSICIÓN ---
	float desfase_mundo = 0.0;
	float factor_velocidad = 1.0;
	
	if (desincronizar_arboles) {
		float pseudo_random = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
		desfase_mundo = pseudo_random * 6.283185;
		factor_velocidad = 0.8 + (pseudo_random * 0.4);
	}
	
	// 3. Simulación matemática de la onda del viento
	float tiempo_modificado = TIME * velocidad_viento * factor_velocidad;
	float ola = sin(tiempo_modificado + (VERTEX.y * frequency_viento) + (VERTEX.x * 0.3) + desfase_mundo) * fuerza_viento;
	
	// Aplicamos el movimiento en los ejes X y Z multiplicado por nuestro peso
	VERTEX.x += ola * peso_viento;
	VERTEX.z += ola * 0.5 * peso_viento;
}

void fragment() {
	vec4 color_textura = texture(albedo_tex, UV);
	ALBEDO = color_textura.rgb;
	
	// TRUCO RETRO: Corregir normales para mallas dobles (hojas planas)
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	
	// Transparencia Alpha Scissor
	ALPHA = color_textura.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	
	// Modo de depuración
	if (activar_depuracion_visual) {
		float distancia_al_centro = length(VERTEX.xz);
		float mascara_altura = smoothstep(altura_minima_hojas, altura_minima_hojas + 0.5, VERTEX.y);
		float mascara_radio = smoothstep(radio_minimo_hojas, radio_minimo_hojas + 0.1, distancia_al_centro);
		float peso_viento = mascara_altura * mascara_radio;
		
		ALBEDO = mix(color_textura.rgb, vec3(1.0, 0.0, 0.0), peso_viento * 0.8);
	}
}

// --- PROCESADOR DE ILUMINACIÓN OPTIMIZADO ---
void light() {
	// 1. Incidencia de la luz base (N dot L) en rango Half-Lambert (0.0 a 1.0)
	float lambert = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	
	// 2. Cuantización estilizada (escalones retro)
	float pasos = float(niveles_sombra);
	float luz_pixelada = floor(lambert * pasos) / (pasos - 1.0);
	
	// INTERPOLACIÓN DE DUREZA: Mezclamos la luz pixelada y la suave según el gusto del usuario
	float iluminacion_final = mix(luz_pixelada, lambert, nitidez_sombra);
	
	// 3. MEZCLA DE COLOR (Adiós al efecto multiplicar plano)
	// En lugar de oscurecer hacia negro, interpolamos entre el color iluminado por el sol
	// y un tinte ambiental que mantiene los colores de tu textura ricos y definidos.
	vec3 color_luz_directa = LIGHT_COLOR * iluminacion_final;
	vec3 color_luz_sombra = tinte_sombra.rgb * (1.0 - iluminacion_final);
	
	// Combinamos todo respetando la atenuación de las sombras del mapa
	DIFFUSE_LIGHT += ALBEDO * (color_luz_directa + color_luz_sombra) * ATTENUATION;
}