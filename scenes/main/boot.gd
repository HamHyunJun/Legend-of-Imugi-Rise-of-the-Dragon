extends Node3D
## M0 부팅 확인 씬.
##
## 목적(docs/design/04 M0 완료 기준):
## 1) 빈 3D 씬이 Android 기기에서 실행되는지 확인한다(Compatibility 렌더러).
## 2) 임의 플래그·카운터를 저장하고, 앱을 다시 켰을 때 복원되는지 확인한다.
##
## 실행할 때마다 counter.debug.boot_count가 1씩 늘고 자동 저장된다.
## 앱을 완전히 종료 후 다시 켜서 숫자가 이어지면 저장/복원이 동작하는 것이다.

const FLAG_TEST := "flag.debug.test"
const COUNTER_BOOT := "counter.debug.boot_count"

@onready var _cube: MeshInstance3D = $Cube
@onready var _info: Label = %InfoLabel
@onready var _fps: Label = %FpsLabel


func _ready() -> void:
	var loaded := SaveSystem.load_game(SaveSystem.SLOT_AUTO)
	GameState.add_counter(COUNTER_BOOT)
	SaveSystem.save_game(SaveSystem.SLOT_AUTO)
	print("[Boot] 세이브 %s, 부팅 횟수 %d" % ["복원" if loaded else "새로 생성", GameState.get_counter(COUNTER_BOOT)])

	%ToggleButton.pressed.connect(_on_toggle_pressed)
	%ResetButton.pressed.connect(_on_reset_pressed)
	_refresh(loaded)


func _process(delta: float) -> void:
	_cube.rotate_y(delta * 0.8)
	_fps.text = "FPS %d" % Engine.get_frames_per_second()


func _on_toggle_pressed() -> void:
	GameState.set_flag(FLAG_TEST, not GameState.get_flag(FLAG_TEST))
	SaveSystem.save_game(SaveSystem.SLOT_AUTO)
	_refresh(true)


func _on_reset_pressed() -> void:
	SaveSystem.delete_save(SaveSystem.SLOT_AUTO)
	GameState.reset()
	_refresh(false)


func _refresh(loaded: bool) -> void:
	var lines: PackedStringArray = [
		"용의 전설 - 이무기의 탄생  v%s" % ProjectSettings.get_setting("application/config/version"),
		"Godot %s / %s / %s" % [
			Engine.get_version_info()["string"],
			RenderingServer.get_current_rendering_method(),
			OS.get_name(),
		],
		"GPU: %s" % RenderingServer.get_video_adapter_name(),
		"",
		"세이브: %s" % ("복원됨" if loaded else "새 게임"),
		"부팅 횟수(%s): %d" % [COUNTER_BOOT, GameState.get_counter(COUNTER_BOOT)],
		"테스트 플래그(%s): %s" % [FLAG_TEST, "켜짐" if GameState.get_flag(FLAG_TEST) else "꺼짐"],
		"",
		"데이터: 오행 %d종, 데이터 오류 %d건" % [DataRegistry.get_all("elements").size(), DataRegistry.errors.size()],
		"저장 경로: %s" % ProjectSettings.globalize_path(SaveSystem.slot_path(SaveSystem.SLOT_AUTO)),
	]
	_info.text = "\n".join(lines)
