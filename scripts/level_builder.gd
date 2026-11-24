@tool
extends Node3D
## 레벨 생성기 (담당 D) — 미디어랩스 3층 평면
##
## 평면은 팀원이 그린 3층 스케치(reference/measurements/3층_평면도_스케치.webp)를 따르고,
## 치수는 Polycam 스캔 실측값(복도 안쪽 폭 2.5m, 천장 2.7m, 실습실 7.5 x 14m)을 쓴다.
##
## 좌표: x = 복도를 따라 서쪽(0) → 동쪽, z = 위쪽(-, 스케치 위) / 아래쪽(+, 스케치 아래). 단위 m.
##
## 게임 흐름 (기획안 6p를 실제 층 구조에 맞춤):
##   시작   계단실에서 로비 문(E)을 열고 3층으로 들어간다
##   01 도입  서쪽 구역은 처음부터 열려 있다. 서버실에서 노드 1 정제 → 방화셔터 1 개방, 괴물 활성화
##   02 위기  셔터 1 동쪽. ML314 강의실에서 노드 2 정제 → 방화셔터 2 개방
##   03 절정  홀·학회실. 학회실에서 노드 3 정제 → 홀 엘리베이터(메인 게이트) 개방 → 탈출
##   오른쪽 아래 사선 복도 끝은 무너진 잔해로 막혀 있다 (출입 금지)
##
## @tool 이라 에디터에서 main.tscn 을 열면 맵이 그대로 보인다. 숫자를 고치고 저장하면 다시 그려진다.
## 문·셔터는 Doors 아래에 두어 네비메시에서 제외한다 (닫힌 셔터 자리를 괴물이 지나갈 수 있게).

const TOTAL_NODES := 3  # GameManager.TOTAL_NODES 와 같은 값 (에디터에서는 자동로드를 못 쓰므로 복사)

const TerminalScene := preload("res://scenes/terminal.tscn")
const DoorScene := preload("res://scenes/door.tscn")
const StartDoorScript := preload("res://scripts/start_door.gd")

const WALL_H := 2.7
const WALL_T := 0.3
const CORR := 1.4          # 복도 벽 중심까지 거리. 안쪽 폭 = 2 * CORR - WALL_T = 2.5m
const DOOR_GAP := 1.6      # 방 출입구 폭 (괴물 반지름 0.5가 지나갈 수 있게)
const DOOR_H := 2.2        # 출입구 높이. 그 위는 인방(벽 조각)으로 막는다
const CORRIDOR_END := 67.0 # 직선 복도가 홀로 열리는 x

# 방 크기 등급 (사용자 지정: 강의실(ML) > 학회실 > 교수실·회의실·랩실·서버실)
const NORMAL_DEPTH := 6.0  # 일반 방: 폭 6m x 깊이 6m
const ML_DEPTH := 8.0      # 강의실: 폭 14m x 깊이 8m

# 복도에 붙은 방. side -1 = 위쪽(z-), +1 = 아래쪽(z+). doors = 출입구 중심 x.
# open = 들어갈 수 있는 방. 잠긴 방은 문만 붙어 있고 바닥 충돌이 없다.
const ROOMS := [
	# 위쪽 (스케치 윗줄, 서→동)
	{"name": "교수연구실", "x0": 1.0, "x1": 7.0, "side": -1, "depth": NORMAL_DEPTH, "doors": [4.0], "open": false},
	{"name": "교수연구실", "x0": 8.0, "x1": 14.0, "side": -1, "depth": NORMAL_DEPTH, "doors": [11.0], "open": false},
	{"name": "교수연구실", "x0": 16.0, "x1": 22.0, "side": -1, "depth": NORMAL_DEPTH, "doors": [19.0], "open": false},
	{"name": "교수연구실", "x0": 24.0, "x1": 30.0, "side": -1, "depth": NORMAL_DEPTH, "doors": [27.0], "open": false},
	{"name": "ML313", "x0": 33.0, "x1": 47.0, "side": -1, "depth": ML_DEPTH, "doors": [34.6, 45.4], "open": true, "desks": true},
	{"name": "ML314", "x0": 51.0, "x1": 65.0, "side": -1, "depth": ML_DEPTH, "doors": [52.6, 63.4], "open": true, "desks": true},
	# 아래쪽 (스케치 아랫줄, 서→동)
	{"name": "회의실", "x0": 0.0, "x1": 6.0, "side": 1, "depth": NORMAL_DEPTH, "doors": [3.0], "open": false},
	{"name": "랩실", "x0": 8.0, "x1": 14.0, "side": 1, "depth": NORMAL_DEPTH, "doors": [11.0], "open": false},
	{"name": "ML304", "x0": 16.0, "x1": 30.0, "side": 1, "depth": ML_DEPTH, "doors": [17.6, 28.4], "open": true, "desks": true},
	{"name": "서버실", "x0": 30.7, "x1": 36.7, "side": 1, "depth": NORMAL_DEPTH, "doors": [33.7], "open": true, "racks": true},
	{"name": "랩실", "x0": 49.0, "x1": 55.0, "side": 1, "depth": NORMAL_DEPTH, "doors": [52.0], "open": true, "tables": true},
	{"name": "랩실", "x0": 58.0, "x1": 64.0, "side": 1, "depth": NORMAL_DEPTH, "doors": [61.0], "open": false},
]

# 아래쪽 로비 (계단실 문 + 엘리베이터). 복도 아래 벽이 이 구간에서 열린다.
const LOBBY := {"x0": 40.0, "x1": 47.0, "z1": 8.0}
# 계단실: 플레이어 시작 지점. 로비 서쪽 벽의 문으로 들어간다.
const STAIR := {"x0": 37.0, "x1": 40.0, "z0": 3.0, "z1": 8.0}
const START_DOOR_Z := 5.0  # 로비 문 경첩 위치 (문은 +z 쪽으로 1.5m)

# 동쪽: 홀(엘리베이터, 기둥), 학회실, 사선 복도
const HALL_TOP := -10.0
const ACAD := [Vector2(73.5, -10.0), Vector2(83.0, -10.0), Vector2(84.6, -8.2), Vector2(78.71, 1.56), Vector2(73.5, -6.5)]  # 학회실 다각형
const DIAG_ANGLE_DEG := 35.0   # 사선 복도 방향 (스케치 오른쪽 아래)
const DIAG_LOWER_START := Vector2(71.5, CORR)  # 사선 복도 아래 벽 시작
const DIAG_WIDTH := 4.0
const DIAG_LENGTH := 16.0
const ELEVATOR_X := Vector2(68.4, 70.6)  # 탈출 엘리베이터 칸 (홀 위쪽 벽)

# 진행 문: (위치, y회전, 크기, 필요 정제 수)
#   방화셔터 1: 로비 동쪽 복도 / 방화셔터 2: ML314 지나 홀 앞 / 메인 게이트: 홀 엘리베이터
const GATES := [
	{"pos": Vector3(48.0, 0, 0), "rot": 0.0, "size": Vector3(0.3, WALL_H, 2.9), "required": 1},
	{"pos": Vector3(66.0, 0, 0), "rot": 0.0, "size": Vector3(0.3, WALL_H, 2.9), "required": 2},
	{"pos": Vector3(69.5, 0, HALL_TOP), "rot": PI / 2, "size": Vector3(0.3, WALL_H, 2.3), "required": 3},
]

# 스모크 테스트가 쓰는 좌표
const START_POS := Vector3(38.6, 0.1, 5.75)
const EXIT_POS := Vector3(69.5, 0.1, -11.2)
const FREEZE_TEST_POS := Vector3(5.0, 0.1, 0.0)  # 장애물 없는 서쪽 직선 복도, +x를 보고 선다
const NAV_TEST_POINTS := [
	Vector3(1.5, 0, 0), Vector3(38.5, 0, 6.5), Vector3(33.7, 0, 4.0), Vector3(40.0, 0, -5.4),
	Vector3(23.0, 0, 5.4), Vector3(50.0, 0, 4.4), Vector3(58.0, 0, -5.4), Vector3(70.0, 0, -6.0),
	Vector3(81.0, 0, -8.0), Vector3(82.0, 0, 6.3), Vector3(69.5, 0, -11.2),
]

@onready var nav_region: NavigationRegion3D = $NavRegion
@onready var doors_root: Node3D = $Doors

var _extras: Node3D  # 조명·표지판·탈출 트리거 등 (재생성 시 통째로 지우기 위해)
var _floor_mat: StandardMaterial3D
var _locked_floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _rack_mat: StandardMaterial3D
var _desk_mat: StandardMaterial3D
var _door_mat: StandardMaterial3D
var _metal_mat: StandardMaterial3D
var _debris_mat: StandardMaterial3D


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
	_build_corridor()
	_build_rooms()
	_build_lobby_and_stairs()
	_build_east()
	_place_gates()
	_place_terminals()
	_place_lights()
	_place_exit_trigger()


# ---------------------------------------------------------------- 재질

func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _make_materials() -> void:
	_floor_mat = _mat(Color(0.16, 0.17, 0.2), 0.9)
	_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # 다각형 바닥은 감기 방향과 무관하게 보이게
	_locked_floor_mat = _mat(Color(0.07, 0.07, 0.08), 1.0)
	_locked_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_mat = _mat(Color(0.22, 0.23, 0.27))
	_rack_mat = _mat(Color(0.08, 0.09, 0.11), 0.35, 0.7)
	_desk_mat = _mat(Color(0.28, 0.29, 0.31), 0.7)
	_door_mat = _mat(Color(0.3, 0.27, 0.24), 0.6)
	_metal_mat = _mat(Color(0.35, 0.36, 0.38), 0.3, 0.8)
	_debris_mat = _mat(Color(0.18, 0.16, 0.14), 1.0)


# ---------------------------------------------------------------- 복도

func _build_corridor() -> void:
	_floor_rect(0.0, CORRIDOR_END, -CORR, CORR, true)
	_wall_seg(Vector2(0, -CORR), Vector2(0, CORR))  # 서쪽 끝

	var upper_gaps: Array = []
	var lower_gaps: Array = []
	for r in ROOMS:
		if not r.open:
			continue
		for dx in r.doors:
			var gap := [dx - DOOR_GAP * 0.5, dx + DOOR_GAP * 0.5]
			if r.side < 0:
				upper_gaps.append(gap)
			else:
				lower_gaps.append(gap)
	lower_gaps.append([LOBBY.x0, LOBBY.x1])
	_wall_seg(Vector2(0, -CORR), Vector2(CORRIDOR_END, -CORR), upper_gaps)
	_wall_seg(Vector2(0, CORR), DIAG_LOWER_START, lower_gaps)


# ---------------------------------------------------------------- 방

func _build_rooms() -> void:
	for r in ROOMS:
		var s: float = r.side
		var depth: float = r.depth
		var z_in := s * CORR
		var z_back := s * (CORR + depth)
		_wall_seg(Vector2(r.x0, z_in), Vector2(r.x0, z_back))
		_wall_seg(Vector2(r.x1, z_in), Vector2(r.x1, z_back))
		_wall_seg(Vector2(r.x0, z_back), Vector2(r.x1, z_back))
		_floor_rect(r.x0, r.x1, minf(z_in, z_back), maxf(z_in, z_back), r.open)
		for dx in r.doors:
			# 복도 쪽 벽면에 붙는 표지판 (복도를 바라본다)
			var face_z := s * (CORR - WALL_T * 0.5 - 0.02)
			var rot := 0.0 if s < 0 else PI
			_sign(r.name, Vector3(dx, 2.3, face_z), rot)
			if not r.open:
				_door_panel(Vector3(dx, 0, s * (CORR - WALL_T * 0.5 - 0.03)), rot, 1.0)
		if r.get("desks", false):
			_place_desks(r)
		if r.get("racks", false):
			_place_server_racks(r)
		if r.get("tables", false):
			var zc := s * (CORR + depth * 0.5)
			_box(nav_region, Vector3((r.x0 + r.x1) * 0.5, 0.375, zc - 1.05), Vector3(2.4, 0.75, 0.8), _desk_mat)
			_box(nav_region, Vector3((r.x0 + r.x1) * 0.5, 0.375, zc + 1.05), Vector3(2.4, 0.75, 0.8), _desk_mat)


## 강의실 책상: 앞(동쪽)을 보는 줄 4개, 줄마다 가운데 통로를 두고 2블록.
## 통로가 1.4m 아래로 좁으면 괴물(반지름 0.5) 네비메시가 끊긴다.
func _place_desks(r: Dictionary) -> void:
	var s: float = r.side
	var depth: float = r.depth
	var inner := depth - WALL_T
	var z_mid := s * (CORR + depth * 0.5)
	var aisle := 1.8  # 가운데 통로
	var block := (inner - aisle - 2.0 * 1.45) * 0.5  # 벽 쪽 통로 1.45m
	for i in 4:
		var x: float = r.x0 + 3.0 + i * 2.5
		for k in [-1, 1]:
			var zc: float = z_mid + k * (aisle * 0.5 + block * 0.5)
			_box(nav_region, Vector3(x, 0.375, zc), Vector3(0.7, 0.75, block), _desk_mat)


## 서버실 랙: 양쪽 벽을 따라 2개씩.
func _place_server_racks(r: Dictionary) -> void:
	var s: float = r.side
	for x in [r.x0 + 0.6, r.x1 - 0.6]:
		for zc in [CORR + 1.8, CORR + 4.0]:
			_box(nav_region, Vector3(x, 1.1, s * zc), Vector3(0.9, 2.2, 2.0), _rack_mat)


# ---------------------------------------------------------------- 로비 · 계단실

func _build_lobby_and_stairs() -> void:
	# 로비
	_floor_rect(LOBBY.x0, LOBBY.x1, CORR, LOBBY.z1, true)
	var door_gap := [START_DOOR_Z, START_DOOR_Z + 1.5]  # z 좌표
	_wall_seg(Vector2(LOBBY.x0, CORR), Vector2(LOBBY.x0, LOBBY.z1), [door_gap])
	_wall_seg(Vector2(LOBBY.x0, LOBBY.z1), Vector2(LOBBY.x1, LOBBY.z1))
	_wall_seg(Vector2(LOBBY.x1, CORR), Vector2(LOBBY.x1, LOBBY.z1))
	# 로비 엘리베이터 (작동 안 함, 장식)
	var ex := LOBBY.x1 - WALL_T * 0.5 - 0.04
	_box(_extras, Vector3(ex, 1.1, 4.6), Vector3(0.08, 2.2, 1.6), _metal_mat, false)
	_sign("엘리베이터\n점검 중", Vector3(ex - 0.02, 2.4, 4.6), -PI / 2)
	_sign("계단", Vector3(LOBBY.x0 + WALL_T * 0.5 + 0.02, 2.3, START_DOOR_Z + 0.75), PI / 2)

	# 계단실
	_floor_rect(STAIR.x0, STAIR.x1, STAIR.z0, STAIR.z1, true)
	_wall_seg(Vector2(STAIR.x0, STAIR.z0), Vector2(STAIR.x0, STAIR.z1))
	_wall_seg(Vector2(STAIR.x0, STAIR.z0), Vector2(STAIR.x1, STAIR.z0))
	_wall_seg(Vector2(STAIR.x0, STAIR.z1), Vector2(STAIR.x1, STAIR.z1))
	# 위층으로 올라가는 계단 (장식, 막혀 있음)
	for i in 4:
		var h := 0.18 * (i + 1)
		_box(nav_region, Vector3((STAIR.x0 + STAIR.x1) * 0.5, h * 0.5, STAIR.z0 + 1.55 - i * 0.35),
			Vector3(STAIR.x1 - STAIR.x0 - WALL_T, h, 0.35), _wall_mat)
	# 로비 문 (경첩이 원점, +z 쪽으로 1.5m. 로비(+x)쪽으로 열린다)
	var door := StaticBody3D.new()
	door.set_script(StartDoorScript)
	door.name = "StartDoor"
	doors_root.add_child(door)
	door.position = Vector3(LOBBY.x0, 0.0, START_DOOR_Z)


# ---------------------------------------------------------------- 동쪽: 홀 · 학회실 · 사선 복도

func _diag_dir() -> Vector2:
	var a := deg_to_rad(DIAG_ANGLE_DEG)
	return Vector2(cos(a), sin(a))


func _diag_up() -> Vector2:
	# 사선 복도의 위쪽(학회실 쪽) 방향
	var d := _diag_dir()
	return Vector2(d.y, -d.x)


func _build_east() -> void:
	var d := _diag_dir()
	var up := _diag_up()
	var lower0: Vector2 = DIAG_LOWER_START
	var upper0: Vector2 = lower0 + up * DIAG_WIDTH
	var tip: Vector2 = ACAD[3]
	var lower_end: Vector2 = lower0 + d * DIAG_LENGTH
	var upper_end: Vector2 = upper0 + d * DIAG_LENGTH

	# 바닥: 홀 + 교차 지점 + 사선 복도를 한 다각형으로
	_floor_poly(PackedVector2Array([
		Vector2(CORRIDOR_END, HALL_TOP), Vector2(ACAD[0].x, HALL_TOP), ACAD[4], tip,
		upper_end, lower_end, lower0, Vector2(CORRIDOR_END, CORR)]))
	# 학회실 바닥
	_floor_poly(PackedVector2Array(ACAD))

	# 홀 서쪽 벽, 홀+학회실 윗벽 (엘리베이터 칸 자리만 뚫림)
	_wall_seg(Vector2(CORRIDOR_END, -CORR), Vector2(CORRIDOR_END, HALL_TOP))
	_wall_seg(Vector2(CORRIDOR_END, HALL_TOP), ACAD[1], [[ELEVATOR_X.x, ELEVATOR_X.y]])
	# 엘리베이터 칸
	var ez := HALL_TOP - 2.2
	_floor_rect(ELEVATOR_X.x, ELEVATOR_X.y, ez, HALL_TOP, true)
	_wall_seg(Vector2(ELEVATOR_X.x, HALL_TOP), Vector2(ELEVATOR_X.x, ez))
	_wall_seg(Vector2(ELEVATOR_X.y, HALL_TOP), Vector2(ELEVATOR_X.y, ez))
	_wall_seg(Vector2(ELEVATOR_X.x, ez), Vector2(ELEVATOR_X.y, ez))
	_sign("엘리베이터", Vector3((ELEVATOR_X.x + ELEVATOR_X.y) * 0.5, 2.45, HALL_TOP + WALL_T * 0.5 + 0.02), 0.0)
	# 기둥
	_box(nav_region, Vector3(71.2, WALL_H * 0.5, -2.6), Vector3(0.8, WALL_H, 0.8), _wall_mat)

	# 학회실 벽 (서쪽 아래 사선 벽 가운데에 출입구)
	_wall_seg(ACAD[0], ACAD[4])
	_wall_seg(ACAD[1], ACAD[2])
	_wall_seg(ACAD[2], tip)
	var sw_len := ACAD[4].distance_to(tip)
	# 사선 벽은 네비메시 격자에 계단처럼 잡혀 실제 통로가 좁아지므로 출입구를 넓게 둔다
	var acad_gap := DOOR_GAP + 0.6
	_wall_seg(ACAD[4], tip, [[sw_len * 0.5 - acad_gap * 0.5, sw_len * 0.5 + acad_gap * 0.5]])
	var sw_dir: Vector2 = (tip - ACAD[4]).normalized()
	var sw_mid: Vector2 = ACAD[4] + sw_dir * (sw_len * 0.5)
	var sw_out := Vector2(-sw_dir.y, sw_dir.x)  # 홀 쪽
	var sign_pos: Vector2 = sw_mid + sw_dir * (acad_gap * 0.5 + 0.6) + sw_out * (WALL_T * 0.5 + 0.02)
	_sign("학회실", Vector3(sign_pos.x, 2.3, sign_pos.y), _face_rot(sw_out))
	# 학회실 회의 탁자
	_box(nav_region, Vector3(78.5, 0.375, -6.0), Vector3(3.0, 0.75, 1.0), _desk_mat)

	# 사선 복도 벽
	_wall_seg(lower0, lower_end)
	_wall_seg(tip, upper_end)
	# 사선 복도 끝의 랩실 (잠김)
	var a: Vector2 = upper0 + d * 11.0
	var b: Vector2 = upper0 + d * 15.0
	var a2: Vector2 = a + up * NORMAL_DEPTH * 0.85
	var b2: Vector2 = b + up * NORMAL_DEPTH * 0.85
	_wall_seg(a, a2)
	_wall_seg(a2, b2)
	_wall_seg(b2, b)
	_floor_poly(PackedVector2Array([a, b, b2, a2]), false)
	var lab_door: Vector2 = upper0 + d * 13.0 - up * (WALL_T * 0.5 + 0.03)
	_door_panel(Vector3(lab_door.x, 0, lab_door.y), _face_rot(-up), 1.0)
	_sign("랩실", Vector3(lab_door.x, 2.3, lab_door.y) + Vector3(-up.x, 0, -up.y) * 0.02, _face_rot(-up))

	# 사선 복도 끝: 무너진 잔해로 막힘 (스케치의 낙서 구역, 접근 금지)
	_wall_seg(lower_end, upper_end)
	var mid: Vector2 = (lower_end + upper_end) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var p: Vector2 = mid - d * rng.randf_range(0.5, 1.6) + up * rng.randf_range(-1.6, 1.6)
		var s := Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.4, 1.6), rng.randf_range(0.5, 1.2))
		var body := _box(nav_region, Vector3(p.x, s.y * 0.5, p.y), s, _debris_mat)
		body.rotation.y = rng.randf_range(0, PI)
	var warn: Vector2 = mid - d * (WALL_T * 0.5 + 0.02)
	_sign("출입 금지", Vector3(warn.x, 2.1, warn.y), _face_rot(-d))


## 표지판·문짝이 normal 방향(2D, x-z)을 바라보게 하는 y 회전. Label3D 앞면은 +z.
func _face_rot(normal: Vector2) -> float:
	return atan2(normal.x, normal.y)


# ---------------------------------------------------------------- 진행 문 · 터미널

func _place_gates() -> void:
	for g in GATES:
		var door := DoorScene.instantiate()
		door.required_nodes = g.required
		door.is_main_gate = g.required >= TOTAL_NODES
		door.size = g.size
		doors_root.add_child(door)
		door.position = g.pos
		door.rotation.y = g.rot
		if not door.is_main_gate:
			_sign("방화셔터", g.pos + Vector3(-0.2, 2.55, 0), -PI / 2)


func _place_terminals() -> void:
	# (위치, 화면이 향하는 방향, 노드 번호, 모드). 벽에 등을 붙인다.
	_terminal(Vector3(33.7, 0.0, 6.9), Vector3(0, 0, -1), 1, Terminal.Mode.SEQUENCE)   # 서버실
	_terminal(Vector3(64.5, 0.0, -5.4), Vector3(-1, 0, 0), 2, Terminal.Mode.PATTERN)   # ML314 교탁 자리
	_terminal(Vector3(79.0, 0.0, -9.5), Vector3(0, 0, 1), 3, Terminal.Mode.SEQUENCE)   # 학회실


func _terminal(pos: Vector3, face_dir: Vector3, index: int, mode: int) -> void:
	var t := TerminalScene.instantiate()
	t.node_index = index
	t.mode = mode
	t.title = "SERVER NODE %02d" % index
	nav_region.add_child(t)
	t.global_position = pos
	t.look_at(pos + face_dir, Vector3.UP)  # 화면(-Z 면)이 face_dir을 향하게


func _place_lights() -> void:
	var corridor_red := Color(0.8, 0.12, 0.12)
	var room_blue := Color(0.35, 0.45, 0.7)
	for x in range(4, int(CORRIDOR_END), 8):
		_light(Vector3(x, WALL_H - 0.3, 0), corridor_red, 0.6, 7.0)
	for r in ROOMS:
		if r.open:
			var zc: float = r.side * (CORR + r.depth * 0.5)
			_light(Vector3((r.x0 + r.x1) * 0.5, WALL_H - 0.3, zc), room_blue, 0.6, maxf(r.x1 - r.x0, r.depth) * 0.8)
	_light(Vector3((LOBBY.x0 + LOBBY.x1) * 0.5, WALL_H - 0.3, 5.0), room_blue, 0.5, 7.0)
	_light(Vector3((STAIR.x0 + STAIR.x1) * 0.5, WALL_H - 0.3, 5.5), Color(0.9, 0.85, 0.7), 0.4, 5.0)
	_light(Vector3(70.0, WALL_H - 0.3, -6.0), room_blue, 0.5, 8.0)
	_light(Vector3(78.5, WALL_H - 0.3, -5.5), room_blue, 0.6, 9.0)
	var dmid: Vector2 = DIAG_LOWER_START + _diag_dir() * 8.0 + _diag_up() * DIAG_WIDTH * 0.5
	_light(Vector3(dmid.x, WALL_H - 0.3, dmid.y), corridor_red, 0.6, 9.0)


func _light(pos: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	_extras.add_child(light)
	light.position = pos


func _place_exit_trigger() -> void:
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, WALL_H, 1.2)
	col.shape = shape
	area.add_child(col)
	_extras.add_child(area)
	area.position = Vector3(EXIT_POS.x, WALL_H * 0.5, EXIT_POS.z)
	if not Engine.is_editor_hint():
		area.body_entered.connect(_on_exit_entered)


func _on_exit_entered(body: Node3D) -> void:
	if body == GameManager.player:
		GameManager.win()


# ---------------------------------------------------------------- 도형 도우미

## a→b 벽. gaps = [[시작 거리, 끝 거리], ...] (a 기준, m) 구간은 비운다.
## 양 끝은 WALL_T/2 만큼 늘려 모서리 틈을 막는다.
func _wall_seg(a: Vector2, b: Vector2, gaps: Array = []) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var dir := (b - a) / length
	var cuts: Array = []
	for g in gaps:
		var s0: float = g[0]
		var s1: float = g[1]
		# 축 정렬 벽에 x/z 좌표로 준 틈은 a 기준 거리로 바꾼다
		if absf(dir.x) > 0.999:
			s0 = (s0 - a.x) * signf(dir.x)
			s1 = (s1 - a.x) * signf(dir.x)
		elif absf(dir.y) > 0.999:
			s0 = (s0 - a.y) * signf(dir.y)
			s1 = (s1 - a.y) * signf(dir.y)
		cuts.append([minf(s0, s1), maxf(s0, s1)])
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var pieces: Array = []
	var cur := -WALL_T * 0.5
	for c in cuts:
		if c[0] > cur:
			pieces.append([cur, c[0]])
		cur = maxf(cur, c[1])
	if length + WALL_T * 0.5 > cur:
		pieces.append([cur, length + WALL_T * 0.5])
	var rot := atan2(-dir.y, dir.x)
	# 출입구 위 인방: 문 높이 위로 천장까지 벽을 채운다
	for c in cuts:
		var s0: float = maxf(c[0], 0.0)
		var s1: float = minf(c[1], length)
		if s1 - s0 < 0.02:
			continue
		var lc: Vector2 = a + dir * ((s0 + s1) * 0.5)
		var lintel := _box(nav_region, Vector3(lc.x, (DOOR_H + WALL_H) * 0.5, lc.y), Vector3(s1 - s0, WALL_H - DOOR_H, WALL_T), _wall_mat)
		lintel.rotation.y = rot
	for p in pieces:
		var l: float = p[1] - p[0]
		if l < 0.02:
			continue
		var c2: Vector2 = a + dir * ((p[0] + p[1]) * 0.5)
		var body := _box(nav_region, Vector3(c2.x, WALL_H * 0.5, c2.y), Vector3(l, WALL_H, WALL_T), _wall_mat)
		body.rotation.y = rot


func _floor_rect(x0: float, x1: float, z0: float, z1: float, collide: bool) -> void:
	var size := Vector3(x1 - x0, 0.2, z1 - z0)
	var pos := Vector3((x0 + x1) * 0.5, -0.1, (z0 + z1) * 0.5)
	if collide:
		_box(nav_region, pos, size, _floor_mat)
	else:
		_box(_extras, pos, size, _locked_floor_mat, false)


## 다각형 바닥 (x-z 평면, y=0). collide=false 면 보이기만 한다.
func _floor_poly(points: PackedVector2Array, collide := true) -> void:
	var idx := Geometry2D.triangulate_polygon(points)
	if idx.is_empty():
		push_warning("floor polygon could not be triangulated")
		return
	var verts := PackedVector3Array()
	for i in idx.size() / 3:
		var p0 := points[idx[i * 3]]
		var p1 := points[idx[i * 3 + 1]]
		var p2 := points[idx[i * 3 + 2]]
		# Godot 앞면(시계 방향) 기준으로 위를 보게 맞춘다. 반대면 네비메시가 '천장'으로 보고 무시한다.
		if (p1 - p0).cross(p2 - p0) < 0.0:
			var t := p1
			p1 = p2
			p2 = t
		verts.append(Vector3(p0.x, 0, p0.y))
		verts.append(Vector3(p1.x, 0, p1.y))
		verts.append(Vector3(p2.x, 0, p2.y))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _floor_mat if collide else _locked_floor_mat
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(verts)
		shape.backface_collision = true
		col.shape = shape
		body.add_child(col)
		body.add_child(mi)
		nav_region.add_child(body)
	else:
		_extras.add_child(mi)


func _door_panel(pos: Vector3, rot_y: float, width: float) -> void:
	var body := _box(_extras, pos + Vector3(0, 1.05, 0), Vector3(width, 2.1, 0.05), _door_mat, false)
	body.rotation.y = rot_y


func _sign(text: String, pos: Vector3, rot_y: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.005
	label.modulate = Color(0.75, 0.78, 0.82)
	label.outline_size = 0
	label.double_sided = false  # 벽 뒤에서 거울 글씨로 비치지 않게
	_extras.add_child(label)
	label.position = pos
	label.rotation.y = rot_y


## 상자 하나. collide=false 면 MeshInstance3D 만 만든다(장식).
func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material, collide := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	if not collide:
		parent.add_child(mi)
		mi.position = pos
		return mi
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.add_child(mi)
	parent.add_child(body)
	body.position = pos
	return body
