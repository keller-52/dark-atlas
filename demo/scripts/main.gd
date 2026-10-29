extends Control

const Sim = preload("res://scripts/simulation.gd")
const Levels = preload("res://scripts/levels.gd")
const BG = Color("0b1520")
const PANEL = Color("101f2c")
const LINE = Color("2b414d")
const PAPER = Color("e4ddc9")
const MUTED = Color("8b9fa6")
const TEAL = Color("78d9cb")
const GOLD = Color("dfb978")
const ORANGE = Color("ed9172")

var levels: Array = Levels.all_levels()
var level_index = 0
var level: Dictionary
var state: Dictionary
var history: Array = []
var pending: Dictionary = {}
var preview: Dictionary = {}
var mode = "bridge"
var anchor = -1
var hover_node = -1
var hint_index = 0
var pulse = 0.0
var anim_t = 1.0
var anim_from: Dictionary = {}
var won_shown = false
var dialog: Control
var notice = ""
var notice_time = 0.0
var font: SystemFont
var ui_font: SystemFont
var labels: Dictionary = {}
var mode_buttons: Dictionary = {}
var level_buttons: Array = []
var execute_button: Button
var wait_button: Button
var undo_button: Button
var restart_button: Button
var next_button: Button
var sound_button: Button
var sound_enabled = true
var sound_player: AudioStreamPlayer
var progress: Dictionary = {}
var metrics: Dictionary = {}
var attempt_start = 0
var attempt_saved = false
var session_id = ""
var storage_dir = "res://playtest"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	ui_font = font
	var theme_data = Theme.new()
	theme_data.default_font = font
	theme_data.default_font_size = 17
	theme = theme_data
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -24
	add_child(sound_player)
	session_id = str(int(Time.get_unix_time_from_system()))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(storage_dir))
	_load_progress()
	_build_ui()
	_load_level(0)
	_show_dialog("欢迎来到墨线实验", "你和老铁皮，准备一起穿过断裂的荒原。\n\n① 选「画／擦桥」，依次点击两个锚点；也可以直接点路线。\n② 观察橙色箭头：它预告这次操作后猎犬会走的一步。\n③ 按空格或「执行一步」，你的操作生效，猎犬随后行动。\n④ 切换「墨」或「老铁皮」，点击相邻锚点，安排两位通过。\n\n每次操作消耗一步。随时按 Z 撤销，R 重来。\n六关都能直接选；先从第一关认识墨线回收。", "intro")

func _style(fill: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _label(key: String, rect: Rect2, size_px: int = 17, color: Color = PAPER) -> Label:
	var label = Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	labels[key] = label
	return label

func _button(text_value: String, rect: Rect2, callback: Callable, accent: bool = false) -> Button:
	var button = Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", BG if accent else PAPER)
	button.add_theme_color_override("font_hover_color", BG if accent else TEAL)
	button.add_theme_color_override("font_pressed_color", BG if accent else GOLD)
	button.add_theme_color_override("font_disabled_color", Color("536870"))
	button.add_theme_stylebox_override("normal", _style(TEAL if accent else Color("192d3a"), TEAL if accent else LINE))
	button.add_theme_stylebox_override("hover", _style(Color("9eeade") if accent else Color("233f4a"), TEAL))
	button.add_theme_stylebox_override("pressed", _style(GOLD if accent else Color("33453f"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("14242f"), Color("21343e")))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD))
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_ui() -> void:
	_label("brand", Rect2(36, 23, 620, 48), 31).text = "残光图志  /  墨线实验"
	_label("eyebrow", Rect2(38, 77, 780, 28), 15, MUTED).text = "一条路，三种去向。让你、老铁皮和猎犬，共用同一张地图。"
	sound_button = _button("声音：开", Rect2(1200, 38, 104, 38), _toggle_sound)
	_button("玩法说明", Rect2(1314, 38, 94, 38), _show_rules)
	_label("level_title", Rect2(54, 164, 740, 37), 23)
	_label("subtitle", Rect2(54, 206, 900, 32), 16, MUTED)
	_label("budget", Rect2(738, 166, 270, 35), 19, TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label("turn", Rect2(1080, 165, 310, 30), 16, GOLD)
	_label("action_label", Rect2(1080, 198, 310, 24), 15, MUTED).text = "选择操作，再在地图上落笔"
	mode_buttons.player = _button("1  墨", Rect2(1080, 234, 147, 44), func(): _set_mode("player"))
	mode_buttons.house = _button("2  老铁皮", Rect2(1237, 234, 151, 44), func(): _set_mode("house"))
	mode_buttons.bridge = _button("3  画／擦桥", Rect2(1080, 290, 147, 44), func(): _set_mode("bridge"))
	mode_buttons.stamp = _button("4  浓墨印章", Rect2(1237, 290, 151, 44), func(): _set_mode("stamp"))
	_label("pending", Rect2(1080, 351, 308, 62), 17)
	execute_button = _button("执行一步  ·  Space", Rect2(1080, 425, 308, 47), _commit, true)
	wait_button = _button("等一步", Rect2(1080, 486, 96, 37), func(): _stage({"kind": "wait"}))
	undo_button = _button("撤销 Z", Rect2(1186, 486, 96, 37), _undo)
	restart_button = _button("重来 R", Rect2(1292, 486, 96, 37), _restart)
	_label("forecast_title", Rect2(1080, 541, 308, 27), 16, ORANGE)
	_label("forecast", Rect2(1080, 574, 308, 85), 16, MUTED)
	_button("提示 H", Rect2(1080, 674, 146, 32), _hint)
	next_button = _button("下一关 →", Rect2(1237, 674, 151, 32), _next_level)
	_label("message", Rect2(54, 111, 1348, 30), 17, GOLD)
	_label("legend", Rect2(54, 684, 960, 29), 14, MUTED).text = "青色：可改墨桥    灰色：陆地栈道    细点线：仅墨通行    橙箭头：猎犬预测"
	_label("chapter", Rect2(52, 751, 1280, 24), 14, MUTED).text = "选择实验  /  六关均可直接试玩；完成后会留下一个小小的印记"
	for i in range(levels.size()):
		var index = i
		var button = _button("%02d  %s" % [i + 1, levels[i].concept], Rect2(50 + i * 224, 789, 211, 54), func(): _switch_level(index))
		button.add_theme_font_size_override("font_size", 16)
		level_buttons.append(button)
	_label("footer", Rect2(52, 867, 1348, 23), 13, MUTED).text = "推演中没有倒计时  ·  右键 / Esc 取消选择  ·  试玩记录仅保存在本机 demo/playtest，不联网"

func _load_level(index: int) -> void:
	level_index = clampi(index, 0, levels.size() - 1)
	level = levels[level_index]
	state = Sim.initial(level)
	history.clear()
	pending = {}
	preview = {}
	mode = "bridge"
	anchor = -1
	hint_index = 0
	anim_t = 1.0
	won_shown = false
	attempt_saved = false
	attempt_start = Time.get_ticks_msec()
	metrics = {"actions": 0, "undos": 0, "resets": 0, "hints": 0, "failures": 0, "stamps": 0, "draws": 0, "erases": 0}
	_set_notice(level.intro, 14)
	_refresh()

func _switch_level(index: int) -> void:
	if anim_t < 1:
		return
	_finish_attempt("left")
	_load_level(index)

func _set_mode(value: String) -> void:
	if anim_t < 1 or state.won or state.lost:
		return
	mode = value
	anchor = -1
	pending = {}
	_refresh()

func _stage(cmd: Dictionary) -> void:
	if anim_t < 1:
		return
	var error = Sim.validate(level, state, cmd)
	if error != "":
		_set_notice(error)
		_beep(175, 0.08)
		return
	pending = cmd
	anchor = -1
	_refresh()

func _describe(cmd: Dictionary) -> String:
	match cmd.get("kind", ""):
		"bridge":
			var e = level.edges[cmd.edge]
			return "%s %s—%s%s" % ["擦桥" if state.active[cmd.edge] else "架桥", level.nodes[e.a].name, level.nodes[e.b].name, "" if state.active[cmd.edge] else " · 落笔 " + level.nodes[cmd.get("to", e.b)].name]
		"move":
			return "%s → %s" % ["墨" if cmd.actor == "player" else "老铁皮", level.nodes[cmd.to].name]
		"stamp":
			return "在 %s 盖印章 · 剩余 %d 次" % [level.nodes[cmd.to].name, state.charges]
		"wait":
			return "等一步 · 让猎犬先行动"
	return ""

func _refresh() -> void:
	labels.level_title.text = "%02d  %s" % [level_index + 1, level.title]
	labels.subtitle.text = level.subtitle
	labels.budget.text = "墨线 %d / %d  ·  印章 %d" % [level.capacity - Sim.used_ink(level, state), level.capacity, state.charges]
	labels.turn.text = "图册推演  /  第 %02d 步" % state.turn
	var names = {"player": "墨", "house": "老铁皮", "bridge": "画／擦桥", "stamp": "浓墨印章"}
	if pending.is_empty():
		labels.pending.text = "正在选择：" + names[mode]
		if mode == "bridge":
			labels.pending.text += "\n" + ("再选一个锚点；第二点为落笔端。" if anchor >= 0 else "点击路线，或依次选择两个锚点。")
		else:
			labels.pending.text += "\n点击地图上的目的锚点。"
	else:
		labels.pending.text = "待执行：" + _describe(pending)
	var busy = anim_t < 1.0
	for key in mode_buttons:
		var button = mode_buttons[key]
		button.add_theme_stylebox_override("normal", _style(Color("294039") if mode == key else Color("192d3a"), TEAL if mode == key else LINE))
		button.disabled = busy or state.won or state.lost or (key == "stamp" and state.charges == 0)
	execute_button.disabled = busy or pending.is_empty() or state.won or state.lost
	wait_button.disabled = busy or state.won or state.lost
	undo_button.disabled = busy or history.is_empty()
	restart_button.disabled = busy
	next_button.text = "再玩一遍" if level_index == levels.size() - 1 else "下一关 →"
	next_button.disabled = busy
	if not state.won and not state.lost:
		preview = Sim.step(level, state, {"kind": "wait"} if pending.is_empty() else pending)
		if state.dog < 0:
			labels.forecast_title.text = "这一关，先认识墨线"
			labels.forecast.text = "两位都抵达金色终点即完成。\n擦除墨桥会完整回收额度。"
		else:
			var plan = preview.plan
			labels.forecast_title.text = "猎犬预测：%s → %s" % [level.nodes[state.dog].name, level.nodes[plan.to].name]
			labels.forecast.text = plan.reason
			if pending.is_empty():
				labels.forecast.text += "\n（当前显示等待一步的结果）"
			if preview.state.lost:
				labels.forecast_title.text = "危险：这一步会碰到老铁皮"
				labels.forecast.text += "\n你可以取消操作，重新安排。"
	elif state.won:
		labels.forecast_title.text = "两位旅伴，都平安抵达了"
		labels.forecast.text = "本次用了 %d 步。\n可以试试别的解法，或继续下一关。" % state.turn
	else:
		labels.forecast_title.text = "猎犬碰到了老铁皮"
		labels.forecast.text = "按 Z 回到上一步，换一种安排。\n本关没有重试次数限制。"
	for i in range(level_buttons.size()):
		var done = progress.has(str(i))
		level_buttons[i].text = "%02d  %s%s" % [i + 1, levels[i].concept, "  ✓" if done else ""]
		level_buttons[i].add_theme_stylebox_override("normal", _style(Color("253a3d") if i == level_index else Color("172835"), GOLD if i == level_index else LINE))
	queue_redraw()

func _commit() -> void:
	if pending.is_empty() or anim_t < 1 or is_instance_valid(dialog):
		return
	var result = Sim.step(level, state, pending)
	if not result.ok:
		_set_notice(result.error)
		return
	history.append(state.duplicate(true))
	anim_from = state.duplicate(true)
	metrics.actions += 1
	if pending.kind == "stamp":
		metrics.stamps += 1
	if pending.kind == "bridge":
		metrics["erases" if state.active[pending.edge] else "draws"] += 1
	state = result.state
	pending = {}
	anchor = -1
	anim_t = 0
	if state.lost:
		metrics.failures += 1
	_set_notice(state.last, 7)
	_beep(210 if state.lost else (620 if state.won else 390), 0.12)
	_refresh()

func _undo() -> void:
	if history.is_empty() or anim_t < 1:
		return
	state = history.pop_back()
	metrics.undos += 1
	pending = {}
	anchor = -1
	won_shown = false
	_set_notice("回到第 %d 步。试试另一种安排。" % state.turn)
	_beep(290, 0.07)
	_refresh()

func _restart() -> void:
	if anim_t < 1:
		return
	metrics.resets += 1
	_finish_attempt("restart")
	_load_level(level_index)

func _next_level() -> void:
	_switch_level((level_index + 1) % levels.size())

func _hint() -> void:
	metrics.hints += 1
	var hints = level.hints
	var text_value = hints[mini(hint_index, hints.size() - 1)]
	hint_index += 1
	_show_dialog("一点提示  /  %d" % mini(hint_index, hints.size()), text_value + "\n\n提示不会替你执行任何操作。关掉后可以继续推演。", "hint")

func _show_rules() -> void:
	_show_dialog("这本图册怎样回应你", "目标：让墨与老铁皮都到达金色终点。\n\n每次架桥、擦桥、移动、盖章或等待，都消耗一步；你的操作先发生，猎犬随后走一段。操作前的预测与实际执行使用相同规则。\n\n墨桥：青色实线可擦，青色虚线可画；旧墨线带短刻痕，不占额度也不可擦。灰色是固有陆地；细点线仅允许墨通过。\n\n猎犬：只沿有效墨线行动；追向连通区域里吸引力最高的节点。\n普通 1 ＜ 老铁皮 2 ＜ 新桥落笔端 3 ＜ 墨障 3.5 ＜ 印章 4。\n同值时选距离最近者，再按锚点字母排序；处在最高吸引源会停留。\n\n新桥落笔端只在本步有效。印章持续本步及后两步，只能同时留一枚；新章替换旧章。吞障后休眠一步。墨可与猎犬同岛，老铁皮与猎犬同岛则失败。\n\n桥上的移动是一次完整动作，动画期间不能操作；擦桥不会移除岛屿。Z 完整撤销，R 重来。", "rules")

func _show_dialog(title_text: String, body: String, kind: String) -> void:
	_close_dialog()
	dialog = Control.new()
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dialog)
	var shade = ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.05, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(shade)
	var height_px = 650 if kind == "rules" else (470 if kind == "intro" else 310)
	if kind == "result":
		height_px = 360
	var top = (900 - height_px) / 2.0
	var panel = Panel.new()
	panel.position = Vector2(278, top)
	panel.size = Vector2(884, height_px)
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 18))
	dialog.add_child(panel)
	var title = Label.new()
	title.position = Vector2(316, top + 28)
	title.size = Vector2(810, 48)
	title.text = title_text
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", GOLD)
	dialog.add_child(title)
	var body_label = Label.new()
	body_label.position = Vector2(318, top + 92)
	body_label.size = Vector2(802, height_px - 172)
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 17 if kind == "rules" else 19)
	body_label.add_theme_color_override("font_color", PAPER)
	dialog.add_child(body_label)
	if kind == "result":
		for i in range(3):
			var response = ["想再玩一关", "感觉有点重复", "规则没看懂"][i]
			var button = _button(response, Rect2(318 + i * 262, top + height_px - 116, 246, 38), func(): _record_feedback(response))
			remove_child(button)
			dialog.add_child(button)
	var close = _button("开始推演" if kind == "intro" else "继续探索", Rect2(840, top + height_px - 62, 280, 40), _close_dialog, true)
	remove_child(close)
	dialog.add_child(close)

func _close_dialog() -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()
		dialog = null

func _record_feedback(response: String) -> void:
	_append_record({"event": "feedback", "session": session_id, "level": level_index + 1, "response": response, "at": Time.get_datetime_string_from_system()})
	_close_dialog()
	_set_notice("已记下你的感受，记录仅保存在本机。")

func _load_progress() -> void:
	if FileAccess.file_exists(storage_dir + "/progress.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string(storage_dir + "/progress.json"))
		if data is Dictionary:
			progress = data

func _finish_attempt(outcome: String) -> void:
	if attempt_saved or state.is_empty():
		return
	if metrics.actions == 0 and outcome != "win":
		return
	var record = metrics.duplicate(true)
	record.merge({"event": "attempt", "session": session_id, "level": level_index + 1, "title": level.title,
		"outcome": outcome, "turns": state.turn, "elapsed_sec": snappedf((Time.get_ticks_msec() - attempt_start) / 1000.0, 0.1),
		"at": Time.get_datetime_string_from_system()}, true)
	_append_record(record)
	attempt_saved = true

func _append_record(record: Dictionary) -> void:
	var path = storage_dir + "/attempts.jsonl"
	var file = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(JSON.stringify(record))

func _set_notice(text_value: String, seconds: float = 6) -> void:
	notice = text_value
	notice_time = seconds
	if labels.has("message"):
		labels.message.text = text_value

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	sound_button.text = "声音：开" if sound_enabled else "声音：关"
	_beep(540, 0.08)

func _beep(hz: float, duration: float) -> void:
	if not sound_enabled or DisplayServer.get_name() == "headless":
		return
	var data = PackedByteArray()
	var samples = int(22050 * duration)
	data.resize(samples * 2)
	for i in range(samples):
		var envelope = sin(PI * float(i) / samples)
		var sample = int(sin(TAU * hz * i / 22050.0) * envelope * envelope * 14000)
		data.encode_s16(i * 2, sample)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	sound_player.stream = stream
	sound_player.play()

func _process(delta: float) -> void:
	pulse += delta
	if notice_time > 0:
		notice_time -= delta
		if notice_time <= 0:
			labels.message.text = level.intro if state.turn == 0 else "世界正等待你的下一笔。"
	if anim_t < 1:
		anim_t = minf(1, anim_t + delta / 0.34)
		if anim_t == 1:
			_refresh()
	if state.get("won", false) and anim_t == 1 and not won_shown:
		won_shown = true
		progress[str(level_index)] = {"turns": state.turn}
		var file = FileAccess.open(storage_dir + "/progress.json", FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(progress))
		_finish_attempt("win")
		_refresh()
		_show_dialog("两位都平安抵达了", "第 %02d 关 · %s\n本次 %d 步，撤销 %d 次。\n\n这段玩法给你的感觉如何？可选一个感受，或直接继续。" % [level_index + 1, level.title, state.turn, metrics.undos], "result")
	queue_redraw()

func _pos(index: int) -> Vector2:
	var p = level.nodes[index].pos
	return Vector2(48 + p.x * 1.02, 120 + p.y * 0.86)

func _actor_pos(actor: String) -> Vector2:
	if anim_t < 1 and anim_from.get(actor, -1) >= 0:
		return _pos(anim_from[actor]).lerp(_pos(state[actor]), smoothstep(0, 1, anim_t))
	return _pos(state[actor])

func _node_at(point: Vector2) -> int:
	for i in range(level.nodes.size()):
		if point.distance_to(_pos(i)) < 49:
			return i
	return -1

func _edge_at(point: Vector2) -> int:
	var best = -1
	var best_distance = 17.0
	for i in range(level.edges.size()):
		var e = level.edges[i]
		var a = _pos(e.a)
		var b = _pos(e.b)
		var closest = Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance = point.distance_to(closest)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(dialog):
			if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
				_close_dialog()
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_1: _set_mode("player")
			KEY_2: _set_mode("house")
			KEY_3: _set_mode("bridge")
			KEY_4: _set_mode("stamp")
			KEY_SPACE: _commit()
			KEY_Z: _undo()
			KEY_R: _restart()
			KEY_H: _hint()
			KEY_N: _next_level()
			KEY_F1: _show_rules()
			KEY_ESCAPE:
				pending = {}
				anchor = -1
				_refresh()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		hover_node = _node_at(event.position)
	if event is InputEventMouseButton and event.pressed and not is_instance_valid(dialog):
		if event.button_index == MOUSE_BUTTON_RIGHT:
			pending = {}
			anchor = -1
			_refresh()
			return
		if event.button_index != MOUSE_BUTTON_LEFT or anim_t < 1 or state.won or state.lost:
			return
		if not Rect2(32, 242, 1008, 431).has_point(event.position):
			return
		var node = _node_at(event.position)
		if node >= 0:
			if mode in ["player", "house"]:
				_stage({"kind": "move", "actor": mode, "to": node})
			elif mode == "stamp":
				_stage({"kind": "stamp", "to": node})
			elif anchor < 0:
				anchor = node
				pending = {}
				_refresh()
			elif node == anchor:
				anchor = -1
				_refresh()
			else:
				var found = false
				for i in range(level.edges.size()):
					var e = level.edges[i]
					if (e.a == anchor and e.b == node) or (e.b == anchor and e.a == node):
						_stage({"kind": "bridge", "edge": i, "to": node})
						found = true
						break
				if not found:
					_set_notice("这两个锚点之间没有可画路线。沿淡色虚线选择。")
					anchor = node
		elif mode == "bridge":
			var edge = _edge_at(event.position)
			if edge >= 0:
				_stage({"kind": "bridge", "edge": edge, "to": level.edges[edge].b})

func _draw() -> void:
	if state.is_empty() or font == null:
		return
	draw_rect(Rect2(0, 0, 1440, 900), BG)
	# Sparse cartographic grain and coastline contours, all native vector drawing.
	for x in range(20, 1440, 28):
		for y in range(15, 900, 28):
			draw_circle(Vector2(x, y), 0.65, Color(0.35, 0.49, 0.54, 0.09))
	draw_style_box(_style(Color("0e1c28"), LINE, 16), Rect2(32, 148, 1008, 574))
	draw_style_box(_style(PANEL, LINE, 16), Rect2(1060, 148, 348, 574))
	draw_style_box(_style(Color("0e1c28"), LINE, 14), Rect2(32, 740, 1376, 118))
	for row in range(7):
		var points = PackedVector2Array()
		for x in range(58, 1020, 12):
			points.append(Vector2(x, 287 + row * 52 + sin(x * 0.013 + row * 0.95) * 13 + sin(x * 0.023 + row) * 6))
		draw_polyline(points, Color(0.29, 0.43, 0.48, 0.075), 1, true)
	for i in range(level.edges.size()):
		_draw_edge(i)
	if not preview.is_empty() and state.dog >= 0 and not state.lost and not state.won:
		var dest = int(preview.plan.to)
		if dest != state.dog:
			_arrow(_pos(state.dog), _pos(dest), ORANGE, true)
	if pending.get("kind", "") == "move":
		_arrow(_pos(state[pending.actor]), _pos(pending.to), GOLD, false)
	for i in range(level.nodes.size()):
		_draw_island(i)
	if state.stamp >= 0 and state.stamp_ttl > 0:
		_draw_stamp(_pos(state.stamp) + Vector2(35, -31), state.stamp_ttl, false)
	if pending.get("kind", "") == "stamp":
		_draw_stamp(_pos(pending.to) + Vector2(35, -31), 3, true)
	var hp = _actor_pos("house")
	_draw_house(hp + Vector2(-9, -10), 1)
	var pp = _actor_pos("player")
	var same_island = pp.distance_to(hp) < 40
	_draw_player(pp + (Vector2(33, 6) if same_island else Vector2(0, -7)), 1)
	if state.dog >= 0:
		_draw_dog(_actor_pos("dog") + Vector2(-2, -7), 1, state.sleep > 0)
		if not preview.is_empty() and not state.won and not state.lost and preview.plan.to != state.dog:
			_draw_dog(_pos(preview.plan.to) + Vector2(-2, -7), 0.28, false)
	if state.lost:
		draw_rect(Rect2(34, 150, 1004, 570), Color(0.6, 0.13, 0.08, 0.07))
	_draw_compass(Vector2(979, 271))

func _draw_edge(index: int) -> void:
	var e = level.edges[index]
	var a = _pos(e.a)
	var b = _pos(e.b)
	var direction = a.direction_to(b)
	a += direction * 38
	b -= direction * 38
	if e.kind == "land":
		if e.get("narrow", false):
			draw_dashed_line(a, b, Color("587078"), 2, 3, true)
		else:
			draw_line(a, b, Color("293b45"), 13, true)
			draw_line(a, b, Color("61777b"), 2, true)
			var normal = direction.orthogonal() * 5
			var distance = a.distance_to(b)
			for t in range(12, int(distance), 15):
				var p = a + direction * t
				draw_line(p - normal, p + normal, Color("43585e"), 1, true)
	elif state.active[index]:
		draw_line(a, b, Color(TEAL, 0.08), 15, true)
		draw_line(a, b, Color(TEAL, 0.25), 6, true)
		draw_line(a, b, Color("69b8b1") if e.get("fixed", false) else TEAL, 2.6, true)
		if e.get("fixed", false):
			var p = a.lerp(b, 0.5)
			var normal = direction.orthogonal() * 6
			draw_line(p - normal, p + normal, GOLD, 2, true)
			draw_line(p - normal + direction * 6, p + normal + direction * 6, GOLD, 2, true)
	else:
		draw_dashed_line(a, b, Color("34505d"), 1.6, 7, true)
		var p = a.lerp(b, 0.5)
		draw_circle(p, 10, Color("162c38"))
		draw_line(p + Vector2(-4, 0), p + Vector2(4, 0), Color("617f89"), 1)
		draw_line(p + Vector2(0, -4), p + Vector2(0, 4), Color("617f89"), 1)
	if pending.get("kind", "") == "bridge" and pending.edge == index:
		var color = ORANGE if state.active[index] else GOLD
		draw_dashed_line(a, b, color, 3, 8, true)
		if state.active[index]:
			var p = a.lerp(b, 0.5)
			draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), ORANGE, 3, true)
			draw_line(p + Vector2(8, -8), p + Vector2(-8, 8), ORANGE, 3, true)
		else:
			var tip = _pos(pending.get("to", e.b))
			draw_arc(tip, 47, 0, TAU, 42, Color(GOLD, 0.7 + sin(pulse * 4) * 0.2), 2, true)

func _draw_island(index: int) -> void:
	var p = _pos(index)
	var shape = PackedVector2Array()
	var shadow = PackedVector2Array()
	for i in range(12):
		var angle = i * TAU / 12
		var radius = 39 + sin(i * 5.3 + index * 2.2) * 5
		var vertex = p + Vector2(cos(angle), sin(angle) * 0.77) * radius
		shape.append(vertex)
		shadow.append(vertex + Vector2(0, 9))
	draw_colored_polygon(shadow, Color("09131c"))
	var is_blocked = Sim.blocked(level, state, index)
	draw_colored_polygon(shape, Color("27363b") if not is_blocked else Color("262334"))
	var border = Color("566a6d")
	if index == level.goal:
		border = GOLD
	if index == anchor or index == hover_node:
		border = TEAL
	shape.append(shape[0])
	draw_polyline(shape, border, 1.6, true)
	draw_arc(p, 26, 0, TAU, 36, Color("415452"), 1, true)
	if index == level.goal:
		draw_arc(p, 47, 0, TAU, 48, Color(GOLD, 0.22), 1.5, true)
		var flag = p + Vector2(26, -24)
		draw_line(flag, flag + Vector2(0, -28), GOLD, 2, true)
		draw_colored_polygon(PackedVector2Array([flag + Vector2(0, -28), flag + Vector2(20, -20), flag + Vector2(0, -12)]), GOLD)
	if is_blocked:
		var blob = PackedVector2Array()
		for i in range(16):
			var a = i * TAU / 16
			var r = 27 if i % 2 == 0 else 19
			blob.append(p + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(blob, Color("0b0f19"))
		draw_arc(p, 22, pulse * 0.2, pulse * 0.2 + 4.5, 24, Color("a68bbb"), 2, true)
		draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), Color("a68bbb"), 3, true)
		draw_line(p + Vector2(7, -7), p + Vector2(-7, 7), Color("a68bbb"), 3, true)
	var text_value = level.nodes[index].name
	if index == level.goal:
		text_value += " · 终点"
	if is_blocked:
		text_value += " · 墨障"
	elif index in state.cleared:
		text_value += " · 已开路"
	var width = font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, p + Vector2(-width / 2, 59), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD if index == level.goal else MUTED)
	if anchor == index:
		draw_arc(p, 49, 0, TAU, 40, TEAL, 2, true)

func _arrow(a: Vector2, b: Vector2, color: Color, dashed: bool) -> void:
	var d = a.direction_to(b)
	var start = a + d * 50
	var end = b - d * 48
	var offset = d.orthogonal() * 12
	if dashed:
		draw_dashed_line(start + offset, end + offset, Color(color, 0.8), 2.5, 9, true)
	else:
		draw_line(start + offset, end + offset, color, 2.5, true)
	var tip = end + offset
	draw_colored_polygon(PackedVector2Array([tip, tip - d * 13 + d.orthogonal() * 6, tip - d * 13 - d.orthogonal() * 6]), color)

func _draw_house(p: Vector2, alpha: float) -> void:
	var warm = Color(GOLD, alpha)
	draw_circle(p + Vector2(1, 8), 35, Color(GOLD, alpha * 0.055))
	for dx in [-17, 17]:
		draw_line(p + Vector2(dx, 16), p + Vector2(dx + sin(pulse * 2) * 2, 27), Color("8a9a91", alpha), 4, true)
		draw_line(p + Vector2(dx - 5, 27), p + Vector2(dx + 7, 27), warm, 3, true)
	draw_style_box(_style(Color("797b6a", alpha), warm, 3), Rect2(p + Vector2(-25, -15), Vector2(50, 37)))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-33, -14), p + Vector2(-5, -37), p + Vector2(31, -14)]), Color("b4a78a", alpha))
	draw_polyline(PackedVector2Array([p + Vector2(-33, -14), p + Vector2(-5, -37), p + Vector2(31, -14)]), PAPER, 2, true)
	draw_rect(Rect2(p + Vector2(12, -37), Vector2(8, 16)), Color("73858a", alpha))
	draw_rect(Rect2(p + Vector2(-16, -8), Vector2(11, 12)), warm)
	draw_rect(Rect2(p + Vector2(8, -8), Vector2(11, 12)), warm)
	draw_rect(Rect2(p + Vector2(-4, 6), Vector2(10, 16)), Color("36484b", alpha))
	for i in range(3):
		var drift = fmod(pulse * 0.4 + i * 0.32, 1.0)
		draw_circle(p + Vector2(17 + sin(drift * 4 + i) * 5, -42 - drift * 25), 3 + drift * 4, Color(MUTED, (1 - drift) * 0.17 * alpha))

func _draw_player(p: Vector2, alpha: float) -> void:
	draw_circle(p + Vector2(0, 15), 11, Color(0, 0, 0, alpha * 0.22))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(-12, 15), p + Vector2(11, 15)]), Color(TEAL, alpha))
	draw_line(p + Vector2(-4, 13), p + Vector2(-5, 21), Color(PAPER, alpha), 2, true)
	draw_line(p + Vector2(4, 13), p + Vector2(6, 21), Color(PAPER, alpha), 2, true)
	draw_circle(p + Vector2(0, -13), 7, Color(PAPER, alpha))
	draw_arc(p + Vector2(0, -13), 9, PI, TAU, 15, Color("234b50", alpha), 5, true)
	draw_line(p + Vector2(9, 0), p + Vector2(18, 6), Color(GOLD, alpha), 2, true)

func _draw_dog(p: Vector2, alpha: float, sleeping: bool) -> void:
	var color = Color(ORANGE, alpha)
	draw_circle(p + Vector2(0, 10), 23, Color(ORANGE, 0.07 * alpha))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-24, -2), p + Vector2(-12, -13), p + Vector2(6, -10), p + Vector2(15, -20), p + Vector2(20, -14), p + Vector2(27, -3), p + Vector2(14, 5), p + Vector2(-10, 6)]), Color("261e23", alpha))
	draw_polyline(PackedVector2Array([p + Vector2(-27, -11), p + Vector2(-19, 0), p + Vector2(-12, -13), p + Vector2(6, -10), p + Vector2(15, -20), p + Vector2(20, -14), p + Vector2(27, -3)]), color, 2.5, true)
	for dx in [-12, 9]:
		draw_line(p + Vector2(dx, 4), p + Vector2(dx - 5, 15), color, 3, true)
	draw_circle(p + Vector2(17, -8), 2.4, color)
	if sleeping:
		draw_string(font, p + Vector2(14, -34), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)

func _draw_stamp(p: Vector2, ttl: int, ghost: bool) -> void:
	var color = Color(GOLD, 0.5 if ghost else 1)
	draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color(GOLD, 0.06), true)
	draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), color, false, 2)
	draw_line(p + Vector2(-7, 6), p + Vector2(0, -7), color, 2, true)
	draw_line(p + Vector2(0, -7), p + Vector2(7, 6), color, 2, true)
	draw_string(font, p + Vector2(19, 5), str(ttl), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func _draw_compass(p: Vector2) -> void:
	var c = Color(MUTED, 0.35)
	draw_arc(p, 21, 0, TAU, 32, c, 1, true)
	draw_line(p - Vector2(0, 29), p + Vector2(0, 29), c, 1, true)
	draw_line(p - Vector2(29, 0), p + Vector2(29, 0), c, 1, true)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(5, 7), p + Vector2(0, 2), p + Vector2(-5, 7)]), Color(GOLD, 0.6))
	draw_string(font, p + Vector2(-5, -34), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not state.is_empty():
		_finish_attempt("closed")
