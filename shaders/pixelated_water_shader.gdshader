shader_type spatial;

// Depth Colors
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;

uniform float roughness = 0.2;

// Wave Normal Maps
uniform sampler2D normalmap_a : hint_normal;
uniform sampler2D normalmap_b : hint_normal;
uniform float normalmap_a_strength : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float normalmap_b_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform vec2 movement_direction = vec2(0.2, 0.1);
uniform float movement_strength = 0.12;

// UV Settings
uniform float uv_scale = 1.0;

// Texture
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;

// Foam Settings
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_distance : hint_range(0.0, 5.0, 0.05) = 0.5; // How far foam extends from shores
uniform float foam_cutoff : hint_range(0.0, 1.0, 0.01) = 0.4;   // Sharpness cutoff of the foam texture
uniform float foam_scale : hint_range(0.1, 10.0, 0.1) = 2.0;    // Size of the foam pattern

// Depth Value
uniform float depth_distance : hint_range(0.0, 20.0, 0.1) = 4.0;
uniform float beers_law : hint_range(0.0, 20.0, 0.1) = 12.0;
uniform float water_transparency : hint_range(0.0, 1.0, 0.01) = 0.05;

// --- AESTHETIC VINTAGE UNIFORMS (Completely detached from vertex behavior) ---
uniform vec2 pixel_density = vec2(320.0, 240.0);                     // Emulated internal viewport resolution
uniform float color_quantization : hint_range(4.0, 64.0, 1.0) = 32.0; // Retro 15-bit color channel banding

float fresnel(float amount, vec3 normal, vec3 view) {
	return pow((1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0)), amount);
}

void vertex() {
	// Functionality left 100% untouched. No jittering. Smooth 4K transformation.
	VERTEX.y += 0.05*sin(3.0*TIME + 1500.0*VERTEX.x);
	VERTEX.y += 0.02*sin(2.0*TIME + 600.0*VERTEX.z);
}

void fragment() {
	// --- AESTHETIC MODIFICATION 1: Pixel Grid Resolution Mapping ---
	// Quantize the screen space coordinates before sampling textures or calculating depth
	vec2 retro_screen_uv = floor(SCREEN_UV * pixel_density) / pixel_density;

	float basic_fresnel = fresnel(3.0, NORMAL, VIEW);
	
	vec2 uv = UV * uv_scale;
	vec2 uv_movement = movement_direction * TIME * movement_strength;
	
	// Sample normal maps
	vec3 normal_a_tex = texture(normalmap_a, uv + uv_movement).rgb;
	vec3 normal_b_tex = texture(normalmap_b, uv - uv_movement).rgb;
	
	vec3 normalmap = texture(normalmap_a, uv + uv_movement).rgb * normalmap_a_strength;
	normalmap += texture(normalmap_b, uv - uv_movement).rgb * normalmap_b_strength;
	
	// Get Depth and Screen Textures using our vintage pixel grid coordinates
	float depth = textureLod(depth_texture, retro_screen_uv, 0.0).r;
	vec3 screen = textureLod(screen_texture, retro_screen_uv, 0.0).rgb;
	
	// Get Depth in World Position (Y)
	vec3 ndc = vec3(retro_screen_uv * 2.0 - 1.0, depth);
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float depth_texture_y = world.y / world.w;
	float vertex_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	
	// Vertical water thickness (perfectly camera independent)
	float vertical_thickness = vertex_y - depth_texture_y;
	
	// Set Depth Blend and adjust with Beer's Law
	float depth_blend = clamp((vertex_y - depth_texture_y) / depth_distance, 0.0, 1.0);
	depth_blend = exp(-depth_blend * beers_law);
	
	// --- Foam Mask Generation ---
	float shore_mask = 1.0 - clamp(vertical_thickness / foam_distance, 0.0, 1.0);
	
	// Distort the foam UVs using the normal maps
	vec2 foam_uv = uv * foam_scale + (normal_a_tex.xy + normal_b_tex.xy) * 0.05;
	
	// --- FIXED: Stable Foam Pattern Generation ---
	// Removed retro_foam_uv mapping to prevent distance scaling bugs and floating foam
	float foam_noise = texture(normalmap_a, foam_uv + uv_movement).r;
	
	// Combine shoreline proximity with noise to create branching sea-foam structures
	float foam_cutoff_match = step(foam_cutoff, foam_noise * shore_mask);
	float final_foam_mask = foam_cutoff_match * shore_mask;
	
	// Set depth color mix from depth blend and get final color mix using screen texture
	vec3 depth_color = mix(secondary_color, primary_color, depth_blend).rgb;
	vec3 final_color = mix(depth_color.rgb, screen, water_transparency);
	
	// Mix base water color with reflections
	vec3 water_base = mix(final_color, screen, depth_blend * (1.0 - basic_fresnel));
	
	// Overlay Foam onto ALBEDO
	vec3 raw_albedo = mix(water_base, foam_color.rgb, final_foam_mask);
	
	// --- AESTHETIC MODIFICATION 3: Color Quantization (Banding) ---
	// Limits smooth modern blending gradients to a specific stepped count
	ALBEDO = floor(raw_albedo * color_quantization) / color_quantization;
	
	ROUGHNESS = roughness * (1.0 - basic_fresnel);
	NORMAL_MAP = normalmap;
}
