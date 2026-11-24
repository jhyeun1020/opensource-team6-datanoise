extends StaticBody3D
## 구역 문 / 메인 게이트 (담당 D)
## 기획안 2p: 노드 3개 정제 → 마지막 탈출문 개방. 구역 문은 required_nodes개 정제 시 열린다.

@export var required_nodes := 1
@export var open_height := 2.7
@export var open_duration := 1.6
@export var is_main_gate := false

@onready var mesh: MeshInstance3D = $MeshInstance3D

var is_open := false
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("doors")
	_mat = mesh.get_surface_override_material(0).duplicate()
	mesh.set_surface_override_material(0, _mat)
	_mat.emission = Color(0.9, 0.15, 0.2)
	GameManager.node_purified.connect(_on_node_purified)


func _on_node_purified(_index: int, count: int) -> void:
	if not is_open and count >= required_nodes:
		open()


func open() -> void:
	is_open = true
	_mat.emission = Color(0.2, 0.9, 0.5)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + open_height, open_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# TODO(사운드/연출): 문 개방음. 메인 게이트는 기획안 6p "강렬한 노이즈와 함께" 연출
