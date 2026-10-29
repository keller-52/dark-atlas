extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Levels = preload("res://scripts/levels.gd")
var checks = 0
var failures: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func b(edge: int, to: int = -1) -> Dictionary:
	var cmd = {"kind": "bridge", "edge": edge}
	if to >= 0:
		cmd.to = to
	return cmd

func m(actor: String, to: int) -> Dictionary:
	return {"kind": "move", "actor": actor, "to": to}

func w() -> Dictionary:
	return {"kind": "wait"}

func solutions() -> Array:
	return [
		[b(0, 1), m("house", 1), m("player", 1), b(0), b(1, 2), m("house", 2), m("player", 2)],
		[b(2), m("house", 1), m("player", 1), b(0), b(1, 2), m("house", 2), m("player", 2)],
		[b(2, 2), m("player", 1), m("house", 1), b(4, 5), b(4), m("house", 2), m("house", 3), m("player", 2), m("player", 3)],
		[b(2, 2), b(3, 3), m("house", 1), m("player", 1), b(2), b(4, 5), b(4), b(2, 2), m("house", 2), m("house", 3), m("house", 6), m("player", 2), m("player", 3), m("player", 6)],
		[m("house", 1), b(3), m("house", 4), m("player", 4)],
		[b(2, 2), b(3, 3), b(2), b(4, 6), b(3), w(), w(), b(5, 5), b(5), b(4), b(6, 7), b(7, 3), m("house", 1), m("house", 7), m("player", 7), b(6), m("house", 3), m("player", 3), b(7), b(4, 6), m("house", 6), m("player", 6)]
	]

func _initialize() -> void:
	var levels = Levels.all_levels()
	var replay_results: Array = []
	for i in range(levels.size()):
		var level = levels[i]
		var state = Sim.initial(level)
		var step_index = 0
		for cmd in solutions()[i]:
			var immutable_before = JSON.stringify(state)
			var prediction = Sim.step(level, state, cmd)
			check(prediction.ok, "Level %d step %d command is valid" % [i + 1, step_index + 1])
			if not prediction.ok:
				break
			check(JSON.stringify(state) == immutable_before, "Preview must never mutate current state")
			var execution = Sim.step(level, state, cmd)
			check(JSON.stringify(prediction) == JSON.stringify(execution), "Prediction must match execution")
			state = execution.state
			check(not state.lost, "Level %d solution must keep the house safe at step %d" % [i + 1, step_index + 1])
			check(Sim.used_ink(level, state) <= level.capacity, "Ink capacity is never exceeded")
			step_index += 1
		check(state.won, "Level %d has a complete playable solution" % [i + 1])
		for barrier in level.barriers:
			check(barrier in state.cleared, "Level %d solution uses the dog to clear all barriers" % [i + 1])
		replay_results.append({"level": i + 1, "title": level.title, "won": state.won, "turns": state.turn, "commands": solutions()[i]})
		print("LEVEL %d: %s, won=%s, turns=%d" % [i + 1, level.title, state.won, state.turn])
	_test_boundaries(levels)
	_test_random_transitions(levels)
	var result = {"passed": failures.is_empty(), "checks": checks, "failures": failures, "levels": replay_results}
	var file = FileAccess.open("res://../artifacts/test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "\t"))
	print("RULE TESTS: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_boundaries(levels: Array) -> void:
	var level = levels[0]
	var state = Sim.initial(level)
	state = Sim.step(level, state, b(0, 1)).state
	var full = Sim.step(level, state, b(1, 2))
	check(not full.ok, "Cannot exceed bridge budget")
	check(full.state == state, "Invalid action changes nothing and consumes no turn")
	state = Sim.step(level, state, b(0)).state
	check(Sim.used_ink(level, state) == 0, "Erasing returns full ink quota")
	check(state.player == 0 and state.house == 0, "Erasing preserves actors standing on islands")
	level = levels[2]
	state = Sim.initial(level)
	check(Sim.validate(level, state, b(1)) != "", "Fixed ink cannot be erased")
	check(Sim.validate(level, state, m("house", 2)) != "", "Actors cannot enter blocked destinations")
	check(Sim.neighbors(level, state, 0, "dog").is_empty(), "Dog cannot use land walkways")
	state = Sim.step(level, state, b(2, 2)).state
	check(state.dog == 1, "Dog walks exactly one edge toward a distant obstacle")
	state = Sim.step(level, state, w()).state
	check(state.dog == 2 and 2 in state.cleared and state.sleep == 1, "Dog clears barrier and gains one rest turn")
	var sleep_result = Sim.step(level, state, {"kind": "stamp", "to": 5})
	state = sleep_result.state
	check(state.dog == 2 and state.sleep == 0, "Dog rests exactly one action after eating")
	check(state.stamp_ttl == 2 and state.charges == 0, "Stamp includes placement action in its three-step lifetime")
	check(Sim.validate(level, state, {"kind": "stamp", "to": 5}) != "", "Used stamp charge cannot be reused")
	state = Sim.step(level, state, w()).state
	check(state.stamp_ttl == 1, "Stamp second action lifetime")
	state = Sim.step(level, state, w()).state
	check(state.stamp_ttl == 0 and state.stamp == -1, "Stamp expires after exactly three actions")
	level = levels[4]
	state = Sim.initial(level)
	check(4 in Sim.neighbors(level, state, 0, "player"), "Player can use the narrow walkway")
	check(4 not in Sim.neighbors(level, state, 0, "house"), "House cannot use the narrow walkway")
	check(Sim.dog_plan(level, state).to == 4, "Dog stays without a reachable stronger attraction")
	state = Sim.step(level, state, m("house", 1)).state
	check(state.dog == 3, "House parking position changes the dog's plan")
	var unsafe = Sim.step(level, state, m("house", 4))
	check(unsafe.state.lost, "Dangerous move is correctly predicted as a loss")
	check(not state.lost, "Predicting a loss does not apply that loss")
	var safe = Sim.step(level, state, b(3))
	check(not safe.state.lost and safe.state.dog == 2, "Disconnecting after luring keeps the exit safe")
	var tie_level = {"nodes": [Levels.n("A", 0, 0), Levels.n("B", 0, 0), Levels.n("C", 0, 0)],
		"edges": [Levels.ink(0, 2, true, true), Levels.ink(0, 1, true, true)],
		"player": 0, "house": 0, "dog": 0, "goal": 2, "capacity": 0, "barriers": [1, 2]}
	state = Sim.initial(tie_level)
	state.house = -1
	check(Sim.dog_plan(tie_level, state).to == 1, "Equal-distance ties use anchor order, not edge insertion order")
	level = levels[5]
	state = Sim.initial(level)
	state.player = level.goal
	state.house = level.goal
	state.dog = -1
	check(not Sim.step(level, state, w()).state.won, "Final level requires all stated barriers cleared")

func _test_random_transitions(levels: Array) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 928416
	for level in levels:
		var state = Sim.initial(level)
		for i in range(100):
			if state.lost or state.won:
				state = Sim.initial(level)
			var cmds = Sim.actions(level, state)
			var cmd = cmds[rng.randi_range(0, cmds.size() - 1)]
			var before = JSON.stringify(state)
			var result = Sim.step(level, state, cmd)
			check(result.ok, "Generated legal actions stay valid")
			check(before == JSON.stringify(state), "Exploration preview preserves source snapshot")
			check(Sim.used_ink(level, result.state) <= level.capacity, "Random transitions respect ink capacity")
			check(result.state.turn == state.turn + 1, "Every successful action advances exactly one step")
			check(result.state.cleared.size() >= state.cleared.size(), "Cleared obstacles stay cleared")
			state = result.state
