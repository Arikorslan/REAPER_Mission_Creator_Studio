extends RefCounted


const MAX_STEPS := 80
var limit := MAX_STEPS
var _undo: Array = []
var _redo: Array = []
var _merge_label := ""
var _merge_time := 0

func clear() -> void:
	_undo.clear(); _redo.clear(); _merge_label = ""; _merge_time = 0
func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()
func undo_depth() -> int: return _undo.size()
func redo_depth() -> int: return _redo.size()
func next_undo_label() -> String: return "" if _undo.is_empty() else str(_undo[-1].get("label", ""))
func next_redo_label() -> String: return "" if _redo.is_empty() else str(_redo[-1].get("label", ""))

func snapshot(state, label: String, merge := false) -> void:
	if state == null: return
	var now := Time.get_ticks_msec()
	if merge and label == _merge_label and now - _merge_time < 450 and not _undo.is_empty():
		_merge_time = now; _redo.clear(); return
	_undo.append({ "label": label, "data": state.data.duplicate(true), "selected": str(state.selected_id)})
	if _undo.size() > limit: _undo.pop_front()
	_redo.clear(); _merge_label = label if merge else ""; _merge_time = now

func push_document(previous: Dictionary, selected: String, label: String, merge := false) -> void:
	if previous.is_empty(): return
	var now := Time.get_ticks_msec()
	if merge and label == _merge_label and now - _merge_time < 700 and not _undo.is_empty():
		_merge_time = now; _redo.clear(); return
	_undo.append({ "label": label, "data": previous.duplicate(true), "selected": selected})
	if _undo.size() > limit: _undo.pop_front()
	_redo.clear(); _merge_label = label if merge else ""; _merge_time = now

func undo(state) -> String:
	if state == null or _undo.is_empty(): return ""
	_redo.append({ "label": str(_undo[-1].get("label", "")), "data": state.data.duplicate(true), "selected": str(state.selected_id)})
	var entry: Dictionary = _undo.pop_back()
	state.restore_snapshot(entry.get("data", {}), str(entry.get("selected", "")))
	_merge_label = ""
	return str(entry.get("label", ""))

func redo(state) -> String:
	if state == null or _redo.is_empty(): return ""
	_undo.append({ "label": str(_redo[-1].get("label", "")), "data": state.data.duplicate(true), "selected": str(state.selected_id)})
	var entry: Dictionary = _redo.pop_back()
	state.restore_snapshot(entry.get("data", {}), str(entry.get("selected", "")))
	_merge_label = ""
	return str(entry.get("label", ""))

func stack_labels() -> Array:
	var out: Array = []
	for row: Dictionary in _undo: out.append(str(row.get("label", "")))
	return out
