extends RefCounted





const WALK_SPEED := 7.0
const RUN_SPEED := 16.0
const JUMP_SPEED := 6.2
const GRAVITY := 22.0
const EYE_HEIGHT := 1.72
const COYOTE_TIME := 0.12



static func wish_direction(yaw: float, forward: float, strafe: float) -> Vector3:
	var input := Vector3(strafe, 0, forward)
	if input.length_squared() > 1.0: input = input.normalized()
	if input.length_squared() < 0.0001: return Vector3.ZERO

	var basis_forward := Vector3(- sin(yaw), 0, -cos(yaw))
	var basis_right := Vector3(cos(yaw), 0, -sin(yaw))
	return (basis_right * input.x + basis_forward * input.z).normalized()


static func target_velocity(yaw: float, forward: float, strafe: float, running: bool) -> Vector3:
	var speed := RUN_SPEED if running else WALK_SPEED
	return wish_direction(yaw, forward, strafe) * speed


static func air_control(on_ground: bool) -> float:
	return 1.0 if on_ground else 0.35


static func vertical_velocity(current: float, on_ground: bool, coyote: float, jump_pressed: bool, delta: float) -> Dictionary:
	var vy := current
	var jumped := false
	if jump_pressed and (on_ground or coyote > 0.0):
		vy = JUMP_SPEED; jumped = true
	else:
		vy -= GRAVITY * delta
	return { "velocity": maxf(vy, -70.0), "jumped": jumped}


static func clamp_pitch(pitch: float) -> float:
	return clampf(pitch, deg_to_rad(-88.0), deg_to_rad(88.0))


static func eye_offset() -> Vector3:
	return Vector3(0, EYE_HEIGHT, 0)
