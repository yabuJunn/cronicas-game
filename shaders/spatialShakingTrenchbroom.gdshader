shader_type spatial;

// License: CC0 | Original shaking por Ultipuk
// Integrado para mantener texturas Low-Poly de TrenchBroom

// --- VARIABLES PARA LA TEXTURA (TRENCHBROOM) ---
uniform sampler2D albedo_tex : source_color, filter_nearest; // filter_nearest mantiene los píxeles definidos
uniform vec4 albedo_color : source_color = vec4(1.0);

// --- VARIABLES PARA EL EFECTO DE SACUDIDA (SHAKING) ---
/** Controla la intensidad de la sacudida (puedes animarla con un Tween de 0.0 a 1.0). */
uniform float progress: hint_range(0.0, 1.0) = 0.0;
/** Cuántas veces tiembla por segundo. */
uniform float frequency: hint_range(0.0, 60.0, 0.1) = 12.0;
/** Límite máximo del desplazamiento. */
uniform vec3 max_offset = vec3(0.1);

// --- FUNCIONES MATEMÁTICAS PARA EL RUIDO ---
float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453123);
}

float smooth_noise(float t) {
	float i = floor(t);
	float f = fract(t);
	
	// Curva smoothstep
	f = f * f * (3.0 - 2.0 * f);
	
	return mix(hash(i), hash(i + 1.0), f);
}

vec3 shake3(float t) {
	return vec3(
		smooth_noise(t),
		smooth_noise(t + 37.0),
		smooth_noise(t + 91.0)
	) * 2.0 - 1.0;
}

// --- MUEVE LOS VÉRTICES (SACUDIDA) ---
void vertex() {
	VERTEX += progress * shake3(TIME * frequency) * max_offset;
}

// --- PINTA LA TEXTURA EN PANTALLA ---
void fragment() {
	// Tomamos la textura original capturada de TrenchBroom y la aplicamos
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	ALBEDO = tex.rgb;
}