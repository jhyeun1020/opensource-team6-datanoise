extends ColorRect
## 화면 노이즈 강도 제어 (담당 D)
## 기획안 2p·8p: 노드를 정제할수록 화면 노이즈가 줄어든다.
## 추가: 괴물이 가까우면 심해지고, 근처에서 큰 소음이 나면 순간적으로 튄다.

@export var monster_noise_range := 12.0
@export var spike_decay := 1.5

var _spike := 0.0


func _ready() -> void:
	GameManager.noise_emitted.connect(_on_noise)


func _on_noise(pos: Vector3, loudness: float) -> void:
	var p := GameManager.player
	if p and p.global_position.distance_to(pos) < 6.0:
		_spike = maxf(_spike, loudness * 0.6)


func _process(delta: float) -> void:
	_spike = maxf(_spike - spike_decay * delta, 0.0)

	var base := 0.12 + 0.55 * GameManager.noise_level()

	var monster_term := 0.0
	var m := GameManager.monster
	var p := GameManager.player
	if m and p and m.visible:
		var d := m.global_position.distance_to(p.global_position)
		monster_term = clampf(1.0 - d / monster_noise_range, 0.0, 1.0) * 0.6

	var intensity := clampf(base + monster_term + _spike, 0.0, 1.0)
	if GameManager.is_dead:
		intensity = 1.0
	elif GameManager.has_won:
		intensity = 0.0
	(material as ShaderMaterial).set_shader_parameter("intensity", intensity)
