extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const RuleTests = preload("res://tests/rules_test.gd")
var checks = 0
var failures: Array = []
var game: Control

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _click_node(index: int) -> void:
	var event = InputEventMouseButton.new()
	event.position = game._pos(index)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	game._unhandled_input(event)

func _key(key: int) -> void:
	var event = InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_input(event)

func _stage_through_ui(cmd: Dictionary) -> void:
	match cmd.kind:
		"bridge":
			game.mode_buttons.bridge.pressed.emit()
			var edge = game.level.edges[cmd.edge]
			var dest = cmd.get("to", edge.b)
			_click_node(edge.a if dest == edge.b else edge.b)
			_click_node(dest)
		"move":
			game.mode_buttons[cmd.actor].pressed.emit()
			_click_node(cmd.to)
		"stamp":
			game.mode_buttons.stamp.pressed.emit()
			_click_node(cmd.to)
		"wait":
			game.wait_button.pressed.emit()

func _run() -> void:
	game = load("res://main.tscn").instantiate()
	game.storage_dir = "res://../artifacts/qa-playtest"
	root.add_child(game)
	await process_frame
	game._close_dialog()
	await process_frame
	var helper = RuleTests.new()
	var solutions = helper.solutions()
	helper.free()
	for index in range(game.levels.size()):
		game._load_level(index)
		var initial = game.state.duplicate(true)
		for cmd in solutions[index]:
			var expected = Sim.step(game.level, game.state, cmd)
			_stage_through_ui(cmd)
			check(not game.pending.is_empty(), "UI can select command on level %d" % (index + 1))
			check(not game.execute_button.disabled, "Confirmation button enables for a valid command")
			check(game.preview.state == expected.state, "Visible forecast uses the actual future state")
			_key(KEY_SPACE)
			check(game.state == expected.state, "Space executes the selected UI command")
			game._process(0.5)
			game._close_dialog()
			await process_frame
			check(game.anim_t == 1, "Animation finishes before accepting another command")
			check(game.labels.turn.text.contains("%02d" % game.state.turn), "Turn label updates after action")
			check(game.undo_button.disabled == game.history.is_empty(), "Undo availability follows history")
		check(game.state.won, "All UI paths can complete level %d" % (index + 1))
		check(game.progress.has(str(index)), "Winning persists level completion")
		while not game.history.is_empty():
			_key(KEY_Z)
		check(game.state == initial, "Undo restores the entire initial state of level %d" % (index + 1))
		check(game.execute_button.disabled, "Undo cancels stale pending commands")
	game._load_level(4)
	_stage_through_ui({"kind": "move", "actor": "house", "to": 1})
	_key(KEY_SPACE)
	game._process(0.5)
	_stage_through_ui({"kind": "move", "actor": "house", "to": 4})
	check(game.labels.forecast_title.text.begins_with("危险"), "UI warns before a losing action")
	_key(KEY_SPACE)
	game._process(0.5)
	check(game.state.lost and game.execute_button.disabled, "Loss blocks further execution")
	_key(KEY_Z)
	check(not game.state.lost and game.state.house == 1, "Undo recovers from a loss")
	_key(KEY_R)
	check(game.state.turn == 0 and game.state.house == 0, "Restart fully resets the level")
	_stage_through_ui({"kind": "move", "actor": "house", "to": 1})
	_key(KEY_ESCAPE)
	check(game.pending.is_empty() and game.execute_button.disabled, "Escape cancels without advancing time")
	game._show_rules()
	check(is_instance_valid(game.dialog), "Rules dialog opens")
	_key(KEY_ESCAPE)
	check(not is_instance_valid(game.dialog), "Escape closes modal without changing the map")
	game._hint()
	check(game.metrics.hints == 1, "Hint usage is recorded")
	game._close_dialog()
	game._record_feedback("QA interaction check")
	var progress_data = JSON.parse_string(FileAccess.get_file_as_string(game.storage_dir + "/progress.json"))
	check(progress_data is Dictionary and progress_data.size() == 6, "Completion data round-trips to disk for all six levels")
	var records = FileAccess.get_file_as_string(game.storage_dir + "/attempts.jsonl")
	check(records.contains("feedback") and records.contains("win"), "Local records include completion and optional feedback")
	var result = {"passed": failures.is_empty(), "checks": checks, "failures": failures}
	var file = FileAccess.open("res://../artifacts/ui-test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print("UI INTEGRATION TESTS: %d checks; %d failures" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
