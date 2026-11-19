extends RefCounted

# Door centers of the six-car preview sprite, from rear to front.
const TRAIN_DOOR_FRACTIONS := [0.086, 0.170, 0.247, 0.319, 0.396, 0.466, 0.542, 0.615, 0.691, 0.764, 0.840, 0.913]
const PASSENGER_TRANSITION_SECONDS := 2.0

# A crossing must finish while the doors are fully open, before closing starts.
# These intervals govern boarding AND alighting on both sidewalks and the metro.
static func passenger_crossing_allowed(seconds: float, vehicle: String) -> bool:
	if vehicle == "metro":
		var phase := fposmod(seconds, 100.0)
		return phase >= 22.0 and phase < 38.0 - PASSENGER_TRANSITION_SECONDS
	if vehicle in ["near_bus", "far_bus"]:
		var phase := fposmod(seconds + (32.0 if vehicle == "near_bus" else 8.0), 70.0)
		return phase >= 26.5 and phase < 31.0 - PASSENGER_TRANSITION_SECONDS
	return false

# Door intervals share the same simulated stop cycle as the on-screen vehicles.
# The train runs on straight rails; easing models braking and acceleration rather
# than importing a full track physics system for this fixed wallpaper scene.
static func train_position(seconds: float, scene_width: float) -> float:
	var cycle := fposmod(seconds, 100.0)
	if cycle < 19.0:
		var progress := cycle / 19.0
		return lerpf(-680.0, 750.0, 1.0 - pow(1.0 - progress, 2.0))
	if cycle < 42.0: return 750.0
	if cycle < 61.0:
		var progress := (cycle - 42.0) / 19.0
		return lerpf(750.0, scene_width, progress * progress)
	return -680.0

static func train_doors(seconds: float) -> float:
	var cycle := fposmod(seconds, 100.0)
	if cycle < 20.0 or cycle >= 40.0: return 0.0
	if cycle < 22.0: return smoothstep(20.0, 22.0, cycle)
	if cycle < 38.0: return 1.0
	return 1.0 - smoothstep(38.0, 40.0, cycle)

# Screen doors correspond to the twelve doors of the train when stopped.
static func platform_door_centers() -> Array[float]:
	var result: Array[float] = []
	for fraction in TRAIN_DOOR_FRACTIONS: result.append(750.0 + fraction * 660.0)
	return result

static func platform_door_opening(seconds: float, center: float) -> float:
	for door in platform_door_centers():
		if absf(door - center) < 0.01: return train_doors(seconds)
	return 0.0

static func bus_doors(seconds: float) -> float:
	var cycle := fposmod(seconds, 70.0)
	if cycle < 25.5 or cycle >= 32.0: return 0.0
	if cycle < 26.5: return smoothstep(25.5, 26.5, cycle)
	if cycle < 31.0: return 1.0
	return 1.0 - smoothstep(31.0, 32.0, cycle)

# Countdown follows the exact same 70-second simulated bus cycle as _bus_x.
static func bus_arrival_seconds(seconds: float) -> int:
	var cycle := fposmod(seconds, 70.0)
	if cycle >= 25.0 and cycle < 33.0: return 0
	return ceili(fposmod(25.0 - cycle, 70.0))
