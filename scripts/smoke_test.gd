extends Node
## 자동 스모크 테스트
## 실행:  godot --path . res://scenes/smoke_test.tscn
## 손으로 플레이하지 않고 GameManager API로 전체 루프를 빠르게 돌려 깨진 곳을 찾는다.
##   노드 3개 정제 → 문 3개 개방 → 괴물 활성화 → 빛에 정지 → 빛 끄면 추격 → 접촉 사망 → 리스폰 → 탈출
## 종료 코드 0 = PASS, 1 = FAIL. 콘솔에 항목별 결과를 찍는다.

const Level := preload("res://scripts/level_builder.gd")

var _lines: Array[String] = []
var _failed := false


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout  # 레벨 생성 + 네비메시 베이크 대기
	await _run()
	print("")
	print("SMOKE RESULT: ", "FAIL" if _failed else "PASS")
	for l in _lines:
		print("  ", l)
	get_tree().quit(1 if _failed else 0)


func _check(cond: bool, msg: String) -> void:
	_lines.append(("[OK]   " if cond else "[FAIL] ") + msg)
	if not cond:
		_failed = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var player := GameManager.player
	var monster := GameManager.monster
	_check(player != null, "플레이어 등록")
	_check(monster != null, "괴물 등록")
	if player == null or monster == null:
		return

	var minigame := get_tree().root.find_child("Minigame", true, false)
	_check(minigame != null, "미니게임 UI 존재")

	var terminals := get_tree().get_nodes_in_group("terminals")
	terminals.sort_custom(func(a, b): return a.node_index < b.node_index)
	_check(terminals.size() == GameManager.TOTAL_NODES, "터미널 %d개 배치" % GameManager.TOTAL_NODES)

	var doors := get_tree().get_nodes_in_group("doors")
	_check(doors.size() == 3, "문 3개 배치")

	_check(monster.state == monster.State.DORMANT, "시작 시 괴물 비활성(DORMANT)")
	_check(player.flashlight_on, "시작 시 손전등 켜짐")

	# ---- 계단실에서 시작 → 로비 문 열기
	_check(player.global_position.distance_to(Level.START_POS) < 0.5, "계단실 시작 위치")
	var start_doors := get_tree().get_nodes_in_group("start_door")
	_check(start_doors.size() == 1, "로비 문 배치")
	if start_doors.size() == 1:
		var sd = start_doors[0]
		# 테스트 중 실제 마우스가 움직여도 결과가 같도록 시작 방향(+x)을 다시 맞춘다
		player.rotation = Vector3(0, -PI / 2, 0)
		player.head.rotation = Vector3.ZERO
		await _frames(2)
		_check(player.interact_ray.get_collider() == sd and sd.can_interact(), "시작 시 로비 문을 보고 있고 열 수 있음")
		player._try_interact()
		await get_tree().create_timer(1.4).timeout
		_check(sd.is_open and not sd.can_interact(), "E로 로비 문 열림")

	# ---- 노드 3개 순서대로 정제
	for t in terminals:
		var idx: int = t.node_index
		# 터미널 화면 앞 1.5m
		player.global_position = t.global_position + (-t.global_transform.basis.z) * 1.5 + Vector3.UP * 0.1
		await _frames(2)
		_check(t.can_interact(), "노드 %d 상호작용 가능" % idx)
		t.interact(player)
		await _frames(1)
		_check(GameManager.in_minigame and minigame.visible, "노드 %d 미니게임 시작" % idx)
		_check(player.input_locked and not player.flashlight_on, "노드 %d 정제 중 입력 잠금·손전등 꺼짐" % idx)

		# 정답 입력
		if t.mode == t.Mode.PATTERN:
			minigame._pattern_hidden = true
		var answer: Array = minigame._target.duplicate()
		# 일부러 한 번 틀려서 오답 처리도 지나가게 한다.
		# SEQUENCE는 첫 비트가 틀리면 즉시 오답, PATTERN은 4비트를 다 넣어야 대조한다.
		minigame._on_bit(1 - answer[0])
		if t.mode == t.Mode.PATTERN:
			for k in range(1, answer.size()):
				minigame._on_bit(answer[k])
		_check(minigame._mistakes == 1, "노드 %d 오답 처리" % idx)
		if t.mode == t.Mode.PATTERN:
			minigame._pattern_hidden = true
		for b in answer:
			minigame._on_bit(b)
		await get_tree().create_timer(1.0).timeout  # _resolve 0.7s

		_check(t.purified, "노드 %d 정제 완료" % idx)
		_check(GameManager.purified_count == idx, "정제 카운트 == %d" % idx)
		_check(not GameManager.in_minigame and not minigame.visible, "노드 %d 미니게임 닫힘" % idx)
		_check(not player.input_locked, "노드 %d 이후 입력 잠금 해제" % idx)
		for d in doors:
			var should_open: bool = d.required_nodes <= idx
			_check(d.is_open == should_open, "노드 %d 이후 문(필요 %d) 열림=%s" % [idx, d.required_nodes, should_open])
		if idx == 1:
			_check(monster.state != monster.State.DORMANT and monster.visible, "노드 1 이후 괴물 활성화")

	# ---- 문이 다 열린 뒤 괴물이 좁은 문을 지나 모든 구역으로 길을 찾는지 (실측 폭 2.5m 복도, 2m 문)
	var nav_map: RID = monster.agent.get_navigation_map()
	for goal in Level.NAV_TEST_POINTS:
		var path := NavigationServer3D.map_get_path(nav_map, monster.spawn_position, goal, true)
		var reached: bool = path.size() > 0 and Vector2(path[-1].x, path[-1].z).distance_to(Vector2(goal.x, goal.z)) < 0.6
		_check(reached, "괴물 스폰 → (%.0f, %.0f) 길찾기 가능" % [goal.x, goal.z])
		if not reached:
			var closest := NavigationServer3D.map_get_closest_point(nav_map, goal)
			_lines.append("[INFO]   경로 끝 %s, 목표에 가장 가까운 네비 점 %s" % [path[-1] if path.size() > 0 else "없음", closest])

	# ---- 괴물: 빛에 정지 / 빛 끄면 추격  (장애물 없는 서쪽 직선 복도에서)
	player.global_position = Level.FREEZE_TEST_POS
	player.rotation = Vector3(0, -PI / 2, 0)  # +x 방향
	player.head.rotation = Vector3.ZERO
	await _frames(1)
	var forward: Vector3 = -player.global_transform.basis.z
	monster.global_position = player.global_position + forward * 5.0
	player._set_flashlight(true)
	await _frames(3)
	_check(monster.state == monster.State.FROZEN, "손전등 비추면 FROZEN (현재 %s)" % monster.State.keys()[monster.state])
	var frozen_pos: Vector3 = monster.global_position
	await _frames(10)
	var frozen_moved: Vector3 = monster.global_position - frozen_pos
	frozen_moved.y = 0.0  # 바닥에 내려앉는 수직 이동은 무시
	_check(frozen_moved.length() < 0.05, "FROZEN 동안 이동 없음")

	# 네비게이션 진단 정보
	var nm: NavigationMesh = get_tree().root.find_child("NavRegion", true, false).navigation_mesh
	_lines.append("[INFO] 네비메시 폴리곤 수: %d" % (nm.get_polygon_count() if nm else -1))
	var agent: NavigationAgent3D = monster.agent
	agent.target_position = player.global_position
	agent.get_next_path_position()
	_lines.append("[INFO] 경로 점 수: %d, finished=%s, reachable=%s" % [
		agent.get_current_navigation_path().size(), agent.is_navigation_finished(), agent.is_target_reachable()])

	player._set_flashlight(false)
	await _frames(3)
	_check(monster.state == monster.State.CHASE, "손전등 끄면 CHASE (현재 %s)" % monster.State.keys()[monster.state])
	var chase_start: Vector3 = monster.global_position
	await _frames(20)
	_lines.append("[INFO] CHASE 20프레임 이동량: %.2f m (시작 %s → %s)" % [
		monster.global_position.distance_to(chase_start), chase_start, monster.global_position])
	_check(monster.global_position.distance_to(chase_start) > 0.3, "CHASE 중 플레이어 쪽으로 이동")

	# ---- 접촉 사망 → 리스폰
	var checkpoint: Vector3 = GameManager.checkpoint_position
	monster.global_position = player.global_position + forward * 0.5
	await _frames(3)
	_check(GameManager.is_dead, "접촉 시 사망")
	await get_tree().create_timer(GameManager.RESPAWN_DELAY + 0.5).timeout
	_check(not GameManager.is_dead, "리스폰 완료")
	_check(player.global_position.distance_to(checkpoint) < 0.5, "체크포인트 위치에서 리스폰")
	_check(monster.global_position.distance_to(monster.spawn_position) < 0.5, "괴물 스폰 위치로 복귀")
	_check(GameManager.purified_count == GameManager.TOTAL_NODES, "리스폰 후 정제 진행도 유지")

	# ---- 탈출
	player.global_position = Level.EXIT_POS
	await _frames(3)
	_check(GameManager.has_won, "탈출 트리거 → 승리")
