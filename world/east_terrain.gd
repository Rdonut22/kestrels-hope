extends RefCounted

## Height of the ground east of the crash site (metres above the crash
## site's flat ground), shared by tools/build_scenes.gd, which builds the
## terrain mesh, its collision and the trees on it, and world/grass_field.gd,
## which grows grass on it. Flat up to the Great Ring's clearing, then gently
## rolling forest floor that rises towards the valley between the eastern
## mountains (around x = 930), its sides climbing into the foothills.

const RING := Vector2(132.0, -16.0)
const VALLEY_X := 930.0
const VALLEY_Z := -16.0

static var _hills: FastNoiseLite
static var _bumps: FastNoiseLite


static func height(x: float, z: float) -> float:
	if x < 100.0:
		return 0.0
	if _hills == null:
		_hills = FastNoiseLite.new()
		_hills.seed = 77
		_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_hills.frequency = 0.006
		_hills.fractal_octaves = 3
		_bumps = FastNoiseLite.new()
		_bumps.seed = 91
		_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_bumps.frequency = 0.03
	# Stay flat at the play area's old edge and round the ring.
	var blend := smoothstep(100.0, 175.0, x) * smoothstep(50.0, 85.0, Vector2(x, z).distance_to(RING))
	var rise := pow(smoothstep(230.0, VALLEY_X, x), 1.6) * 48.0 + maxf(x - VALLEY_X, 0.0) * 0.18
	var hills := (_hills.get_noise_2d(x, z) * 0.5 + 0.5) * (5.0 + 12.0 * smoothstep(450.0, VALLEY_X, x))
	var bumps := (_bumps.get_noise_2d(x, z) * 0.5 + 0.5) * 1.2
	# Towards the valley the ground climbs on either side of it.
	var funnel := pow(smoothstep(600.0, VALLEY_X + 120.0, x), 2.0) * smoothstep(55.0, 230.0, absf(z - VALLEY_Z)) * 45.0
	return blend * (rise + hills + bumps + funnel)
