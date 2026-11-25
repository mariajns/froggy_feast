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
uniform float wave_time = -1.0;

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

// ---------- Foam ----------
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float foam_width : hint_range(0.0, 0.5) = 0.08;
uniform float foam_softness : hint_range(0.001, 0.1) = 0.01;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform float foam_noise_scale = 0.5;
uniform float foam_speed = 0.05;

// ---------- Squiggle lines ----------
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_scale = 0.15;
uniform vec2 line_stretch = vec2(3.0, 1.0);
uniform float line_width : hint_range(0.0, 0.1) = 0.015;
uniform float line_speed = 0.03;
uniform float mask_scale = 0.08;
uniform float mask_threshold : hint_range(0.0, 1.0) = 0.6;
uniform float line_fade_start = 8.0;
uniform float line_fade_end = 20.0;

float wave(vec2 p, float t) {
	return sin(p.x * wave_scale + t * wave_speed) * 0.5
	     + sin(p.y * wave_scale * 1.3 + t * wave_speed * 0.8) * 0.5;
}

void vertex() {
	// Use the script's time when it's set, otherwise the built-in TIME
	float t = wave_time < 0.0 ? TIME : wave_time;

	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave(world.xz, t);
	VERTEX.y += h * wave_height;

	float e = 0.1;
	float hx = wave(world.xz + vec2(e, 0.0), t) - h;
	float hz = wave(world.xz + vec2(0.0, e), t) - h;
	NORMAL = normalize(vec3(-hx * wave_height / e, 1.0, -hz * wave_height / e));
}

void fragment() {
	// Colour bands
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	float b1 = smoothstep(band_1 - band_softness, band_1 + band_softness, fresnel);
	float b2 = smoothstep(band_2 - band_softness, band_2 + band_softness, fresnel);
	vec3 col = mix(near_color.rgb, mid_color.rgb, b1);
	col = mix(col, far_color.rgb, b2);

	// Positions
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;
	vec3 behind_world  = (INV_VIEW_MATRIX * vec4(behind.xyz, 1.0)).xyz;
	vec3 surface_world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Transparency
	float water_thickness = -behind.z - (-VERTEX.z);
	float t = clamp(water_thickness / visibility_depth, 0.0, 1.0);
	float alpha = mix(min_alpha, 1.0, t);

	// Squiggle lines
	vec2 line_uv = surface_world.xz * line_stretch * line_scale + vec2(0.0, TIME * line_speed);
	float ln = texture(foam_noise, line_uv).r;
	float d = abs(ln - 0.5);
	float aa = fwidth(ln) + 0.001;
	float lines = 1.0 - smoothstep(line_width, line_width + aa, d);

	float m = texture(foam_noise, surface_world.xz * mask_scale + vec2(0.37, 0.71) - TIME * line_speed * 0.5).r;
	lines *= smoothstep(mask_threshold - 0.02, mask_threshold + 0.02, m);
	lines *= 1.0 - smoothstep(line_fade_start, line_fade_end, -VERTEX.z);

	col = mix(col, line_color.rgb, lines);
	alpha = max(alpha, lines);

	// Foam
	float vertical_depth = surface_world.y - behind_world.y;
	float foam_gradient = 1.0 - clamp(vertical_depth / foam_width, 0.0, 1.0);
	float n = texture(foam_noise, surface_world.xz * foam_noise_scale + TIME * foam_speed).r;
	float foam = smoothstep(n - foam_softness, n + foam_softness, foam_gradient);

	col = mix(col, foam_color.rgb, foam);
	alpha = max(alpha, foam);

	ALBEDO = col;
	ALPHA = alpha;
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