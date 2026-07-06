shader_type spatial;
// render_mode unshaded: no lo afecta la luz.
// cull_front: solo dibuja la 	parte trasera (clave para que parezca un borde y no cubra el objeto).
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Blanco por defecto
uniform float outline_width = 2.0;

void vertex() {
    // Inflamos el modelo siguiendo sus normales
    VERTEX += NORMAL * (outline_width / 100.0);
}

void fragment() {
    ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}