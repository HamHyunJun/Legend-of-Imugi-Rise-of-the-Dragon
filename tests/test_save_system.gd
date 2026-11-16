extends SceneTree
## M0 완료 기준 자동 테스트: 플래그·카운터를 저장하고 다시 불러오면 복원되는가.
##
## 실행: godot --headless --path . --script res://tests/test_save_system.gd
## 실제 세이브를 건드리지 않도록 전용 테스트 슬롯을 쓴다.

const SLOT := "test_m0"

var _failures := 0


func _initialize() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveSystem")
	saves.delete_save(SLOT)

	# 1) 저장 -> 초기화 -> 불러오기
	state.reset()
	state.set_flag("flag.debug.test", true)
	state.add_counter("counter.debug.boot_count", 3)
	state.player["level"] = 7
	_check(saves.save_game(SLOT), "저장 성공")
	state.reset()
	_check(state.get_flag("flag.debug.test") == false, "초기화 후 플래그 꺼짐")
	_check(saves.load_game(SLOT), "불러오기 성공")
	_check(state.get_flag("flag.debug.test") == true, "플래그 복원")
	_check(state.get_counter("counter.debug.boot_count") == 3, "카운터 복원")
	_check(int(state.player["level"]) == 7, "플레이어 레벨 복원")

	# 2) 두 번째 저장 시 직전 본이 .bak으로 남는가
	state.add_counter("counter.debug.boot_count", 1)
	_check(saves.save_game(SLOT), "두 번째 저장 성공")
	_check(FileAccess.file_exists(saves.slot_path(SLOT) + ".bak"), ".bak 생성")

	# 3) 본 파일이 손상되면 .bak(카운터 3)으로 복구되는가
	var f := FileAccess.open(saves.slot_path(SLOT), FileAccess.WRITE)
	f.store_string("{ 손상된 파일")
	f.close()
	state.reset()
	_check(saves.load_game(SLOT), "손상 시 백업에서 불러오기")
	_check(state.get_counter("counter.debug.boot_count") == 3, "백업 값 복원")

	# 4) 체크섬 불일치 감지
	saves.save_game(SLOT)
	saves.delete_save(SLOT)
	state.reset()
	state.set_flag("flag.debug.test", true)
	saves.save_game(SLOT)
	var text := FileAccess.get_file_as_string(saves.slot_path(SLOT))
	f = FileAccess.open(saves.slot_path(SLOT), FileAccess.WRITE)
	f.store_string(text.replace("\"flag.debug.test\": true", "\"flag.debug.test\": false"))
	f.close()
	_check(not saves.load_game(SLOT), "변조된 파일은 거부(백업 없음)")

	saves.delete_save(SLOT)
	print("세이브 테스트: %s (실패 %d건)" % ["통과" if _failures == 0 else "실패", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  [통과] " if ok else "  [실패] ") + label)
	if not ok:
		_failures += 1
