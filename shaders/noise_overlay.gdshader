shader_type canvas_item;

// 화면 전체 디지털 노이즈 (담당 D)
// intensity 0.0 = 깨끗함, 1.0 = 최대 노이즈. noise_overlay.gd가 매 프레임 갱신한다.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float time_scale = 12.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * time_scale);

	// 가로 글리치 띠: 일부 행이 좌우로 밀린다
	float row = floor(uv.y * 40.0);
	float band = step(0.985 - intensity * 0.12, rand(vec2(row, t)));
	uv.x += band * (rand(vec2(t, row)) - 0.5) * 0.08 * intensity;

	// 색수차
	float ca = 0.004 * intensity;
	vec3 col;
	col.r = texture(screen_texture, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_texture, uv).g;
	col.b = texture(screen_texture, uv - vec2(ca, 0.0)).b;

	// 그레인
	float grain = (rand(uv * (t + 1.0)) - 0.5) * 0.35 * intensity;
	col += grain;

	// 스캔라인
	col *= 1.0 - 0.15 * intensity * step(0.5, fract(uv.y * 220.0));

	// 비네트 (가장자리 어둡게)
	float d = distance(uv, vec2(0.5));
	col *= 1.0 - smoothstep(0.45, 0.9, d) * (0.5 + 0.4 * intensity);

	COLOR = vec4(col, 1.0);
}
