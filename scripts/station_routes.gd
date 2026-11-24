extends RefCounted

const STREET_Y := 556.0
const PLATFORM_Y := 712.0
const RIDE_SECONDS := 24.0
const TRAVEL_STATES := ["approach_metro", "metro_fold_umbrella", "enter_metro", "escalator_down", "approach_exit", "escalator_up", "exit_metro"]
const INSIDE_STATES := ["enter_metro", "exit_metro"]
const ESCALATOR_STATES := ["escalator_down", "escalator_up"]
# One entrance on this side of the road holds a pair of escalators: the front
# one runs down, the one just behind it (drawn a few pixels up and right) runs up.
const UP_OFFSET := Vector2(10.0, -4.0)
const TOP_X := 165.0
const BOTTOM_X := 435.0

static func access_x(_entering: bool, shift: float) -> float:
	return 85.0 + shift

static func escalator_position(progress: float, going_down: bool, shift: float) -> Vector2:
	var upper := Vector2(TOP_X + shift, STREET_Y)
	var lower := Vector2(BOTTOM_X + shift, PLATFORM_Y)
	if going_down:
		return upper.lerp(lower, clampf(progress, 0, 1))
	return lower.lerp(upper, clampf(progress, 0, 1)) + UP_OFFSET
