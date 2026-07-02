shader_type spatial;

uniform vec4 albedo : source_color;

uniform sampler2D texture_albedo :
source_color,
filter_nearest,
repeat_enable;

uniform float roughness = 0.95;
uniform float specular = 0.05;

// Triplanar

varying vec3 tri_pos;
varying vec3 tri_blend;

// Waves

uniform float wave_height = 0.22;
uniform float wave_speed = 0.80;

uniform float ripple_amount = 0.025;

uniform float tide_amount = 0.05;
uniform float tide_speed = 0.15;

// Appearance

uniform vec4 water_color : source_color =
vec4(0.62,0.74,0.82,1.0);

uniform float water_alpha = 0.72;

uniform float texture_speed = 0.025;

void vertex() {
	float wave = 0.0;

	wave += sin(VERTEX.x*1.4 + TIME*wave_speed)*0.18;

	wave += sin(VERTEX.z*1.2 + TIME*wave_speed*0.7)*0.14;

	wave +=
	sin(VERTEX.x*8.0 + TIME*2.4)
	*
	sin(VERTEX.z*7.5 + TIME*2.0)
	*
	ripple_amount;

	wave +=
	sin(TIME*tide_speed)
	*
	tide_amount;

	VERTEX.y += wave * wave_height;
}

vec4 triplanar_texture(
	sampler2D sampler_,
	vec3 weights,
	vec3 position_
)
{

	vec4 samp = vec4(0.0);

	samp +=
		texture(sampler_,position_.xy)
		*weights.z;

	samp +=
		texture(sampler_,position_.xz)
		*weights.y;

	samp +=
		texture(
			sampler_,
			position_.zy*vec2(-1.0,1.0)
		)
		*weights.x;

	return samp;

}

void fragment()
{
	vec3 layer_a = tri_pos;
	vec3 layer_b = tri_pos;
	vec3 layer_c = tri_pos;
	
	layer_a.x += TIME * texture_speed;
	layer_a.z += TIME * texture_speed * 0.35;

	layer_b.x -= TIME * texture_speed * 0.45;
	layer_b.z += TIME * texture_speed * 0.70;

	layer_c.x += sin(TIME*0.15)*0.35;
	layer_c.z += cos(TIME*0.12)*0.35;
	
	vec4 texA =
	triplanar_texture(
	texture_albedo,
	tri_blend,
	layer_a);

	vec4 texB =
	triplanar_texture(
	texture_albedo,
	tri_blend,
	layer_b);

	vec4 texC =
	triplanar_texture(
	texture_albedo,
	tri_blend,
	layer_c);
	
	vec4 water =
	mix(
	mix(texA, texB, 0.5),
	texC,
	0.25);
	
	ALBEDO =
	albedo.rgb *
	water_color.rgb *
	water.rgb;

	METALLIC = 0.0;

	ROUGHNESS = roughness;

	SPECULAR = specular;

	EMISSION = ALBEDO * 0.03;

	ALPHA = water_alpha;
}