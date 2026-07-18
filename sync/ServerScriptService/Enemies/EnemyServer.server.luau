--!strict
-- EnemyServer.server.luau — croc spawn director + multi-croc AI (Jobs 006 → 007).
--
-- Spawns crocs near/ahead of the boat as it travels (capped, rate escalates with distance), each
-- running the same Humanoid-less chase→bite AI. A single global Heartbeat ticks ALL Enemy-tagged
-- crocs (roblox-ai multi-agent pattern); crocs left far behind are culled. Server-authoritative.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))

-- ── config ─────────────────────────────────────────────────────────────────
local MAX_ACTIVE = 4 -- most crocs alive at once
local SPAWN_AHEAD_MIN, SPAWN_AHEAD_MAX = 70, 140 -- studs ahead of the boat to spawn
local CULL_BEHIND = 260 -- despawn a croc once the boat is this far past it
local LEAD_TIME = 0.8 -- boat-velocity lead for interception
local SPAWN_INTERVAL_NEAR, SPAWN_INTERVAL_FAR = 5.0, 2.0 -- seconds between spawns, early → late run
local ESCALATE_DISTANCE = 12000 -- distance over which spawn rate ramps to its fastest
-- ───────────────────────────────────────────────────────────────────────────

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y
local rng = Random.new()

type CrocState = { biteTimer: number }
local state: { [Model]: CrocState } = {}

local function spawnCroc(def: EnemyDefs.EnemyDef, pos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = def.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = def.size
	body.Color = def.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true -- kinematic: the server drives it via PivotTo
	body.CanCollide = false
	body.CFrame = CFrame.new(pos)
	body.Parent = model
	model.PrimaryPart = body

	local snout = Instance.new("Part")
	snout.Name = "Snout"
	snout.Size = Vector3.new(def.size.X * 0.6, def.size.Y * 0.7, def.size.Z * 0.35)
	snout.Color = def.color
	snout.Material = Enum.Material.SmoothPlastic
	snout.Anchored = true
	snout.CanCollide = false
	snout.CFrame = body.CFrame * CFrame.new(0, 0, -def.size.Z * 0.6)
	snout.Parent = model

	model:SetAttribute("HP", def.hp)
	model:SetAttribute("MaxHP", def.hp)
	model:SetAttribute("Category", def.category)
	CollectionService:AddTag(model, "Enemy") -- weapon fire + the global AI tick find crocs by this tag
	model.Parent = Workspace
	state[model] = { biteTimer = def.biteCooldown }
	return model
end

local function despawn(croc: Model)
	state[croc] = nil
	croc:Destroy()
end

-- greybox hit feedback: flash the hull red
local flashing = false
local function flashHull()
	if flashing then
		return
	end
	flashing = true
	local orig = hull.Color
	hull.Color = Color3.fromRGB(210, 45, 45)
	task.delay(0.12, function()
		hull.Color = orig
		flashing = false
	end)
end

local function damageBoat(amount: number)
	local hp = (boat:GetAttribute("HP") :: number?) or 0
	boat:SetAttribute("HP", math.max(0, hp - amount))
	flashHull()
end

local function boatAlive(): boolean
	return hull.Parent ~= nil and ((boat:GetAttribute("HP") :: number?) or 1) > 0
end

-- nearest alive, not-already-downed player character within range of a point (a croc's juicy target)
local function nearestPlayer(pos: Vector3, range: number): Model?
	local best: Model? = nil
	local bestD = range
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") then
			local d = (root.Position - pos).Magnitude
			if d <= bestD then
				best, bestD = char, d
			end
		end
	end
	return best
end

-- one croc's step: cull / death / chase / bite
local function tickCroc(croc: Model, def: EnemyDefs.EnemyDef, dt: number)
	local body = croc.PrimaryPart
	if not body then
		despawn(croc)
		return
	end
	if ((croc:GetAttribute("HP") :: number?) or 0) <= 0 then
		despawn(croc)
		return
	end

	local crocPos = body.Position
	local boatPos = hull.Position
	-- cull crocs the boat has left well behind (they lost the chase)
	if boatPos.Z - crocPos.Z > CULL_BEHIND then
		despawn(croc)
		return
	end

	local st = state[croc]
	if not st then
		return
	end
	st.biteTimer += dt

	local dist = (Vector3.new(boatPos.X, 0, boatPos.Z) - Vector3.new(crocPos.X, 0, crocPos.Z)).Magnitude
	if dist <= def.aggroRadius then
		local lead = boatPos + hull.AssemblyLinearVelocity * LEAD_TIME
		local dir = Vector3.new(lead.X - crocPos.X, 0, lead.Z - crocPos.Z)
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			local step = math.min(def.speed * dt, math.max(dist - def.biteRange * 0.5, 0))
			local newPos = Vector3.new(crocPos.X + dir.X * step, WATER_Y, crocPos.Z + dir.Z * step)
			croc:PivotTo(CFrame.lookAt(newPos, newPos + dir))
		end
		if dist <= def.biteRange and st.biteTimer >= def.biteCooldown then
			st.biteTimer = 0
			-- go for an exposed player if one's in reach, otherwise chomp the boat
			local victim = nearestPlayer(crocPos, def.biteRange)
			if victim then
				local hp = (victim:GetAttribute("HP") :: number?) or 0
				victim:SetAttribute("HP", math.max(0, hp - def.biteDamage))
				flashHull() -- brief shared feedback
			else
				damageBoat(def.biteDamage)
			end
		end
	end
end

local def = EnemyDefs.Crocodile

-- global AI tick over every live croc
RunService.Heartbeat:Connect(function(dt: number)
	for _, croc in CollectionService:GetTagged("Enemy") do
		if croc:IsA("Model") and croc.Parent == Workspace then
			tickCroc(croc, def, dt)
		end
	end
end)

-- spawn director: keep up to MAX_ACTIVE crocs coming, faster the further you've travelled
task.spawn(function()
	while true do
		if boatAlive() and #CollectionService:GetTagged("Enemy") < MAX_ACTIVE then
			local z = hull.Position.Z + rng:NextNumber(SPAWN_AHEAD_MIN, SPAWN_AHEAD_MAX)
			local x = RiverData.centerlineX(z) + rng:NextNumber(-1, 1) * RiverData.widthAt(z) * 0.35
			spawnCroc(def, Vector3.new(x, WATER_Y, z))
		end
		local dist = math.max(0, RiverData.worldToDistance(hull.Position.Z))
		local t = math.clamp(dist / ESCALATE_DISTANCE, 0, 1)
		task.wait(SPAWN_INTERVAL_NEAR + (SPAWN_INTERVAL_FAR - SPAWN_INTERVAL_NEAR) * t)
	end
end)

print(("[Enemy] spawn director online (max %d crocs)"):format(MAX_ACTIVE))
