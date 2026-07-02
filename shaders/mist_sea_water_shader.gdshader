shader_type spatial;

uniform sampler2D water_texture;

uniform vec2 speed = vec2(0.05,0.02);

void fragment(){

    vec2 uv = UV + TIME * speed;

    ALBEDO = texture(water_texture, uv).rgb;

    ALPHA = 0.6;
}