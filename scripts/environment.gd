extends RefCounted

# Live environment for the preview: real sun and moon for Shenzhen, sky colours,
# ambient light on the city, and how many windows are lit at a given hour.
# Everything is a pure function of the local clock and the weather, so it can
# be tested without rendering.

const LATITUDE := 22.5431
const LONGITUDE := 114.0579
const UTC_OFFSET := 8.0
const HORIZON_Y := 362.0          # scene y of the far shore / horizon
const PX_PER_DEGREE := 5.5        # scene pixels per degree of elevation

static func day_of_year(date: Dictionary) -> int:
	var days := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var n: int = days[int(date.month) - 1] + int(date.day)
	var y := int(date.year)
	if int(date.month) > 2 and (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)): n += 1
	return n

static func hours(now: Dictionary) -> float:
	return float(now.hour) + float(now.minute) / 60.0 + float(now.get("second", 0)) / 3600.0

# Solar elevation/azimuth in degrees (NOAA approximation, accurate to ~0.5°).
static func sun(now: Dictionary) -> Dictionary:
	var n := day_of_year(now)
	var gamma := TAU / 365.0 * (n - 1 + (hours(now) - 12.0) / 24.0)
	var eq_time := 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
	var decl := 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
	var true_solar := hours(now) * 60.0 + eq_time + 4.0 * LONGITUDE - 60.0 * UTC_OFFSET
	var hour_angle := deg_to_rad(true_solar / 4.0 - 180.0)
	return _horizontal(decl, hour_angle)

static func _horizontal(decl: float, hour_angle: float) -> Dictionary:
	var lat := deg_to_rad(LATITUDE)
	var cos_zenith := sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hour_angle)
	var zenith := acos(clampf(cos_zenith, -1.0, 1.0))
	var elevation := 90.0 - rad_to_deg(zenith)
	var azimuth := rad_to_deg(atan2(sin(hour_angle), cos(hour_angle) * sin(lat) - tan(decl) * cos(lat))) + 180.0
	return {"elevation": elevation, "azimuth": fposmod(azimuth, 360.0)}

# Moon: phase from the synodic month, position approximated from the sun's hour
# angle shifted by the phase (good enough to rise ~50 minutes later each day).
static func moon(now: Dictionary) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_dict(now) - UTC_OFFSET * 3600.0
	var days := (unix - 947182440.0) / 86400.0       # 2000-01-06 18:14 UTC new moon
	var phase := fposmod(days / 29.530588, 1.0)
	var decl := 0.4 * sin(TAU * fposmod(days / 27.32, 1.0))
	var sun_hour_angle := deg_to_rad((hours(now) - 12.0) * 15.0)
	var pos := _horizontal(decl, sun_hour_angle - phase * TAU)
	pos.phase = phase
	pos.illumination = 0.5 - 0.5 * cos(phase * TAU)
	return pos

static func sky_position(body: Dictionary) -> Vector2:
	# The viewer looks south across the bay: east on the left, west on the right.
	var x := 1086.0 + (float(body.azimuth) - 180.0) / 90.0 * 1180.0
	return Vector2(x, HORIZON_Y - float(body.elevation) * PX_PER_DEGREE)

# Where the moon is drawn at night. A 16:10 screen only shows scene x ~542–1630
# and crops the top, so the true azimuth often puts the moon off screen, and
# near new moon it is invisible. The moon is the point of a clear night here:
# its path is compressed into the visible sky, it waits high in the south-west
# while it is really below the horizon, and it always shows at least a crescent.
const MOON_PARK := Vector2(1390.0, 118.0)

static func display_moon(body: Dictionary) -> Dictionary:
	var az := clampf((float(body.azimuth) - 90.0) / 180.0, 0.0, 1.0)
	var el := clampf(float(body.elevation), 0.0, 75.0) / 75.0
	var arc := Vector2(720.0 + az * 760.0, HORIZON_Y - 70.0 - el * 190.0)
	var up := smoothstep(2.0, 12.0, float(body.elevation))
	var phase := float(body.phase)
	# Keep at least a thin crescent (illumination ~10 %).
	if phase < 0.1: phase = 0.1
	elif phase > 0.9: phase = 0.9
	return {"pos": MOON_PARK.lerp(arc, up), "phase": phase}

# Sky colour keyframes by solar elevation: [elevation, zenith, horizon].
const SKY_KEYS := [
	# Navy above and a warm sodium glow low down: a city night is never black,
	# and no keyframe drifts into violet (the old painted sky was purple).
	[-18.0, Color(0.030, 0.055, 0.105), Color(0.120, 0.120, 0.110)],
	[-10.0, Color(0.040, 0.070, 0.135), Color(0.150, 0.140, 0.120)],
	[-4.0, Color(0.070, 0.120, 0.230), Color(0.520, 0.330, 0.200)],
	[0.0, Color(0.170, 0.300, 0.520), Color(0.980, 0.580, 0.300)],
	[6.0, Color(0.260, 0.470, 0.760), Color(1.000, 0.790, 0.540)],
	[15.0, Color(0.250, 0.530, 0.880), Color(0.720, 0.860, 0.950)],
	[60.0, Color(0.200, 0.480, 0.900), Color(0.640, 0.810, 0.960)],
]

static func _key(elevation: float, index: int) -> Color:
	if elevation <= SKY_KEYS[0][0]: return SKY_KEYS[0][index]
	for i in range(SKY_KEYS.size() - 1):
		var a: Array = SKY_KEYS[i]
		var b: Array = SKY_KEYS[i + 1]
		if elevation <= b[0]:
			return (a[index] as Color).lerp(b[index], smoothstep(a[0], b[0], elevation))
	return SKY_KEYS[-1][index]

# Clouds and rain flatten the sky towards grey; at night clouds reflect the
# city's orange light pollution.
static func sky_colors(elevation: float, cloud: float, rain: float) -> Dictionary:
	var zenith := _key(elevation, 1)
	var horizon := _key(elevation, 2)
	var daylight := smoothstep(-10.0, 12.0, elevation)
	var grey := Color(0.60, 0.63, 0.68).lerp(Color(0.42, 0.44, 0.48), rain) * daylight + Color(0.09, 0.07, 0.07) * (1.0 - daylight)
	var overcast := clampf(cloud * 0.75 + rain * 0.25, 0.0, 1.0)
	return {"zenith": zenith.lerp(grey * 0.9, overcast), "horizon": horizon.lerp(grey, overcast)}

static func daylight(elevation: float) -> float:
	return smoothstep(-6.0, 8.0, elevation)

# Multiplier for everything on the ground (buildings, streets, vehicles, people).
const AMBIENT_KEYS := [
	# Moonlit blue at night, amber at dusk; never lavender.
	[-14.0, Color(0.26, 0.33, 0.48)],
	[-7.0, Color(0.38, 0.45, 0.60)],
	[-2.0, Color(0.86, 0.72, 0.60)],
	[2.0, Color(1.00, 0.90, 0.80)],
	[10.0, Color(0.98, 0.96, 0.93)],
	[30.0, Color(0.95, 0.97, 1.00)],
]

static func ambient(elevation: float, cloud: float, rain: float) -> Color:
	var c: Color = AMBIENT_KEYS[0][1]
	if elevation >= AMBIENT_KEYS[-1][0]:
		c = AMBIENT_KEYS[-1][1]
	else:
		for i in range(AMBIENT_KEYS.size() - 1):
			var a: Array = AMBIENT_KEYS[i]
			var b: Array = AMBIENT_KEYS[i + 1]
			if elevation >= a[0] and elevation < b[0]:
				c = (a[1] as Color).lerp(b[1], smoothstep(a[0], b[0], elevation))
				break
	var dim := lerpf(1.0, 0.78, clampf(cloud * 0.6 + rain * 0.6, 0.0, 1.0))
	return Color(c.r * dim, c.g * dim, c.b * lerpf(dim, 1.0, 0.3))

# Share of windows lit: dark by day, busiest early evening, nearly all off in
# the small hours. Weekends stay up later.
static func window_occupancy(now: Dictionary) -> float:
	var h := hours(now)
	var weekend := int(now.get("weekday", 1)) in [0, 6]
	var keys := [[0.0, 0.32], [1.0, 0.16], [2.0, 0.07], [4.5, 0.04], [6.0, 0.12], [7.0, 0.30], [8.5, 0.18],
		[17.0, 0.30], [18.5, 0.75], [20.5, 0.85], [22.0, 0.72], [23.0, 0.55], [24.0, 0.32]]
	for i in range(keys.size() - 1):
		if h >= keys[i][0] and h < keys[i + 1][0]:
			var v: float = lerpf(keys[i][1], keys[i + 1][1], smoothstep(keys[i][0], keys[i + 1][0], h))
			if weekend and (h >= 23.0 or h < 2.0): v = minf(1.0, v * 1.4)
			return v
	return 0.3

# Share of office floors still lit: full during the working day, a long tail
# of overtime (加班) into the night, a few security / server rooms until dawn.
static func office_occupancy(now: Dictionary) -> float:
	var h := hours(now)
	var weekend := int(now.get("weekday", 1)) in [0, 6]
	var keys := [[0.0, 0.14], [2.0, 0.07], [5.5, 0.05], [7.5, 0.35], [9.0, 0.85], [18.0, 0.85], [19.5, 0.62],
		[21.0, 0.45], [22.5, 0.3], [24.0, 0.14]]
	for i in range(keys.size() - 1):
		if h >= keys[i][0] and h < keys[i + 1][0]:
			var v: float = lerpf(keys[i][1], keys[i + 1][1], smoothstep(keys[i][0], keys[i + 1][0], h))
			return v * (0.45 if weekend else 1.0)
	return 0.14

# Shenzhen's skyline light shows run roughly 19:30–22:00.
static func light_show(now: Dictionary) -> float:
	var h := hours(now)
	return smoothstep(19.5, 19.6, h) * (1.0 - smoothstep(22.0, 22.1, h))

# Street lamps follow the real dusk/dawn rather than a fixed clock.
static func street_lights(elevation: float) -> float:
	return 1.0 - smoothstep(-3.0, 2.0, elevation)
