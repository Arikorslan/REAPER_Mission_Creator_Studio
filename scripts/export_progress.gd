extends RefCounted
## Thread-safe progress mailbox. Worker threads never access a UI Control.
var _mutex := Mutex.new()
var _percent := 0.0
var _note := "Preparing export"

func report(percent: float, note: String) -> void:
	_mutex.lock()
	_percent = maxf(_percent, clampf(percent, 0.0, 100.0))
	if not note.is_empty(): _note = note
	_mutex.unlock()

func snapshot() -> Dictionary:
	_mutex.lock()
	var value := {"percent": _percent, "note": _note}
	_mutex.unlock()
	return value

func bake_tick(done: int, total: int) -> void:
	var ratio := clampf(float(done) / float(maxi(1, total)), 0.0, 1.0)
	report(3.0 + 19.0 * ratio, "Baking ground · %d%% of this stage" % int(ratio * 100.0))

func store_tick(stage: String, done: int, total: int) -> void:
	var ratio := clampf(float(done) / float(maxi(1, total)), 0.0, 1.0)
	match stage:
		"prepare": report(67.0, "Checking mission and assets")
		"hash": report(69.0 + 7.0 * ratio, "Hashing asset %d of %d" % [done, total])
		"write": report(76.0 + 14.0 * ratio, "Writing package · %.1f / %.1f MiB" % [float(done) / 1048576.0, float(total) / 1048576.0])
		"verify": report(91.0, "Re-reading and verifying the finished package")
		_: report(67.0, stage)

func write_tick(done: int, total: int) -> void:
	store_tick("write", done, total)
