shader_type canvas_item;
// Darkness overlay: multiplies the scene by a cold ambient tint and lifts it
// towards warm light near LightEmitters. Light is quantised in bands with a
// 4x4 Bayer dither so it reads as pixel art rather than a smooth gradient.
render_mode blend_mul, unshaded;

const int MAX_LIGHTS = 64;

uniform int light_count = 0;
uniform vec4 lights[MAX_LIGHTS];        // xy world pos, z radius, w energy
uniform vec4 light_colors[MAX_LIGHTS];  // rgb tint
uniform vec3 dark_color : source_color = vec3(0.07, 0.065, 0.14);
uniform float ambient = 0.0;
uniform float bands = 5.0;
uniform float dither_strength = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = y * 4 + x;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec2 p = floor(world_pos) + 0.5;
	float total = ambient;
	vec3 tint = vec3(0.0);
	float tint_w = 0.0;
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 L = lights[i];
		float a = clamp(1.0 - distance(p, L.xy) / max(L.z, 0.001), 0.0, 1.0);
		a = a * a * (3.0 - 2.0 * a) * L.w;
		total += a;
		if (a > 0.0) {
			tint += light_colors[i].rgb * a;
			tint_w += a;
		}
	}
	total = clamp(total, 0.0, 1.0);
	float lvl = clamp(total + bayer4(p) * dither_strength / bands, 0.0, 1.0);
	lvl = floor(lvl * bands + 0.5) / bands;
	vec3 warm = tint_w > 0.0 ? tint / tint_w : vec3(1.0);
	// near-full light keeps true colours; the warm tint is strongest mid-range
	vec3 lit = mix(warm, vec3(1.0), smoothstep(0.75, 1.0, lvl) * 0.5);
	COLOR = vec4(mix(dark_color, lit, lvl), 1.0);
}
