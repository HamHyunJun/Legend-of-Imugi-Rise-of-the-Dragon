extends Node
## 런타임 게임 상태(자동 로드: GameState).
##
## 변하는 값은 모두 이곳 한 군데에 모은다. 세이브 파일의 "state"는
## to_dict()를 그대로 직렬화한 것이다(docs/design/05_데이터구조.md 6장).
##
## 규칙: 다른 스크립트는 이 변수들을 직접 고치지 말고, 아래 전용 함수나
## (M3 이후) 효과(Effect) 실행기를 통해서만 바꾼다. 변경 시 EventBus 신호를 보낸다.

## 상태 구조가 바뀌면 올리고 SaveSystem의 마이그레이션을 추가한다.
const STATE_VERSION := 1

var player: Dictionary
var yinyang: Dictionary
var orbs: Array
var flags: Dictionary
var counters: Dictionary
var quests: Dictionary
var relations: Dictionary
var regions: Dictionary
var nest: Dictionary
var inventory: Dictionary
var codex: Dictionary
var records: Dictionary
var location: Dictionary


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	# 일시정지 중에는 자동 로드도 멈추므로(process_mode 기본값) 실제 플레이 시간만 쌓인다.
	records["play_time"] = float(records.get("play_time", 0.0)) + delta


## 새 게임 상태로 초기화한다.
func reset() -> void:
	from_dict(default_state())
	EventBus.state_reset.emit()


## 새 게임의 기본 상태. 필드를 추가하면 여기에도 기본값을 넣는다.
static func default_state() -> Dictionary:
	return {
		"player": {
			"name": "미르",
			"level": 1, "exp": 0,
			"growth_stage": "hatchling", # hatchling/adult/glider/dragon/awakened/divine
			"abilities": ["walk"],
			"current_form": "form.imugi",
			"unlocked_forms": [],
			"bond": {}, # form_id -> 교감 등급
			"accessories": [],
		},
		"yinyang": {"yang_total": 0, "yin_total": 0, "tendency": 0, "micro_used": {}},
		"orbs": [],
		"flags": {},
		"counters": {},
		"quests": {}, # quest_id -> { state, stage, progress }
		"relations": {}, # npc_id -> int
		"regions": {}, # region_id -> { state, visited, discovered }
		"nest": {"stage": 1, "theme": null, "unlocked_themes": ["theme.base"], "slots": {}},
		"inventory": {},
		"codex": {"forms_seen": [], "enemies": [], "treasures": []},
		"records": {"play_time": 0.0, "flight_challenges": {}},
		"location": {"region": "region.jamryong_cave", "spawn": "nest"},
	}


## 세이브용 사본. 원본을 바깥에서 고치지 못하게 깊은 복사한다.
func to_dict() -> Dictionary:
	return {
		"player": player.duplicate(true),
		"yinyang": yinyang.duplicate(true),
		"orbs": orbs.duplicate(true),
		"flags": flags.duplicate(true),
		"counters": counters.duplicate(true),
		"quests": quests.duplicate(true),
		"relations": relations.duplicate(true),
		"regions": regions.duplicate(true),
		"nest": nest.duplicate(true),
		"inventory": inventory.duplicate(true),
		"codex": codex.duplicate(true),
		"records": records.duplicate(true),
		"location": location.duplicate(true),
	}


## 세이브에서 읽은 상태를 적용한다. 빠진 필드는 기본값으로 채운다
## (구버전 세이브에 새 필드가 없어도 동작하도록).
func from_dict(data: Dictionary) -> void:
	var base := default_state()
	for key: String in base:
		var value: Variant = data.get(key, base[key])
		if base[key] is Dictionary and value is Dictionary:
			var merged: Dictionary = base[key].duplicate(true)
			merged.merge(value, true)
			value = merged
		set(key, value)


# --- 플래그 / 카운터 (M0에서 저장·복원 검증에 사용) ---

func get_flag(id: String, default: Variant = false) -> Variant:
	return flags.get(id, default)


func set_flag(id: String, value: Variant = true) -> void:
	if flags.get(id) == value:
		return
	flags[id] = value
	EventBus.flag_changed.emit(id, value)


func get_counter(id: String) -> int:
	return int(counters.get(id, 0))


func add_counter(id: String, amount: int = 1) -> int:
	var value := get_counter(id) + amount
	counters[id] = value
	EventBus.counter_changed.emit(id, value)
	return value
