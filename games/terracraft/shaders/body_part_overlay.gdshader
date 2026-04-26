shader_type canvas_item;
// UV rect of the body part to show: (x0, y0, x1, y1) normalised 0..1
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// Colour tint applied to the visible region
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.85);

void fragment() {
	if (UV.x >= region.x && UV.x <= region.z && UV.y >= region.y && UV.y <= region.w) {
		vec4 base = texture(TEXTURE, UV);
		COLOR = vec4(tint.rgb, base.a * tint.a);
	} else {
		COLOR = vec4(0.0);
	}
}
