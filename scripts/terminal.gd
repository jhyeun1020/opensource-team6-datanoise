class_name Terminal
extends StaticBody3D
## 서버 터미널 (담당 C ↔ D 접점)
## 플레이어가 E로 상호작용하면 정제 미니게임을 시작시키고, 성공하면 노드 정제 완료를 알린다.
## 기획안 5p: 입력 방식은 "순서 입력" / "패턴 대조" 두 가지. mode로 선택.

enum Mode { SEQUENCE, PATTERN }

@export var node_index := 1
@export var mode: Mode = Mode.SEQUENCE
@export var title := "SERVER NODE 01"

@onready var screen: MeshInstance3D = $Screen
@onready var label: Label3D = $Label3D
@onready var light: OmniLight3D = $OmniLight3D

var purified := false

var _screen_mat: StandardMaterial3D
var _flicker_t := 0.0


func _ready() -> void:
	add_to_group("terminals")
	label.text = title
	_screen_mat = screen.get_surface_override_material(0).duplicate()
	screen.set_surface_override_material(0, _screen_mat)
	_set_screen_color(Color(0.9, 0.2, 0.3))
	GameManager.minigame_finished.connect(_on_minigame_finished)


func can_interact() -> bool:
	return not purified and not GameManager.in_minigame


## 플레이어의 InteractRay가 이 노드를 보고 E를 누르면 호출된다.
func interact(_player: Node) -> void:
	if not can_interact():
		return
	GameManager.emit_noise(global_position, 0.6)  # 터미널 기동음: 괴물이 이쪽으로 조사하러 온다
	GameManager.start_minigame(self)


func _on_minigame_finished(terminal: Node, success: bool) -> void:
	if terminal != self or not success:
		return
	purified = true
	_set_screen_color(Color(0.2, 0.9, 0.5))
	label.text = title + "\nPURIFIED"
	GameManager.purify_node(node_index)
	# TODO(사운드/연출): 정제 완료 사운드, 화면 노이즈 걷히는 연출


func _process(delta: float) -> void:
	if purified:
		light.light_color = Color(0.3, 1.0, 0.6)
		light.light_energy = 0.8
		return
	# 정제 전: 불안하게 깜빡이는 화면 빛
	_flicker_t += delta
	light.light_energy = 0.3 + 0.5 * absf(sin(_flicker_t * 13.0)) * randf()


func _set_screen_color(c: Color) -> void:
	_screen_mat.emission = c
	_screen_mat.albedo_color = c * 0.1
