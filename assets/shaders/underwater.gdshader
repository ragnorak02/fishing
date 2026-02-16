shader_type canvas_item;

uniform vec4 water_tint : source_color = vec4(0.05, 0.15, 0.35, 1.0);
uniform vec4 deep_tint : source_color = vec4(0.02, 0.05, 0.15, 1.0);
uniform float depth_factor : hint_range(0.0, 1.0) = 0.0;
uniform float caustic_speed : hint_range(0.1, 2.0) = 0.5;
uniform float caustic_scale : hint_range(1.0, 30.0) = 10.0;
uniform float caustic_intensity : hint_range(0.0, 0.5) = 0.15;

float caustic(vec2 uv, float time) {
	float c = sin(uv.x * caustic_scale + time * caustic_speed) *
			  cos(uv.y * caustic_scale * 0.8 + time * caustic_speed * 1.2);
	c += sin((uv.x + uv.y) * caustic_scale * 0.6 + time * caustic_speed * 0.8) * 0.5;
	return c * 0.5 + 0.5;
}

void fragment() {
	vec4 base = mix(water_tint, deep_tint, depth_factor);
	float c = caustic(UV, TIME) * caustic_intensity;
	base.rgb += vec3(c * 0.3, c * 0.5, c * 0.7);
	COLOR = base;
}
