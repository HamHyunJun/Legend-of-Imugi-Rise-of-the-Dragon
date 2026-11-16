extends Node
## 전역 신호 허브(자동 로드: EventBus).
##
## 상태를 바꾸는 쪽(GameState, 효과 실행기)은 여기로 신호를 보내고,
## UI·NPC 반응·둥지 등은 이 신호를 구독해 갱신한다.
## 시스템끼리 직접 참조하지 않게 해서 결합도를 낮추는 것이 목적이다.
## 신호 목록은 docs/design/05_데이터구조.md 6장을 따른다.

# --- 상태 변경 ---
signal flag_changed(id: String, value: Variant)
signal counter_changed(id: String, value: int)
signal yinyang_changed(yang_total: int, yin_total: int, tendency: int)
signal orb_gained(element: String)
signal form_unlocked(form_id: String)
signal form_changed(form_id: String)
signal ability_unlocked(ability_id: String)
signal relation_changed(npc_id: String, value: int)
signal quest_changed(quest_id: String, state: String, stage: String)
signal region_state_changed(region_id: String, state: String)
signal exp_changed(level: int, exp: int)

# --- 시스템 ---
## DataRegistry가 모든 정의 데이터를 읽은 뒤 한 번 보낸다.
signal data_loaded
## GameState 전체가 교체되었을 때(새 게임, 불러오기).
signal state_reset
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal save_failed(slot: String, reason: String)
