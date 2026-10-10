shader_type canvas_item;
// Screen-edge vignette in dithered pixel bands: warns about low flame and
// flashes when the lamplighter is hurt.

uniform vec4 tint : source_color = vec4(0.45, 0.05, 0.08, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 resolution = vec2(640.0, 360.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[y * 4 + x] + 0.5) / 16.0;
}

void fragment() {
	vec2 px = floor(UV * resolution);
	vec2 d = (UV - 0.5) * vec2(1.0, resolution.y / resolution.x) * 2.0;
	float edge = smoothstep(0.55, 1.15, length(d));
	float a = edge * intensity;
	a = step(bayer4(px), a * 1.2) * min(1.0, a * 1.6);
	COLOR = vec4(tint.rgb, a);
}
