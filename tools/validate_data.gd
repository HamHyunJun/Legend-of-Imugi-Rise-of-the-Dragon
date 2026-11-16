extends SceneTree
## 데이터 검증 도구(docs/design/05_데이터구조.md 1장).
##
## 실행: godot --headless --path . --script res://tools/validate_data.gd
## 실패하면 종료 코드 1을 돌려주므로 CI에서도 쓸 수 있다.
##
## M0 검사 항목: JSON 문법, id 누락, ID 중복, ID 형식(소문자·숫자·밑줄·점),
## 존재하지 않는 res:// 경로(경고). 참조 무결성, 조건/효과 타입,
## 퀘스트 도달 가능성 검사는 M3 이후 Condition/Effect 엔진과 함께 추가한다.

const ID_PATTERN := "^[a-z0-9_]+(\\.[a-z0-9_]+)*$"


func _initialize() -> void:
	# 자동 로드는 _initialize 시점에 이미 준비되어 있다.
	var registry: Node = root.get_node("DataRegistry")
	registry.load_all()

	var errors: PackedStringArray = registry.errors.duplicate()
	var warnings: PackedStringArray = []
	var id_regex := RegEx.create_from_string(ID_PATTERN)

	for catalog: String in registry.catalog_names():
		for id: String in registry.get_all(catalog):
			if id_regex.search(id) == null:
				errors.append("%s: ID 형식 오류 '%s'" % [catalog, id])
			_check_paths(registry.get_def(catalog, id), "%s/%s" % [catalog, id], warnings)

	for w in warnings:
		print("경고: " + w)
	for e in errors:
		printerr("오류: " + e)
	print("데이터 검증 완료: 오류 %d건, 경고 %d건" % [errors.size(), warnings.size()])
	quit(1 if errors.size() > 0 else 0)


## 값 안의 res:// 문자열이 실제로 존재하는지 재귀적으로 확인한다.
## 아직 에셋을 만들기 전이라 경고로만 처리한다.
func _check_paths(value: Variant, where: String, warnings: PackedStringArray) -> void:
	if value is Dictionary:
		for key: Variant in value:
			_check_paths(value[key], "%s.%s" % [where, key], warnings)
	elif value is Array:
		for i in value.size():
			_check_paths(value[i], "%s[%d]" % [where, i], warnings)
	elif value is String and value.begins_with("res://"):
		if not ResourceLoader.exists(value) and not FileAccess.file_exists(value):
			warnings.append("%s: 없는 경로 %s" % [where, value])
