shader_type spatial;
// render_mode unshaded: no lo afecta la luz.
// cull_front: solo dibuja la parte trasera para crear el borde.
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Blanco por defecto
uniform float outline_width = 1.0;

void vertex() {
    // CAMBIO CLAVE: En lugar de NORMAL, usamos normalize(VERTEX).
    // Esto toma la posición local del vértice respecto al centro (0,0,0) del objeto
    // y lo empuja uniformemente hacia afuera como si fuera un globo.
    if (length(VERTEX) > 0.0) {
        VERTEX += normalize(VERTEX) * (outline_width / 100.0);
    }
}

void fragment() {
    ALBEDO = outline_color.rgb;
    ALPHA = outline_color.a;
}