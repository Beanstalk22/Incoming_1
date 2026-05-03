shader_type spatial;
render_mode blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx;

uniform vec3 water_color : source_color = vec3(0.01, 0.2, 0.4);
uniform vec3 deep_water_color : source_color = vec3(0.0, 0.05, 0.1);
uniform sampler2D depth_texture : hint_depth_texture;

// --- Sailing Illusion Controls ---
uniform vec2 sailing_direction = vec2(0.0, 1.0); 
uniform float sailing_speed = 5.0;                

// Controls for distance smoothing
uniform float far_fade_distance = 500.0;
uniform float wave_speed = 0.2; 

// Wave 1 Settings (Optimized to 2 layers)
uniform float amplitude_a = 0.15;
uniform vec2 direction_a = vec2(1.0, 0.23);
uniform float frequency_a = 0.021;

// Wave 2 Settings
uniform float amplitude_b = 0.35;
uniform vec2 direction_b = vec2(-0.7, 0.91);
uniform float frequency_b = 0.057;

uniform float depth_color_fade = 25.0; 

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Distance factor for fading waves in the distance
	float dist = distance(world_pos, CAMERA_POSITION_WORLD);
	float dist_factor = clamp(1.0 - (dist / far_fade_distance), 0.0, 1.0);
	
	// Sailing illusion: move the "read" position of the waves
	vec2 moving_pos = world_pos.xz + (sailing_direction * TIME * sailing_speed);
	
	// Pre-calculate normalized directions
	vec2 dir_a = normalize(direction_a);
	vec2 dir_b = normalize(direction_b);
	
	// Calculate the wave phases
	float phase_a = dot(moving_pos, dir_a) * frequency_a + (TIME * wave_speed);
	float amp_b_faded = amplitude_b * dist_factor; // Fade out the 2nd wave in the distance
	float phase_b = dot(moving_pos, dir_b) * frequency_b + (TIME * wave_speed * 1.5);
	
	// Single Pass Math: Compute Sine (Height) and Cosine (Derivative/Normal) together
	float sin_a = sin(phase_a);
	float cos_a = cos(phase_a);
	float sin_b = sin(phase_b);
	float cos_b = cos(phase_b);
	
	// 1. Apply Height
	float height = (amplitude_a * sin_a) + (amp_b_faded * sin_b);
	VERTEX.y += height;
	
	// 2. Analytic Normals (Exact slope calculation without sampling height 3 times)
	// dH/dx = Amplitude * direction.x * frequency * cos(phase)
	float dx = (amplitude_a * dir_a.x * frequency_a * cos_a) + (amp_b_faded * dir_b.x * frequency_b * cos_b);
	// dH/dz = Amplitude * direction.y * frequency * cos(phase)
	float dz = (amplitude_a * dir_a.y * frequency_a * cos_a) + (amp_b_faded * dir_b.y * frequency_b * cos_b);
	
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	// 1. Depth Sampling for Color Gradient
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	upos.xyz /= upos.w;
	float depth_diff = max(-upos.z - (-VERTEX.z), 0.0);
	
	// 2. Apply Colors based on Depth
	float depth_f = clamp(depth_diff / depth_color_fade, 0.0, 1.0);
	
	ALBEDO = mix(water_color, deep_water_color, depth_f);
	ALPHA = clamp(depth_f + 0.4, 0.0, 1.0);
	
	// Smooth, reflective surface
	METALLIC = 0.1;
	ROUGHNESS = 0.05; 
	SPECULAR = 0.5;
}