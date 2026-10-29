extends RefCounted
## Pure deterministic rules shared by the preview, actual execution and tests.

static func initial(level: Dictionary) -> Dictionary:
	var active: Array = []
	for e in level.edges:
		active.append(bool(e.get("active", e.kind != "ink" or e.get("fixed", false))))
	return {"player": level.player, "house": level.house, "dog": level.get("dog", -1),
		"active": active, "cleared": [], "stamp": -1, "stamp_ttl": 0,
		"charges": level.get("stamps", 0), "sleep": 0, "turn": 0,
		"lost": false, "won": false, "last": "", "fresh": -1}

static func used_ink(level: Dictionary, s: Dictionary) -> int:
	var used = 0
	for i in range(level.edges.size()):
		var e = level.edges[i]
		if e.kind == "ink" and not e.get("fixed", false) and s.active[i]:
			used += int(e.get("cost", 1))
	return used

static func blocked(level: Dictionary, s: Dictionary, node: int) -> bool:
	return node in level.get("barriers", []) and node not in s.cleared

static func edge_open(e: Dictionary, s: Dictionary) -> bool:
	for required in e.get("requires", []):
		if required not in s.cleared:
			return false
	return true

static func neighbors(level: Dictionary, s: Dictionary, node: int, actor: String) -> Array:
	var out: Array = []
	for i in range(level.edges.size()):
		var e = level.edges[i]
		if not s.active[i] or not edge_open(e, s):
			continue
		if actor == "dog" and e.kind != "ink":
			continue
		if actor == "house" and e.get("narrow", false):
			continue
		var dest = -1
		if e.a == node:
			dest = int(e.b)
		elif e.b == node:
			dest = int(e.a)
		if dest < 0:
			continue
		if actor != "dog" and blocked(level, s, dest):
			continue
		out.append(dest)
	out.sort()
	return out

static func validate(level: Dictionary, s: Dictionary, cmd: Dictionary) -> String:
	if s.lost or s.won:
		return "本次尝试已结束，可以撤销或重来。"
	var kind = cmd.get("kind", "")
	if kind == "wait":
		return ""
	if kind == "bridge":
		var i = int(cmd.get("edge", -1))
		if i < 0 or i >= level.edges.size():
			return "请选择两个相连的锚点。"
		var e = level.edges[i]
		if e.kind != "ink" or e.get("fixed", false):
			return "旧墨线与陆地栈道不可擦除。"
		if not s.active[i] and used_ink(level, s) + int(e.get("cost", 1)) > level.capacity:
			return "墨线额度不足。先擦掉一座旧桥。"
		if int(cmd.get("to", e.b)) not in [e.a, e.b]:
			return "落笔端必须位于桥的端点。"
		return ""
	if kind == "move":
		var actor = cmd.get("actor", "player")
		if actor not in ["player", "house"]:
			return "请选择墨或老铁皮。"
		var dest = int(cmd.get("to", -1))
		if dest in neighbors(level, s, int(s[actor]), actor):
			return ""
		return "这里暂时无法抵达：需要相邻通路，并清除目的地的墨障。"
	if kind == "stamp":
		if s.charges <= 0:
			return "本关的印章已用完。"
		if int(cmd.get("to", -1)) < 0 or int(cmd.get("to", -1)) >= level.nodes.size():
			return "请选择一个锚点。"
		return ""
	return "请选择一个操作。"

static func heat(level: Dictionary, s: Dictionary, node: int) -> float:
	var value = 1.0
	if node == s.house:
		value = 2.0
	if node == s.fresh:
		value = 3.0
	if blocked(level, s, node):
		value = 3.5
	if node == s.stamp and s.stamp_ttl > 0:
		value = 4.0
	return value

static func dog_plan(level: Dictionary, s: Dictionary) -> Dictionary:
	if s.dog < 0:
		return {"to": -1, "target": -1, "reason": "本关没有猎犬。"}
	if s.sleep > 0:
		return {"to": s.dog, "target": s.dog, "reason": "饱食休眠，本步不移动。"}
	var queue: Array = [s.dog]
	var parent: Dictionary = {s.dog: -1}
	var distance: Dictionary = {s.dog: 0}
	var index = 0
	while index < queue.size():
		var at = int(queue[index])
		index += 1
		for next in neighbors(level, s, at, "dog"):
			if not parent.has(next):
				parent[next] = at
				distance[next] = int(distance[at]) + 1
				queue.append(next)
	var target = int(s.dog)
	for node in queue:
		var h = heat(level, s, node)
		var best_h = heat(level, s, target)
		if h > best_h or (is_equal_approx(h, best_h) and (distance[node] < distance[target] or (distance[node] == distance[target] and node < target))):
			target = node
	var next_node = target
	while next_node != s.dog and parent[next_node] != s.dog:
		next_node = int(parent[next_node])
	var reason = "原地停留：当前节点已是最近的最高吸引源。"
	if target != s.dog:
		var source = "普通节点"
		if target == s.house:
			source = "老铁皮"
		if target == s.fresh:
			source = "新桥落笔端"
		if blocked(level, s, target):
			source = "墨障"
		if target == s.stamp and s.stamp_ttl > 0:
			source = "浓墨印章"
		reason = "追向%s %s（吸引力 %.1f）。" % [source, level.nodes[target].name, heat(level, s, target)]
	return {"to": next_node, "target": target, "reason": reason}

static func step(level: Dictionary, before: Dictionary, cmd: Dictionary) -> Dictionary:
	var s = before.duplicate(true)
	var error = validate(level, s, cmd)
	if error != "":
		return {"ok": false, "state": s, "error": error, "events": []}
	var events: Array = []
	s.fresh = -1
	match cmd.kind:
		"bridge":
			var i = int(cmd.edge)
			var e = level.edges[i]
			s.active[i] = not s.active[i]
			if s.active[i]:
				s.fresh = int(cmd.get("to", e.b))
				events.append("架桥 %s—%s，落笔端 %s。" % [level.nodes[e.a].name, level.nodes[e.b].name, level.nodes[s.fresh].name])
			else:
				events.append("擦除 %s—%s，收回墨线。" % [level.nodes[e.a].name, level.nodes[e.b].name])
		"move":
			s[cmd.actor] = int(cmd.to)
			events.append("%s抵达 %s。" % ["墨" if cmd.actor == "player" else "老铁皮", level.nodes[cmd.to].name])
		"stamp":
			s.stamp = int(cmd.to)
			s.stamp_ttl = 3
			s.charges -= 1
			events.append("在 %s 盖章，持续本步及后两步。" % level.nodes[cmd.to].name)
		"wait":
			events.append("等待一步。")
	var plan = dog_plan(level, s)
	var was_sleeping = s.sleep > 0
	if was_sleeping:
		s.sleep -= 1
	elif s.dog >= 0:
		s.dog = int(plan.to)
		if blocked(level, s, s.dog):
			s.cleared.append(s.dog)
			s.cleared.sort()
			s.sleep = 1
			events.append("猎犬吞掉 %s 的墨障，下步休眠。" % level.nodes[s.dog].name)
	if s.dog >= 0 and s.dog == s.house:
		s.lost = true
		events.append("猎犬碰到老铁皮。按 Z 撤销，再试另一种安排。")
	if s.stamp_ttl > 0:
		s.stamp_ttl -= 1
		if s.stamp_ttl == 0:
			s.stamp = -1
	s.turn += 1
	var cleared_all = true
	for node in level.get("required_clear", []):
		if node not in s.cleared:
			cleared_all = false
	s.won = not s.lost and s.player == level.goal and s.house == level.goal and cleared_all
	s.fresh = -1
	s.last = " ".join(events)
	return {"ok": true, "state": s, "events": events, "plan": plan}

static func actions(level: Dictionary, s: Dictionary) -> Array:
	var cmds: Array = [{"kind": "wait"}]
	for actor in ["player", "house"]:
		for dest in neighbors(level, s, int(s[actor]), actor):
			cmds.append({"kind": "move", "actor": actor, "to": dest})
	for i in range(level.edges.size()):
		var e = level.edges[i]
		if e.kind == "ink" and not e.get("fixed", false):
			var cmd = {"kind": "bridge", "edge": i, "to": e.b}
			if validate(level, s, cmd) == "":
				cmds.append(cmd)
				if not s.active[i]:
					cmds.append({"kind": "bridge", "edge": i, "to": e.a})
	if s.charges > 0:
		for i in range(level.nodes.size()):
			cmds.append({"kind": "stamp", "to": i})
	return cmds

static func state_key(s: Dictionary) -> String:
	return str([s.player, s.house, s.dog, s.active, s.cleared, s.stamp, s.stamp_ttl, s.charges, s.sleep])
