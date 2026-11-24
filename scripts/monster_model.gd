@tool
extends Node3D
## 글리치 교수 모델 (담당 D ↔ B)
## 정장 차림의 마른 사람 실루엣. 팔이 지나치게 길고 고개가 꺾여 있으며,
## 얼굴 자리는 깨진 화면 노이즈(shaders/glitch_face.gdshader)로 일렁인다.
## 특정 인물을 본뜨지 않은 원본 디자인이다. 기본 도형만으로 코드에서 만든다(외부 에셋 없음).
##
## 괴물(monster.gd)이 set_state_look() 으로 상태 색과 글리치 강도를 넘겨준다.
## 걷는 동작은 부모(CharacterBody3D)의 속도를 보고 다리·팔을 흔든다.

const FaceShader := preload("res://shaders/glitch_face.gdshader")

var _suit: StandardMaterial3D
var _shirt: StandardMaterial3D
var _tie: StandardMaterial3D
var _skin: StandardMaterial3D
var _face: ShaderMaterial

var _hips: Array[Node3D] = []      # 다리 회전축 (왼, 오)
var _shoulders: Array[Node3D] = [] # 팔 회전축 (왼, 오)
var _head_pivot: Node3D
var _body: Node3D                   # 몸 전체 (글리치 순간이동 흔들림용)

var _phase := 0.0
var _jitter_t := 0.0
var _frozen := false
var _chasing := false


func _ready() -> void:
	for c in get_children():
		c.free()
	_make_materials()
	_build()


func _make_materials() -> void:
	_suit = StandardMaterial3D.new()
	_suit.albedo_color = Color(0.07, 0.07, 0.08)
	_suit.roughness = 0.85
	_shirt = StandardMaterial3D.new()
	_shirt.albedo_color = Color(0.55, 0.55, 0.52)
	_shirt.roughness = 0.9
	_tie = StandardMaterial3D.new()
	_tie.albedo_color = Color(0.25, 0.03, 0.05)
	_skin = StandardMaterial3D.new()
	_skin.albedo_color = Color(0.42, 0.4, 0.38)
	_skin.roughness = 0.7
	_face = ShaderMaterial.new()
	_face.shader = FaceShader
	_face.set_shader_parameter("glow_color", Color(0.5, 0.1, 0.6))
	_face.set_shader_parameter("glitch", 0.3)


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


## 앞쪽 = -Z (monster.gd 의 look_at 방향). 발바닥 = y 0. 키 약 2.15m.
func _build() -> void:
	_body = _pivot(self, Vector3.ZERO)

	# 다리 (엉덩이 회전축 y 1.0)
	for side in [-1.0, 1.0]:
		var hip := _pivot(_body, Vector3(0.13 * side, 1.0, 0.0))
		_part(hip, Vector3(0.17, 0.95, 0.19), Vector3(0, -0.475, 0), _suit)      # 바지
		_part(hip, Vector3(0.16, 0.08, 0.3), Vector3(0, -0.96, -0.05), _suit)    # 구두
		_hips.append(hip)

	# 몸통: 앞으로 살짝 굽은 상체
	var torso := _pivot(_body, Vector3(0, 1.0, 0))
	torso.rotation.x = deg_to_rad(-8.0)
	_part(torso, Vector3(0.5, 0.8, 0.26), Vector3(0, 0.4, 0), _suit)            # 재킷
	_part(torso, Vector3(0.16, 0.36, 0.02), Vector3(0, 0.6, -0.135), _shirt)    # 셔츠 깃
	_part(torso, Vector3(0.055, 0.34, 0.025), Vector3(0, 0.56, -0.15), _tie)    # 넥타이
	# 목에 건 출입증: 이름 대신 오류 문구
	var badge := _part(torso, Vector3(0.08, 0.11, 0.01), Vector3(0.14, 0.42, -0.14), _shirt)
	var err := Label3D.new()
	err.text = "ERR0R"
	err.font_size = 18
	err.pixel_size = 0.0025
	err.modulate = Color(0.9, 0.1, 0.15)
	err.position = Vector3(0, 0, -0.008)
	err.rotation.y = PI
	badge.add_child(err)

	# 팔: 어깨 회전축에서 무릎 아래까지 늘어지는 지나치게 긴 팔
	for side in [-1.0, 1.0]:
		var sh := _pivot(torso, Vector3(0.31 * side, 0.74, 0.0))
		sh.rotation.z = deg_to_rad(4.0 * side)
		_part(sh, Vector3(0.12, 1.05, 0.13), Vector3(0, -0.525, 0), _suit)      # 소매
		_part(sh, Vector3(0.09, 0.08, 0.1), Vector3(0, -1.09, 0), _skin)        # 손등
		for f in 3:                                                              # 길쭉한 손가락
			_part(sh, Vector3(0.022, 0.2, 0.022), Vector3((f - 1) * 0.028, -1.23, -0.01), _skin)
		_shoulders.append(sh)

	# 목과 머리: 옆으로 꺾인 고개, 얼굴은 노이즈
	_part(torso, Vector3(0.1, 0.14, 0.1), Vector3(0, 0.86, -0.02), _skin)
	_head_pivot = _pivot(torso, Vector3(0, 0.93, -0.03))
	_head_pivot.rotation.z = deg_to_rad(14.0)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.24, 0.3, 0.26)
	hb.subdivide_width = 6
	hb.subdivide_height = 14
	hb.subdivide_depth = 6
	head.mesh = hb
	head.material_override = _face
	head.position = Vector3(0, 0.15, 0)
	_head_pivot.add_child(head)


## 괴물 상태에 따른 모습. color = 상태 색, glitch = 찢어짐 정도.
func set_state_look(color: Color, glitch: float, frozen: bool, chasing: bool) -> void:
	_frozen = frozen
	_chasing = chasing
	if _face:
		_face.set_shader_parameter("glow_color", color)
		_face.set_shader_parameter("glitch", glitch)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _body == null:
		return
	var parent := get_parent() as CharacterBody3D
	var speed := 0.0
	if parent:
		speed = Vector2(parent.velocity.x, parent.velocity.z).length()

	# 걷기: 다리·팔을 엇갈려 흔든다. 빛에 굳으면 그 자세로 멈춘다.
	if not _frozen:
		_phase += delta * speed * 2.4
		var amount := clampf(speed / 3.0, 0.0, 1.0)
		var swing := sin(_phase) * 0.55 * amount
		_hips[0].rotation.x = swing
		_hips[1].rotation.x = -swing
		var reach := -0.5 if _chasing else -0.12   # 추격 중엔 팔을 앞으로 뻗는다
		_shoulders[0].rotation.x = reach - swing * 0.5
		_shoulders[1].rotation.x = reach + swing * 0.5

	# 글리치 순간이동 흔들림: 가끔 몸이 몇 cm 튀었다가 돌아온다 (빛에 굳었을 때 더 자주)
	_jitter_t -= delta
	if _jitter_t <= 0.0:
		var strong := _frozen or _chasing
		_body.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (0.07 if strong else 0.03)
		_head_pivot.rotation.y = randf_range(-0.4, 0.4) if strong else 0.0
		_jitter_t = randf_range(0.04, 0.12) if strong else randf_range(0.2, 0.6)
	elif _jitter_t < 0.03:
		_body.position = Vector3.ZERO
