--!strict
-- EnemyDefs.luau — enemy stat definitions (Job 006 POC).
--
-- Data-driven so the threat system extends cleanly (GAME.md "Threats"): every enemy carries a
-- `category` ("sea"/"land") and an optional `strengthAt(phase)` time-of-day multiplier hook, so land
-- threats and day/night scaling slot in later without reshaping this. The POC uses one sea croc.

export type EnemyDef = {
	name: string,
	category: string, -- "sea" | "land"
	hp: number,
	speed: number, -- studs/s move (swim) speed
	aggroRadius: number, -- start chasing within this distance of the boat
	biteRange: number, -- deal damage within this distance
	biteDamage: number, -- damage per bite to the boat
	biteCooldown: number, -- seconds between bites
	color: Color3,
	size: Vector3,
	-- time-of-day strength multiplier; POC returns 1. Later: sea → higher at night, land → higher by day.
	strengthAt: ((phase: string) -> number)?,
}

local EnemyDefs: { [string]: EnemyDef } = {
	Crocodile = {
		name = "Crocodile",
		category = "sea",
		hp = 40,
		speed = 20, -- slower than the boat's top speed (~30) so full throttle escapes, but catches a dawdler
		aggroRadius = 150,
		biteRange = 16,
		biteDamage = 8,
		biteCooldown = 1.5,
		color = Color3.fromRGB(58, 86, 54),
		size = Vector3.new(6, 3, 16),
	},
}

return EnemyDefs
