shader_type spatial;

// ---------- Colours (cartoon bands) ----------
uniform vec4 near_color : source_color = vec4(0.12, 0.45, 0.75, 1.0);
uniform vec4 mid_color  : source_color = vec4(0.25, 0.65, 0.88, 1.0);
uniform vec4 far_color  : source_color = vec4(0.60, 0.88, 0.97, 1.0);
uniform float fresnel_power : hint_range(0.5, 10.0) = 5.0;
uniform float band_1 : hint_range(0.0, 1.0) = 0.15;
uniform float band_2 : hint_range(0.0, 1.0) = 0.5;
uniform float band_softness : hint_range(0.001, 0.1) = 0.01;

// ---------- Waves ----------
uniform float wave_height = 0.02;
uniform float wave_speed = 1.0;
uniform float wave_scale = 0.8;

// ---------- Toon lighting ----------
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.1;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.6;
uniform float spec_shininess : hint_range(1.0, 512.0) = 128.0;
uniform float spec_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float spec_strength : hint_range(0.0, 5.0) = 1.5;

// ---------- Transparency ----------
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform float min_alpha : hint_range(0.0, 1.0) = 0.25;
uniform float visibility_depth : hint_range(0.1, 10.0) = 3.0;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale + t * wave_speed) * 0.5
	     + sin(p.y * wave_scale * 1.3 + t * wave_speed * 0.8) * 0.5;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(world.xz, TIME);
	VERTEX.y += h * wave_height;

	// Recalculate the normal so light reacts to the waves
	float e = 0.1;
	float hx = wave(world.xz + vec2(e, 0.0), TIME) - h;
	float hz = wave(world.xz + vec2(0.0, e), TIME) - h;
	NORMAL = normalize(vec3(-hx * wave_height / e, 1.0, -hz * wave_height / e));
}

void fragment() {
	// Colour bands
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float b1 = smoothstep(band_1 - band_softness, band_1 + band_softness, fresnel);
	float b2 = smoothstep(band_2 - band_softness, band_2 + band_softness, fresnel);
	vec3 col = mix(near_color.rgb, mid_color.rgb, b1);
	col = mix(col, far_color.rgb, b2);

	// How far is the thing behind the water?
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;

	// Distance the view ray travels through the water
	float water_thickness = -behind.z - (-VERTEX.z);

	// Transparency
	float t = clamp(water_thickness / visibility_depth, 0.0, 1.0);

	ALBEDO = col;
	ALPHA = mix(min_alpha, 1.0, t);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Lit or shadowed, with a hard edge
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = smoothstep(shadow_threshold - 0.02, shadow_threshold + 0.02, ndl);
	DIFFUSE_LIGHT += mix(shadow_strength, 1.0, lit) * LIGHT_COLOR / PI;

	// Hard-edged sun sparkle
	vec3 half_dir = normalize(LIGHT + VIEW);
	float spec = pow(max(dot(NORMAL, half_dir), 0.0), spec_shininess);
	spec = smoothstep(spec_threshold - 0.02, spec_threshold + 0.02, spec) * lit;
	SPECULAR_LIGHT += spec * spec_strength * LIGHT_COLOR / PI;
}