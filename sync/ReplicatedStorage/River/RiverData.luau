--!strict
-- RiverData.luau — single source of truth for the river's SHAPE (Job 005).
--
-- Pure, deterministic math from a seed. No terrain writes, no side effects. BOTH the RiverGenerator
-- (which materializes voxels) and BoatServer (which drives on it) read from here, so they can never
-- desync. The river runs along +Z from Z_START; "distance" downstream = z - Z_START.
--
-- Continuity: centerline/width are continuous functions of z (layered Perlin via math.noise), so
-- chunk boundaries line up automatically — no seams to stitch.

local RiverData = {}

-- ── config (tunable) ───────────────────────────────────────────────────────
RiverData.WATER_Y = 12            -- target water surface height
RiverData.Z_START = 0             -- world Z of the river's upstream start
RiverData.END_DISTANCE = 18000    -- campaign finish distance (studs) ≈ a long ~15–25 min run
RiverData.ENDLESS = false         -- true = no end (P10 endless mode)

-- meander: centerlineX(z) = A1·noise(z·F1) + A2·noise(z·F2). Big slow bends + smaller wiggles.
-- (noise ≈ ±0.5, so ×2 to use its full range; amplitudes are ~studs of side-to-side.)
local A1, F1 = 300, 1 / 1600
local A2, F2 = 75, 1 / 620
-- width: WIDE by design (obstacles/ramps live IN the channel). Gentle variation, never tight — any
-- real pinch-points come later as placed obstacles, not a skinny river.
local W_BASE, W_VAR, F_W = 190, 45, 1 / 700
local W_FLOOR, W_CEIL = 140, 240
-- ───────────────────────────────────────────────────────────────────────────

local seed = 1
local offX1, offX2, offW = 1.7, 5.3, 9.1 -- noise offsets (avoid integer lattice zeros); re-derived per seed

function RiverData.setSeed(newSeed: number)
	seed = newSeed
	local r = Random.new(newSeed)
	offX1 = r:NextNumber(1, 5000)
	offX2 = r:NextNumber(1, 5000)
	offW = r:NextNumber(1, 5000)
end

function RiverData.getSeed(): number
	return seed
end

-- world-space X of the channel center at downstream position z
function RiverData.centerlineX(z: number): number
	return A1 * (math.noise(z * F1 + offX1) * 2) + A2 * (math.noise(z * F2 + offX2) * 2)
end

-- channel width (bank to bank) at z — wide, with gentle variation; clamped so it never gets tight
function RiverData.widthAt(z: number): number
	local n = math.noise(z * F_W + offW) * 2 -- ~[-1, 1]
	return math.clamp(W_BASE + W_VAR * n, W_FLOOR, W_CEIL)
end

-- world position of the channel center at z (at the water surface)
function RiverData.positionAt(z: number): Vector3
	return Vector3.new(RiverData.centerlineX(z), RiverData.WATER_Y, z)
end

-- unit downstream tangent at z (finite-difference of the centerline)
function RiverData.tangentAtZ(z: number): Vector3
	local dx = RiverData.centerlineX(z + 1) - RiverData.centerlineX(z - 1)
	return Vector3.new(dx * 0.5, 0, 1).Unit
end

function RiverData.worldToDistance(z: number): number
	return z - RiverData.Z_START
end

function RiverData.distanceToWorldZ(distance: number): number
	return RiverData.Z_START + distance
end

-- true once past the campaign finish (unless endless)
function RiverData.isPastEnd(z: number): boolean
	return not RiverData.ENDLESS and (z - RiverData.Z_START) >= RiverData.END_DISTANCE
end

RiverData.setSeed(seed)
return RiverData
