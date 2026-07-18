--!strict
-- EnemyServer.server.luau — greybox POC: one sea croc that chases + bites the boat (Job 006).
--
-- Humanoid-less NPC (roblox-ai swarm path): open water has no obstacles between croc and boat, so we
-- skip pathfinding and STEER directly toward the boat's LED (velocity-predicted) position, moving the
-- croc kinematically via PivotTo, clamped to the water surface. Server-authoritative.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))

local LEAD_TIME = 0.8 -- seconds of boat-velocity lead, so the croc intercepts rather than trails

-- wait for the river + boat to exist
if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y

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

	-- a snout so its facing reads at a glance (greybox)
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
	CollectionService:AddTag(model, "Enemy") -- weapon fire targets tagged enemies
	model.Parent = Workspace
	return model
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

-- spawn one croc near the boat, on the water, within aggro range
local def = EnemyDefs.Crocodile
local croc = spawnCroc(def, Vector3.new(hull.Position.X + 40, WATER_Y, hull.Position.Z + 70))
local body = croc.PrimaryPart :: BasePart
local biteTimer = def.biteCooldown -- ready to bite on first contact

RunService.Heartbeat:Connect(function(dt: number)
	biteTimer += dt
	if not croc.Parent then
		return
	end
	-- death (once shooting lands): HP <= 0 → despawn
	if ((croc:GetAttribute("HP") :: number?) or 0) <= 0 then
		croc:Destroy()
		return
	end
	if not hull.Parent or (boat:GetAttribute("HP") :: number? or 1) <= 0 then
		return -- boat gone/destroyed → stop attacking
	end

	local crocPos = body.Position
	local boatPos = hull.Position
	local dist = (Vector3.new(boatPos.X, 0, boatPos.Z) - Vector3.new(crocPos.X, 0, crocPos.Z)).Magnitude

	if dist <= def.aggroRadius then
		-- chase: steer toward the boat's led position, on the water surface
		local lead = boatPos + hull.AssemblyLinearVelocity * LEAD_TIME
		local dir = Vector3.new(lead.X - crocPos.X, 0, lead.Z - crocPos.Z)
		if dir.Magnitude > 0.01 then
			dir = dir.Unit
			local step = math.min(def.speed * dt, math.max(dist - def.biteRange * 0.5, 0))
			local newPos = Vector3.new(crocPos.X + dir.X * step, WATER_Y, crocPos.Z + dir.Z * step)
			croc:PivotTo(CFrame.lookAt(newPos, newPos + dir))
		end
		-- bite
		if dist <= def.biteRange and biteTimer >= def.biteCooldown then
			biteTimer = 0
			damageBoat(def.biteDamage)
		end
	end
end)

print(("[Enemy] spawned %s (hp=%d) near the boat"):format(def.name, def.hp))
