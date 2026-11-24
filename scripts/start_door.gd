@tool
extends StaticBody3D
## 계단실 → 3층 로비 문 (담당 D)
## 플레이어는 계단실에서 시작하고, 이 문을 E로 열면서 게임이 시작된다.
## 경첩(이 노드의 원점)을 축으로 로비 쪽으로 열린다. 메시와 충돌은 코드로 만든다.

@export var size := Vector3(0.08, 2.2, 1.5)  # 두께, 높이, 폭(경첩에서 +z 방향으로)
@export var open_angle_deg := 95.0
@export var open_duration := 1.2

var prompt_text := "[E]  로비 문 열기"
var is_open := false


func _ready() -> void:
	add_to_group("start_door")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.3, 0.27)
	mat.roughness = 0.6
	mesh.material_override = mat
	mesh.position = Vector3(0.0, size.y * 0.5, size.z * 0.5)
	add_child(mesh)

	var handle := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(0.2, 0.04, 0.14)
	handle.mesh = hbox
	handle.position = Vector3(0.0, 1.0, size.z - 0.15)
	add_child(handle)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = mesh.position
	add_child(col)


func can_interact() -> bool:
	return not is_open


func interact(_player: Node) -> void:
	if is_open:
		return
	is_open = true
	GameManager.emit_noise(global_position, 0.3)  # 문 여는 소리
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(open_angle_deg), open_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# TODO(사운드): 문 여는 소리 (끼익)
