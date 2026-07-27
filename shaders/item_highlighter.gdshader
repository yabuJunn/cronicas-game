//

shader_type spatial;
render_mode unshaded, depth_draw_never;

group_uniforms Highlight;
uniform vec4 shine_color : source_color = vec4(1.0);
uniform float shine_speed : hint_range(0, 25) = 2.0;
uniform float shine_width : hint_range(0.001, 1.0) = 0.08; // Valor por defecto fino (8cm)
uniform float softness : hint_range(0.0, 1.0) = 0.5;       // Difuminado de bordes
uniform float cycle_interval : hint_range(0, 100) = 2.0;
uniform float angle_fade : hint_range(0, 1) = 0.5;

group_uniforms HighlightDirection;
uniform float x_direction : hint_range(-1, 1) = 0.0;
uniform float y_direction : hint_range(-1, 1) = 1.0;
uniform float z_direction : hint_range(-1, 1) = 0.5;

float sawtooth(float x) {
	float period = shine_width + cycle_interval;
	return 2.0 * ((x + shine_speed * TIME) / period - floor(0.5 + (x + shine_speed * TIME) / period));
}

void fragment() {
	vec3 w_vertex = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Proyección en la dirección deseada
	float projection = dot(w_vertex, normalize(vec3(x_direction, y_direction, z_direction)));
	
	// Calculamos la franja con bordes suaves si softness > 0
	float raw_freq = sawtooth(projection) - sawtooth(projection + shine_width);
	float frequency = smoothstep(0.0, max(softness, 0.001), raw_freq);
	
	ALBEDO = shine_color.xyz;
	ALPHA = clamp((1.0 - dot(NORMAL, VIEW) * angle_fade) * frequency * shine_color.a, 0.0, 1.0);	
}