extends RefCounted

const STREET_Y := 556.0
const PLATFORM_Y := 712.0
const RIDE_SECONDS := 24.0
const TRAVEL_STATES := ["approach_metro", "metro_fold_umbrella", "enter_metro", "escalator_down", "approach_exit", "escalator_up", "exit_metro"]
const INSIDE_STATES := ["enter_metro", "exit_metro"]
const ESCALATOR_STATES := ["escalator_down", "escalator_up"]

static func access_x(entering: bool, shift: float) -> float:
	return 85.0 + shift if entering else 2087.0 - shift

static func escalator_position(progress: float, going_down: bool, shift: float) -> Vector2:
	var upper := Vector2(165.0 + shift, STREET_Y) if going_down else Vector2(2007.0 - shift, STREET_Y)
	var lower := Vector2(435.0 + shift, PLATFORM_Y) if going_down else Vector2(1737.0 - shift, PLATFORM_Y)
	return upper.lerp(lower, clampf(progress, 0, 1)) if going_down else lower.lerp(upper, clampf(progress, 0, 1))
