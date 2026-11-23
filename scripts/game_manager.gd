extends Node
## GameManager (Autoload, 전역 이름 GameManager)
##
## 팀 전체가 공유하는 "이벤트 허브". 파트(A 플레이어 / B 괴물 / C 미니게임 / D 레벨·연출)
## 사이의 접점은 아래 시그널로만 주고받는다. 서로의 노드를 직접 참조하지 않는 것이 규칙.
##
##   noise_emitted(position, loudness)   누가 어디서 얼마나 큰 소리를 냈나 (0.0 ~ 1.0)
##                                        플레이어 발소리 0.2 / 달리기 0.45 / 터미널 기동 0.6
##                                        미니게임 키 입력 0.3 / 오답 1.0
##   node_purified(node_index, count)     서버 노드 하나 정제 완료 → 문 개방, 노이즈 감소, 체크포인트
##   minigame_started / minigame_finished 터미널 정제 미니게임 시작·종료 (플레이어 입력 잠금 해제용)
##   player_died / player_respawned       괴물 접촉 = 즉사 → 마지막 정제 지점에서 재시작
##   game_won                             메인 게이트 통과

signal noise_emitted(position: Vector3, loudness: float)
signal node_purified(node_index: int, purified_count: int)
signal minigame_started(terminal: Node)
signal minigame_finished(terminal: Node, success: bool)
signal player_died
signal player_respawned(checkpoint: Vector3)
signal game_won

const TOTAL_NODES := 3
const RESPAWN_DELAY := 2.0

var purified_count := 0
var checkpoint_position := Vector3.ZERO
var in_minigame := false
var is_dead := false
var has_won := false

var player: Node3D = null
var monster: Node3D = null

# 키 바인딩. project.godot의 [input] 대신 코드로 등록해 둬서 팀원 PC에서 설정이 어긋나지 않게 한다.
const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"flashlight": [KEY_F],
	"interact": [KEY_E],
	"bit_0": [KEY_0, KEY_KP_0],
	"bit_1": [KEY_1, KEY_KP_1],
	"restart": [KEY_R],
}


func _ready() -> void:
	_setup_input_map()


func _setup_input_map() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- 등록

func register_player(p: Node3D) -> void:
	player = p
	checkpoint_position = p.global_position


func register_monster(m: Node3D) -> void:
	monster = m


# ---------------------------------------------------------------- 소음

func emit_noise(position: Vector3, loudness: float) -> void:
	noise_emitted.emit(position, clampf(loudness, 0.0, 1.0))


# ---------------------------------------------------------------- 정제

func start_minigame(terminal: Node) -> void:
	if in_minigame or is_dead or has_won:
		return
	in_minigame = true
	minigame_started.emit(terminal)


func finish_minigame(terminal: Node, success: bool) -> void:
	in_minigame = false
	minigame_finished.emit(terminal, success)


func purify_node(node_index: int) -> void:
	purified_count = mini(purified_count + 1, TOTAL_NODES)
	if player:
		checkpoint_position = player.global_position
	node_purified.emit(node_index, purified_count)


## 1.0(하나도 정제 안 됨) → 0.0(전부 정제). 화면 노이즈 셰이더 기본 강도.
func noise_level() -> float:
	return 1.0 - float(purified_count) / float(TOTAL_NODES)


# ---------------------------------------------------------------- 실패 / 승리

func kill_player() -> void:
	if is_dead or has_won:
		return
	is_dead = true
	in_minigame = false
	player_died.emit()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	is_dead = false
	player_respawned.emit(checkpoint_position)


func win() -> void:
	if has_won:
		return
	has_won = true
	game_won.emit()


func restart() -> void:
	purified_count = 0
	in_minigame = false
	is_dead = false
	has_won = false
	player = null
	monster = null
	get_tree().reload_current_scene()
