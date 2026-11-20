shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_nearest; // Filtro Nearest para el look pixelado PSX
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

group_uniforms Viento;
uniform float velocidad_viento = 2.0;
uniform float fuerza_viento = 0.15;
uniform float frequency_viento = 0.5;
uniform bool desincronizar = true; // Interruptor On/Off para el randomizador

group_uniforms Filtro_Hojas;
uniform float altura_minima_hojas = 2.0;
uniform float radio_minimo_hojas = 0.15;

uniform bool activar_depuracion_visual = false;

void vertex() {
	float distancia_al_centro = length(VERTEX.xz);
	float mascara_altura = smoothstep(altura_minima_hojas, altura_minima_hojas + 0.5, VERTEX.y);
	float mascara_radio = smoothstep(radio_minimo_hojas, radio_minimo_hojas + 0.1, distancia_al_centro);
	float peso_viento = mascara_altura * mascara_radio;

	// Posición global del objeto (funciona tanto para nodos individuales como para MultiMesh)
	vec3 pos_objeto_mundo = MODEL_MATRIX[3].xyz;
	vec3 pos_vertice_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float desfase_tiempo = 0.0;
	float factor_velocidad = 1.0;
	vec2 direccion_viento = vec2(1.0, 0.5);

	if (desincronizar) {
		// Generamos dos valores pseudoaleatorios únicos basados en la posición global del objeto
		float rand_1 = fract(sin(dot(pos_objeto_mundo.xz, vec2(12.9898, 78.233))) * 43758.5453);
		float rand_2 = fract(sin(dot(pos_objeto_mundo.xz, vec2(39.3468, 11.135))) * 24634.6345);

		desfase_tiempo = rand_1 * 6.283185; // Desfase completo de 0 a 360 grados
		factor_velocidad = 0.75 + (rand_2 * 0.5); // Cada árbol oscila a distinta velocidad (75% - 125%)

		// Variamos ligeramente el ángulo hacia donde se inclina cada objeto
		float angulo = (rand_1 - 0.5) * 1.5;
		direccion_viento = vec2(cos(angulo), sin(angulo));
	}

	float tiempo_modificado = (TIME * velocidad_viento * factor_velocidad) + desfase_tiempo;

	// Onda principal + micro-turbulencia usando coordenadas mundiales para que el viento "viaje" por el escenario
	float ola_principal = sin(tiempo_modificado + (pos_vertice_mundo.y * frequency_viento) + (pos_vertice_mundo.x * 0.25));
	float rafaga_secundaria = cos((tiempo_modificado * 0.65) + (pos_vertice_mundo.z * frequency_viento * 0.8)) * 0.35;
	float desplazamiento = (ola_principal + rafaga_secundaria) * fuerza_viento * peso_viento;

	VERTEX.x += desplazamiento * direccion_viento.x;
	VERTEX.z += desplazamiento * direccion_viento.y;
}

void fragment() {
	vec4 color_textura = texture(albedo_tex, UV);
	vec3 rgb = color_textura.rgb;

	ALBEDO = rgb;

	// Mantiene la superficie mate para evitar brillos plásticos, pero recibe luces, sombras y Environment del nivel
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