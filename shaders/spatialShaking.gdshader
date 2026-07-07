shader_type spatial;

// License: CC0
// Author: Ultipuk, https://ultipuk.xyz
// Link: https://godotshaders.com/shader/spatial-shaking

/** Use this from the editor for interpolation. */
uniform float progress: hint_range(0.0, 1.0) = 1.0;
/** How many times it shakes per second. */
uniform float frequency: hint_range(0.0, 60.0, 0.1) = 12.0;
/** Shaking bounds. */
uniform vec3 max_offset = vec3(0.1);

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453123);
}

float smooth_noise(float t) {
	float i = floor(t);
	float f = fract(t);
	
	// smoothstep curve
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

void vertex() {
	VERTEX += progress * shake3(TIME * frequency) * max_offset;
}
