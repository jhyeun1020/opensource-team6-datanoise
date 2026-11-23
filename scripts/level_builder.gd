@tool
extends Node3D
## 그레이박스 레벨 생성기 (담당 D) — 1주차 프로토타입 전용
##
## 기획안 6p 공간 흐름:
##   01 도입  미디어랩스 입구 → 첫 번째 서버 정제 (안전, 분위기 파악)
##   02 위기  복도 → 서버실 → 두 번째 정제 (괴물 등장, 빛 조절 필요)
##   03 절정  메인 서버실 → 마지막 정제 → 탈출문 개방
##
## @tool 이라서 에디터에서 main.tscn 을 열면 맵이 그대로 보인다(미리보기용, 씬에 저장되지는 않음).
## ROOMS / DOORS 숫자를 바꾸고 저장하면 에디터 뷰가 다시 그려진다.
## 레벨이 코드로 생성되므로 네비메시도 실행 시 베이크한다(에디터에서는 생략).
## 4주차에 실제 모델링된 레벨(.tscn)로 교체할 때는 이 스크립트를 떼고
## NavRegion 아래에 레벨을 넣고 에디터에서 Bake 하면 된다. 문은 Doors 아래(네비메시 제외).

const TOTAL_NODES := 3  # GameManager.TOTAL_NODES 와 같은 값 (에디터에서는 자동로드를 못 쓰므로 복사)

const TerminalScene := preload("res://scenes/terminal.tscn")
const DoorScene := preload("res://scenes/door.tscn")

const WALL_H := 4.0
const WALL_T := 0.3
const DOOR_W := 3.0

# 방 목록: [x_from, x_to, z_half]. x축을 따라 일직선으로 이어진다.
const ROOMS := [
	[0.0, 10.0, 5.0],    # 01 입구 (도입)
	[10.0, 22.0, 2.0],   # 서버 복도
	[22.0, 34.0, 6.0],   # 02 서버실 (위기)
	[34.0, 44.0, 2.0],   # 복도
	[44.0, 60.0, 8.0],   # 03 메인 서버실 (절정)
	[60.0, 64.0, 2.0],   # 탈출 통로
]

# 문이 있는 경계 x → 열리기 위해 필요한 정제 노드 수
const DOORS := { 10: 1, 34: 2, 60: 3 }

@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var doors_root: Node3D = $Doors

var _extras: Node3D  # 조명·탈출 트리거 등 생성물 묶음 (재생성 시 통째로 지우기 위해)
var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _rack_mat: StandardMaterial3D


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		return  # 에디터에서는 미리보기만. 네비메시 베이크·게임 로직은 실행 시에만.

	# 물리 서버에 콜라이더가 등록된 뒤 베이크해야 지오메트리가 잡힌다.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# 값들은 cell_size/cell_height(기본 맵 설정 0.25)의 배수로 맞춘다. 아니면 정밀도 경고가 뜬다.
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh()


## 생성물을 모두 지우고 다시 만든다. 에디터에서 스크립트가 다시 로드될 때 중복 생성을 막는다.
func rebuild() -> void:
	for child in nav_region.get_children():
		child.free()
	for child in doors_root.get_children():
		child.free()
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	_extras = Node3D.new()
	_extras.name = "Generated"
	add_child(_extras)

	_make_materials()
	_build_rooms()
	_place_racks()
	_place_lights()
	_place_doors()
	_place_terminals()
	_place_exit_trigger()


# ---------------------------------------------------------------- 지오메트리

func _make_materials() -> void:
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.16, 0.17, 0.2)
	_floor_mat.roughness = 0.9
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(0.22, 0.23, 0.27)
	_wall_mat.roughness = 0.8
	_rack_mat = StandardMaterial3D.new()
	_rack_mat.albedo_color = Color(0.08, 0.09, 0.11)
	_rack_mat.metallic = 0.7
	_rack_mat.roughness = 0.35


func _build_rooms() -> void:
	for i in ROOMS.size():
		var r: Array = ROOMS[i]
		var x0: float = r[0]
		var x1: float = r[1]
		var half: float = r[2]

		_box(nav_region, Vector3((x0 + x1) * 0.5, -0.1, 0.0),
			Vector3(x1 - x0, 0.2, half * 2.0), _floor_mat)
		_wall_z(half, x0, x1)
		_wall_z(-half, x0, x1)

		if i == 0:
			_wall_x(x0, -half, half)
		if i == ROOMS.size() - 1:
			_wall_x(x1, -half, half)
		else:
			var nxt: Array = ROOMS[i + 1]
			var outer: float = maxf(half, nxt[2])
			var gap: float = DOOR_W * 0.5 if DOORS.has(int(round(x1))) else minf(half, nxt[2])
			_wall_x(x1, gap, outer)
			_wall_x(x1, -outer, -gap)


func _wall_x(x: float, z0: float, z1: float) -> void:
	if z1 - z0 <= 0.001:
		return
	# 문 틈 쪽으로 두께가 번지지 않게 z 길이는 정확히 z1 - z0. 모서리는 _wall_z 쪽이 WALL_T만큼 덮는다.
	_box(nav_region, Vector3(x, WALL_H * 0.5, (z0 + z1) * 0.5),
		Vector3(WALL_T, WALL_H, z1 - z0), _wall_mat)


func _wall_z(z: float, x0: float, x1: float) -> void:
	_box(nav_region, Vector3((x0 + x1) * 0.5, WALL_H * 0.5, z),
		Vector3(x1 - x0 + WALL_T, WALL_H, WALL_T), _wall_mat)


## 서버 랙: 시야를 끊고 동선을 꺾는 장애물. 간격 2.0 이상(괴물 agent_radius 0.6 통과).
func _place_racks() -> void:
	var rack := Vector3(2.0, 2.4, 0.9)
	for x in [25.0, 29.0]:
		for z in [-3.2, 3.2]:
			_box(nav_region, Vector3(x, rack.y * 0.5, z), rack, _rack_mat)
	for x in [47.0, 51.0, 55.0]:
		for z in [-4.5, 4.5]:
			_box(nav_region, Vector3(x, rack.y * 0.5, z), rack, _rack_mat)


func _place_lights() -> void:
	for i in ROOMS.size():
		var r: Array = ROOMS[i]
		var light := OmniLight3D.new()
		var corridor: bool = r[2] <= 2.0
		# 바닥과 벽 윤곽은 보이되 위협은 어둠에 숨을 정도. 플레이테스트 후 조절.
		light.light_color = Color(0.8, 0.12, 0.12) if corridor else Color(0.35, 0.45, 0.7)
		light.light_energy = 0.7 if corridor else 0.6
		light.omni_range = maxf(r[1] - r[0], r[2] * 2.0) * 0.9
		light.shadow_enabled = false
		_extras.add_child(light)
		light.position = Vector3((r[0] + r[1]) * 0.5, 3.6, 0.0)


func _place_doors() -> void:
	for x in DOORS:
		var door := DoorScene.instantiate()
		door.required_nodes = DOORS[x]
		door.is_main_gate = DOORS[x] >= TOTAL_NODES
		doors_root.add_child(door)
		door.position = Vector3(float(x), 0.0, 0.0)


func _place_terminals() -> void:
	# (위치, 화면이 향하는 방향, 노드 번호, 모드)
	_terminal(Vector3(8.0, 0.0, -4.65), Vector3(0, 0, 1), 1, Terminal.Mode.SEQUENCE)
	_terminal(Vector3(32.0, 0.0, 5.65), Vector3(0, 0, -1), 2, Terminal.Mode.PATTERN)
	_terminal(Vector3(52.0, 0.0, 7.65), Vector3(0, 0, -1), 3, Terminal.Mode.SEQUENCE)


func _terminal(pos: Vector3, face_dir: Vector3, index: int, mode: int) -> void:
	var t := TerminalScene.instantiate()
	t.node_index = index
	t.mode = mode
	t.title = "SERVER NODE %02d" % index
	nav_region.add_child(t)
	t.global_position = pos
	t.look_at(pos + face_dir, Vector3.UP)  # 화면(-Z 면)이 face_dir을 향하게


func _place_exit_trigger() -> void:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 3.0, 4.0)
	col.shape = shape
	area.add_child(col)
	_extras.add_child(area)
	area.position = Vector3(62.5, 1.5, 0.0)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_exit_entered)


func _on_exit_entered(body: Node3D) -> void:
	if body == GameManager.player:
		GameManager.win()


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)
	body.position = pos
	return body
