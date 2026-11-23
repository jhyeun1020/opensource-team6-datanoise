extends CharacterBody3D
## 글리치 괴물 (담당 B)
##
## 기획안 규칙(4p, 7p):
##   - 터미널 정제 중 발생한 소음을 듣고 일정 거리까지 접근한다.
##   - 빛을 비추면 멈추고, 빛을 끄면 빠르게 접근한다.
## 기획안 6p: 첫 노드 정제 전(도입 구간)에는 등장하지 않는다 → DORMANT.
## 뼈대에서 정한 규칙(9p "괴물 접촉 결과" 제안): 접촉 = 즉사, 체력·탄약 없음.
##
## 상태기계
##   DORMANT     비활성 (노드 1 정제 전)
##   IDLE        스폰 주변을 어슬렁거림
##   INVESTIGATE 들린 소음 위치로 이동
##   CHASE       플레이어 위치(마지막으로 본/들은)로 빠르게 이동
##   FROZEN      손전등 빛에 비춰져 정지. 빛이 꺼지면 CHASE로.

signal state_changed(state_name: String)

enum State { DORMANT, IDLE, INVESTIGATE, CHASE, FROZEN }

@export var investigate_speed := 2.2
@export var chase_speed := 4.2
@export var hearing_range := 30.0        # loudness 1.0 소음이 들리는 최대 거리 (loudness에 비례)
@export var alarm_distance := 12.0       # 이 거리 안의 큰 소음(>=0.9)은 바로 추격
@export var sight_range := 14.0
@export var sight_fov_deg := 70.0        # 정면 기준 반각
@export var lose_sight_time := 4.0
@export var kill_distance := 1.2
@export var idle_wander_radius := 6.0
@export var activate_after_nodes := 1    # 이 개수 이상 정제되면 활성화

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D

var state: State = State.DORMANT
var spawn_position: Vector3

var _mat: StandardMaterial3D
var _last_known := Vector3.ZERO
var _since_seen := 999.0
var _idle_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const STATE_COLORS := {
	State.DORMANT: Color(0.2, 0.2, 0.2),
	State.IDLE: Color(0.5, 0.1, 0.6),
	State.INVESTIGATE: Color(1.0, 0.5, 0.1),
	State.CHASE: Color(1.0, 0.05, 0.1),
	State.FROZEN: Color(0.6, 0.9, 1.0),
}


func _ready() -> void:
	spawn_position = global_position
	# 머티리얼을 인스턴스별로 복제해서 상태 색을 바꿔도 다른 노드에 영향이 없게 한다.
	_mat = mesh.get_surface_override_material(0).duplicate()
	mesh.set_surface_override_material(0, _mat)

	GameManager.register_monster(self)
	GameManager.noise_emitted.connect(_on_noise)
	GameManager.node_purified.connect(_on_node_purified)
	GameManager.player_respawned.connect(func(_pos): reset())
	_apply_state_visuals()


func reset() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_since_seen = 999.0
	_last_known = spawn_position
	agent.target_position = spawn_position  # 이전 추격 목표를 잊는다
	_idle_timer = 2.0                        # 리스폰 직후 잠시 대기
	if GameManager.purified_count >= activate_after_nodes:
		_change_state(State.IDLE)
	else:
		_change_state(State.DORMANT)


# ---------------------------------------------------------------- 이벤트

func _on_node_purified(_index: int, count: int) -> void:
	if state == State.DORMANT and count >= activate_after_nodes:
		_change_state(State.IDLE)
		# 첫 등장: 정제 소음이 난 쪽(플레이어 위치)으로 조사하러 간다.
		if GameManager.player:
			_investigate(GameManager.player.global_position)


func _on_noise(pos: Vector3, loudness: float) -> void:
	if state == State.DORMANT or state == State.FROZEN or GameManager.is_dead:
		return
	var dist := global_position.distance_to(pos)
	if dist > loudness * hearing_range:
		return
	if loudness >= 0.9 and dist <= alarm_distance:
		_last_known = pos
		_change_state(State.CHASE)
	elif state != State.CHASE:
		_investigate(pos)


func _investigate(pos: Vector3) -> void:
	_last_known = pos
	agent.target_position = pos
	_change_state(State.INVESTIGATE)


# ---------------------------------------------------------------- 메인 루프

func _physics_process(delta: float) -> void:
	var player := GameManager.player
	if state == State.DORMANT or player == null or GameManager.is_dead or GameManager.has_won:
		velocity = Vector3.ZERO
		return

	# 1) 빛 반응: 어떤 상태든 비추면 멈춤. 빛이 꺼지면 즉시 추격.
	var lit: bool = player.is_lighting(global_position + Vector3.UP * 1.0)
	if lit and state != State.FROZEN:
		_change_state(State.FROZEN)
	elif not lit and state == State.FROZEN:
		_last_known = player.global_position
		_change_state(State.CHASE)

	# 2) 시야
	if state != State.FROZEN and _can_see(player):
		_since_seen = 0.0
		_last_known = player.global_position
		if state != State.CHASE:
			_change_state(State.CHASE)
	else:
		_since_seen += delta

	# 3) 상태별 이동 목표와 속도
	var speed := 0.0
	match state:
		State.FROZEN:
			speed = 0.0
		State.CHASE:
			agent.target_position = _last_known
			speed = chase_speed
			if _since_seen > lose_sight_time and _arrived():
				_change_state(State.IDLE)
		State.INVESTIGATE:
			speed = investigate_speed
			if _arrived():
				_change_state(State.IDLE)
		State.IDLE:
			speed = investigate_speed * 0.7
			_idle_timer -= delta
			if _arrived() and _idle_timer <= 0.0:
				_idle_timer = randf_range(2.0, 4.0)
				agent.target_position = spawn_position + Vector3(
					randf_range(-idle_wander_radius, idle_wander_radius), 0.0,
					randf_range(-idle_wander_radius, idle_wander_radius))

	_move(speed, delta)

	# 4) 접촉 = 즉사
	if state != State.FROZEN and global_position.distance_to(player.global_position) < kill_distance:
		GameManager.kill_player()


func _arrived() -> bool:
	var to_target := agent.target_position - global_position
	to_target.y = 0.0
	return to_target.length() < 1.0


func _move(speed: float, delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	if speed <= 0.0 or _arrived():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var next := agent.get_next_path_position()
	if agent.is_navigation_finished() or agent.get_current_navigation_path().is_empty():
		# 경로가 없음(네비메시가 아직 베이크되지 않았거나 도달 불가) → 목표로 직진 (임시 대처)
		next = agent.target_position
	var dir := next - global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.0001:
		# 경로 점이 제자리면(원점/높이 오프셋 문제 등) 목표로 직진
		dir = agent.target_position - global_position
		dir.y = 0.0
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		look_at(global_position + dir, Vector3.UP)
	move_and_slide()


func _can_see(player: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var target: Vector3 = player.eye_position()
	var to_target := target - eye
	var dist := to_target.length()
	if dist > sight_range or dist < 0.001:
		return false
	var forward := -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to_target / dist)) > sight_fov_deg:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == player


# ---------------------------------------------------------------- 상태 전환

func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_apply_state_visuals()
	state_changed.emit(State.keys()[state])
	# TODO(사운드): 상태별 사운드 (CHASE 진입 시 글리치 스크리치 등)


func _apply_state_visuals() -> void:
	visible = state != State.DORMANT
	var c: Color = STATE_COLORS[state]
	_mat.albedo_color = c * 0.2
	_mat.emission = c
	_mat.emission_energy_multiplier = 2.5 if state == State.CHASE else 1.2
