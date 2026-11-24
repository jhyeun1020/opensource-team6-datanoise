@tool
extends StaticBody3D
## 방 문 (담당 D)
## 경첩(이 노드의 원점)에서 로컬 +x 방향으로 width 만큼 뻗은 한 짝 문. 메시·충돌은 코드로 만든다.
##
## - 플레이어: E로 열고 닫는다. 여닫는 소리가 난다(소음 0.25).
## - 잠긴 문: 열리지 않고 E를 누르면 덜컹거린다(소음 0.35). 괴물이 들을 수 있다.
## - 괴물: 닫힌 문 앞(1.3m)에 오면 문을 거칠게 밀어 연다(소음 0.8).
##   문 충돌은 레이어 3(값 4)에만 있어서 괴물 몸은 문에 걸리지 않는다. 플레이어와 빛·시야 판정은 막는다.

const DOOR_LAYER := 4

@export var width := 1.55
@export var height := 2.2
@export var open_angle_deg := 95.0   # 방 안쪽으로 열리는 방향(부호 포함)
@export var locked := false
@export var open_duration := 0.6

var is_open := false
var _tween: Tween


var prompt_text: String:
	get:
		if locked:
			return "[E]  잠겨 있음"
		return "[E]  문 닫기" if is_open else "[E]  문 열기"


func _ready() -> void:
	add_to_group("room_doors")
	collision_layer = DOOR_LAYER
	collision_mask = 0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.24) if not locked else Color(0.24, 0.22, 0.2)
	mat.roughness = 0.6
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.06)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = Vector3(width * 0.5, height * 0.5, 0.0)
	add_child(mesh)
	var handle := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(0.14, 0.04, 0.16)
	handle.mesh = hbox
	handle.position = Vector3(width - 0.15, 1.0, 0.0)
	add_child(handle)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	col.shape = shape
	col.position = mesh.position
	add_child(col)


func can_interact() -> bool:
	return _tween == null or not _tween.is_running()


func interact(_player: Node) -> void:
	if not can_interact():
		return
	if locked:
		GameManager.emit_noise(global_position, 0.35)  # 덜컹
		# TODO(사운드): 잠긴 문 손잡이 덜컹 소리
		return
	_set_open(not is_open, 0.25)


func _set_open(open: bool, loudness: float) -> void:
	is_open = open
	GameManager.emit_noise(global_position, loudness)
	var target := deg_to_rad(open_angle_deg) if open else 0.0
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", _closed_rot + target, open_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# TODO(사운드): 문 여닫는 소리


var _closed_rot := 0.0


func _enter_tree() -> void:
	_closed_rot = rotation.y


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or is_open or locked:
		return
	var m := GameManager.monster
	if m == null or not m.visible:
		return
	var center := global_transform * Vector3(width * 0.5, 0.0, 0.0)
	var flat := Vector2(m.global_position.x - center.x, m.global_position.z - center.z)
	if flat.length() < 1.3:
		_set_open(true, 0.8)  # 괴물이 문을 밀어젖힌다
		# TODO(사운드/연출): 문이 벽에 쾅 부딪히는 소리
