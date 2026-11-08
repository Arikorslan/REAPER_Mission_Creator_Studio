extends RefCounted





const Terrain = preload("res://scripts/terrain_model.gd")
const GRAVITY := 9.81
const BANK_LIMIT := deg_to_rad(25.0)
const PITCH_LIMIT := deg_to_rad(18.0)
const BANK_RATE := deg_to_rad(110.0)
const PITCH_RATE := deg_to_rad(80.0)
const TURN_GAIN := 4.0
const MIN_CLEARANCE := 15.0
var position := Vector3.ZERO
var heading := 0.0
var roll := 0.0



var pitch := 0.0
var speed := 45.0
var turn_rate := 0.0
var vertical_speed := 0.0
var skimming := false
var target_id := ""
var target_name := ""
var target_distance := 0.0
var target_elapsed := 0.0
var complete := false
var objects: Array = []
var terrain: Dictionary = {}

func start(data: Dictionary) -> void:
	terrain = data.get("terrain", Terrain.empty()); objects = data.get("objects", [])
	var start_row: Dictionary = {}
	for row: Dictionary in objects:
		if str(row.get("asset", "")) == "drone_start": start_row = row; break
	var x := float(start_row.get("x", -180)); var z := float(start_row.get("z", 300))
	var agl := clampf(float(start_row.get("height", 140)), 25.0, 500.0)
	position = Vector3(x, Terrain.height_at(terrain, objects, x, z) +agl, z)
	heading = deg_to_rad(float(start_row.get("yaw_deg", 0))); speed = 45.0
	roll = 0.0; pitch = 0.0; turn_rate = 0.0; vertical_speed = 0.0; skimming = false
	target_id = str(data.get("recon_target", "")); target_name = ""; target_elapsed = 0.0; complete = false
	for row: Dictionary in objects:
		if str(row.id) == target_id: target_name = str(row.name); break
	if target_name.is_empty(): target_id = ""

func _approach(current: float, target: float, rate: float, dt: float) -> float:
	var delta := target - current
	var step := rate * dt
	return target if absf(delta) <= step else current + signf(delta) * step

func step(delta: float, commands: Dictionary, preview_positions: Dictionary = {}) -> void:
	var dt := clampf(delta, 0.0, 0.1)
	var throttle := clampf(float(commands.get("throttle", 0)), -1, 1)
	var turn := clampf(float(commands.get("turn", 0)), -1, 1)
	var climb := clampf(float(commands.get("climb", 0)), -1, 1)
	speed = clampf(speed + throttle * 18.0 * dt, 18.0, 100.0)


	roll = _approach(roll, turn * BANK_LIMIT, BANK_RATE, dt)


	var reference_speed := maxf(speed, 18.0)


	turn_rate = -TURN_GAIN * GRAVITY * tan(roll) / reference_speed
	heading += turn_rate * dt


	pitch = _approach(pitch, climb * PITCH_LIMIT, PITCH_RATE, dt)
	vertical_speed = speed * sin(pitch)
	var forward := Vector3(- sin(heading), 0, -cos(heading))
	position += forward * speed * dt
	position.y += vertical_speed * dt
	var boundary := maxf(100.0, float(terrain.get("extent", Terrain.EXTENT)) -100.0)
	position.x = clampf(position.x, -boundary, boundary); position.z = clampf(position.z, -boundary, boundary)
	var floor_y := Terrain.height_at(terrain, objects, position.x, position.z)
	var lowest := floor_y + MIN_CLEARANCE
	skimming = position.y <= lowest
	position.y = clampf(position.y, lowest, floor_y + 500.0)
	if target_id.is_empty() or complete: return
	for row: Dictionary in objects:
		if str(row.id) != target_id: continue
		var p: Vector2 = preview_positions.get(target_id, Vector2(float(row.x), float(row.z)))
		target_distance = Vector2(position.x, position.z).distance_to(p)
		if target_distance <= 150.0: target_elapsed += dt
		else: target_elapsed = 0.0
		if target_elapsed >= 2.0: complete = true
		return



func attitude() -> Vector3:
	return Vector3(- pitch, heading, roll)

func bank_degrees() -> float: return rad_to_deg(roll)


func bank_side() -> String:
	if absf(roll) < deg_to_rad(2.0): return ""
	return " R" if roll > 0.0 else " L"
func pitch_degrees() -> float: return rad_to_deg(pitch)

func telemetry() -> String:
	var floor_y := Terrain.height_at(terrain, objects, position.x, position.z)
	var objective := "FREE FLIGHT / no recon target set"
	if not target_id.is_empty(): objective = ("RECON COMPLETE / " + target_name) if complete else ("RECON / %s / %d m / hold within 150 m for 2 s" % [target_name, int(target_distance)])
	var wave := "TERRAIN / pull up" if skimming else ("CLIMB" if pitch > deg_to_rad(3.0) else ("DIVE" if pitch < deg_to_rad(-3.0) else "LEVEL"))
	return "TEST FLIGHT  |  %d km/h  |  %d m AGL  |  bank %d°%s  |  %s  |  %s" % [int(speed * 3.6), int(position.y - floor_y), int(absf(bank_degrees())), bank_side(), wave, objective]
