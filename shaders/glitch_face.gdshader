shader_type spatial;
// 글리치 교수 머리: 얼굴 자리가 깨진 화면 노이즈로 일렁인다 (담당 D)
// glow_color = 괴물 상태 색, glitch = 0(잔잔) ~ 1(심하게 찢어짐)
render_mode unshaded, cull_disabled;

uniform vec4 glow_color : source_color = vec4(0.5, 0.1, 0.6, 1.0);
uniform float glitch : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	// 가로 띠 단위로 머리를 옆으로 밀어서 화면이 찢어지는 느낌
	float tick = floor(TIME * 12.0);
	float band = floor(VERTEX.y * 18.0);
	float r = hash(vec2(band, tick));
	float tear = step(1.0 - glitch * 0.45, r);
	VERTEX.x += (r - 0.5) * 0.3 * tear;
	VERTEX.z += (hash(vec2(band, tick + 7.0)) - 0.5) * 0.1 * tear;
}

void fragment() {
	float tick = floor(TIME * 15.0);
	// 큼직한 블록 노이즈 (TV 지지직)
	vec2 cell = floor(UV * vec2(12.0, 16.0));
	float n = hash(cell + vec2(tick, tick * 0.37));
	// 주사선
	float scan = 0.55 + 0.45 * sin(UV.y * 140.0 + TIME * 35.0);
	// 가끔 번쩍이는 가로 띠
	float band_n = hash(vec2(floor(UV.y * 22.0), tick));
	float flash = step(0.9 - glitch * 0.25, band_n);
	// 색 번짐: 채널마다 다른 노이즈
	float nr = hash(cell + vec2(tick + 1.0, 3.0));
	float nb = hash(cell + vec2(tick + 2.0, 5.0));
	vec3 stat = vec3(nr, n, nb) * 0.28 * scan;
	vec3 col = stat + glow_color.rgb * (0.25 + 0.5 * n + flash * (1.2 + glitch));
	ALBEDO = col;
}
