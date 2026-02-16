shader_type canvas_item;

uniform vec4 deep_color : source_color = vec4(0.05, 0.2, 0.45, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.1, 0.35, 0.6, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.3, 0.55, 0.8, 1.0);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.8;
uniform float wave_scale : hint_range(1.0, 50.0) = 15.0;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.6;

float wave(vec2 uv, float time) {
	float w = sin(uv.x * wave_scale + time * wave_speed) * 0.5 + 0.5;
	w += sin(uv.y * wave_scale * 0.7 + time * wave_speed * 1.3) * 0.3;
	w += sin((uv.x + uv.y) * wave_scale * 0.5 + time * wave_speed * 0.7) * 0.2;
	return w / 1.5;
}

void fragment() {
	float w = wave(UV, TIME);
	vec4 base = mix(deep_color, shallow_color, w);
	if (w > highlight_threshold) {
		float highlight_mix = (w - highlight_threshold) / (1.0 - highlight_threshold);
		base = mix(base, highlight_color, highlight_mix * 0.4);
	}
	COLOR = base;
}
