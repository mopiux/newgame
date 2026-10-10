shader_type canvas_item;
// Per-sprite feedback: white hit flash, coloured tint flash and a dithered
// dissolve used when creatures crumble into embers.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[y * 4 + x] + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, flash_color.rgb, flash * flash_color.a);
	if (dissolve > 0.0) {
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
		float t = bayer4(px) * 0.7 + fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453) * 0.3;
		if (t < dissolve) {
			c.a = 0.0;
		} else if (t < dissolve + 0.12) {
			c.rgb = edge_color.rgb;
		}
	}
	COLOR = c * COLOR;
}
