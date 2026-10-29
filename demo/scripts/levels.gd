extends RefCounted

static func n(label: String, x: float, y: float) -> Dictionary:
	return {"name": label, "pos": Vector2(x, y)}

static func ink(a: int, b: int, active: bool = false, fixed: bool = false) -> Dictionary:
	return {"a": a, "b": b, "kind": "ink", "active": active or fixed, "fixed": fixed}

static func land(a: int, b: int, narrow: bool = false) -> Dictionary:
	return {"a": a, "b": b, "kind": "land", "active": true, "narrow": narrow}

static func all_levels() -> Array:
	return [
		{"title": "第一座桥", "subtitle": "让有限的墨线，陪你们走得更远。", "concept": "墨线回收",
			"nodes": [n("A", 160, 380), n("B", 440, 270), n("C", 740, 380)],
			"edges": [ink(0, 1), ink(1, 2)], "player": 0, "house": 0, "dog": -1,
			"goal": 2, "capacity": 1, "stamps": 0, "barriers": [],
			"intro": "你只有一份墨线。先让两位旅伴都抵达 B，再擦桥回收，继续前往 C。",
			"hints": ["选「画／擦桥」，依次点击 A、B。再按空格执行。", "选「老铁皮」或「墨」，点击相邻目的地并执行。", "两位都到 B 后，擦掉 A—B，额度就能用来连接 B—C。"]},
		{"title": "剪断追来的路", "subtitle": "有时，一笔擦除比一笔连接更重要。", "concept": "隔离猎犬",
			"nodes": [n("A", 160, 340), n("B", 440, 340), n("C", 750, 340), n("D", 440, 580)],
			"edges": [ink(0, 1, true), ink(1, 2), ink(1, 3, true)],
			"player": 0, "house": 0, "dog": 3, "goal": 2, "capacity": 2, "stamps": 0, "barriers": [],
			"intro": "猎犬正沿 D—B—A 追向老铁皮。先改变连接，再安排你们通过。",
			"hints": ["先看橙色虚线：它标出本次操作后猎犬真正会走的一步。", "擦掉 B—D，可以把猎犬留在 D。", "两位先到 B，再把 A—B 的墨线回收给 B—C。"]},
		{"title": "请它开门", "subtitle": "危险也能成为开路的帮手。", "concept": "诱导与拆障",
			"nodes": [n("A", 140, 430), n("B", 350, 430), n("C", 570, 430), n("D", 790, 430), n("E", 350, 190), n("F", 650, 190)],
			"edges": [land(0, 1), ink(4, 1, true, true), ink(1, 2), land(2, 3), ink(2, 5)],
			"player": 0, "house": 0, "dog": 4, "goal": 3, "capacity": 2, "stamps": 1, "barriers": [2],
			"intro": "C 的墨障挡住前路。接来猎犬吞掉它，再为老铁皮安排一条安全的通路。",
			"hints": ["接通 B—C 后，猎犬会被墨障吸引。它每步只走一段。", "吞障后猎犬会休眠一步。可以趁机安排下一段路线。", "从 C 向 F 落笔能诱导它去 F。等它抵达，再擦掉 C—F。印章能额外稳住目标。"]},
		{"title": "还要再借一次", "subtitle": "现在就关住它，下一道门谁来开？", "concept": "重复利用与额度",
			"nodes": [n("A", 120, 450), n("B", 320, 450), n("C", 510, 450), n("D", 700, 360), n("E", 320, 190), n("F", 700, 150), n("G", 880, 480)],
			"edges": [land(0, 1), ink(4, 1, true, true), ink(1, 2), ink(2, 3), ink(3, 5), land(3, 6)],
			"player": 0, "house": 0, "dog": 4, "goal": 6, "capacity": 2, "stamps": 1, "barriers": [2, 3],
			"intro": "两道墨障，两份墨线。先让猎犬完成两次开路，再决定怎样隔离它。",
			"hints": ["猎犬需要先后到达 C 和 D。别在它完成工作前永久切断通路。", "猎犬在 D 休眠时，可以暂时擦掉 B—C，腾出一份墨线。", "用腾出的额度连接 D—F，把猎犬引去 F 并隔离，再恢复你们要走的路。"]},
		{"title": "老铁皮也是路标", "subtitle": "它停在哪里，世界就会作出不同回应。", "concept": "同伴参与解谜",
			"nodes": [n("A", 160, 510), n("B", 350, 510), n("C", 350, 280), n("D", 590, 220), n("E", 780, 420)],
			"edges": [land(0, 1), ink(1, 2, true, true), ink(2, 3, true, true), ink(3, 4, true), land(1, 4), land(0, 4, true)],
			"player": 0, "house": 0, "dog": 4, "goal": 4, "capacity": 1, "stamps": 0, "barriers": [],
			"intro": "猎犬守着 E。这里没有印章。让老铁皮进入旧墨线网络，把猎犬引离终点。",
			"hints": ["陆地栈道不会传递墨线吸引；老铁皮停在 A 时猎犬会留在 E。", "先把老铁皮移到 B。猎犬会从 E 走向 D。", "然后擦掉 D—E。猎犬留在另一侧，你们可以沿陆地栈道前往 E。细点线只允许墨通过。"]},
		{"title": "一起走过最后一桥", "subtitle": "把开路、回收和同行，放进同一个计划里。", "concept": "综合调度",
			"nodes": [n("A", 130, 470), n("B", 320, 380), n("C", 500, 220), n("D", 690, 380), n("E", 300, 150), n("F", 830, 170), n("G", 880, 500), n("H", 500, 550)],
			"edges": [land(0, 1), ink(4, 1, true, true), ink(1, 2), ink(2, 3), ink(3, 6), ink(6, 5), ink(1, 7), ink(7, 3), land(0, 7, true)],
			"player": 0, "house": 0, "dog": 4, "goal": 6, "capacity": 2, "stamps": 2, "barriers": [2, 3, 6], "required_clear": [2, 3, 6],
			"intro": "三道墨障，仍然只有两份墨线。你可以走细栈道侦察，老铁皮需要完整的桥。",
			"hints": ["先规划猎犬依次吞掉 C、D、G 的路线。两份额度需要沿途回收。", "猎犬到 D 后，可以把 B—C 换成 D—G。旧桥被擦掉时，岛上的角色仍然安全。", "最后把猎犬从 G 引往 F 并断开。之后恢复老铁皮需要的路线，分段回收额度。"]}
	]
