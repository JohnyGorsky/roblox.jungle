--!strict
-- ExcursionServer.server.luau — dock → jungle camp raid loop, first slice (Job 011).
--
-- At each dock, inland, we carve a flat walkable CLEARING and build a greybox CAMP: huts, a guarded
-- loot crate. Loot the crate → carry it (hands full, can't shoot) → deposit at the boat → a resource
-- count goes up. Server-authoritative. Guards target on-foot players (leashed to the camp).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local EnemyDefs = require(ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("EnemyDefs"))

local CAMP_AHEAD = 1400
local CAMP_INLAND = 55 -- studs past the bank edge to the camp centre
local CLEARING_SIZE = 110
local GUARD_LEASH = 55

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local Terrain = Workspace.Terrain
local CLEAR_Y = RiverData.WATER_Y + 3 -- walkable clearing ground height

local campsRoot = Instance.new("Folder")
campsRoot.Name = "Camps"
campsRoot.Parent = Workspace

local built: { [number]: boolean } = {}
local carrying: { [Player]: BasePart } = {}
type GuardState = { biteTimer: number, anchor: Vector3 }
local guardState: { [Model]: GuardState } = {}

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, parent: Instance, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- flatten a walkable grass clearing (fill solid below CLEAR_Y, clear hills above)
local function carveClearing(cx: number, cz: number)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y - 20, cz), Vector3.new(CLEARING_SIZE, 40, CLEARING_SIZE), Enum.Material.Grass)
	Terrain:FillBlock(CFrame.new(cx, CLEAR_Y + 22, cz), Vector3.new(CLEARING_SIZE, 44, CLEARING_SIZE), Enum.Material.Air)
end

-- deposit carried loot at the boat → a resource count. ONLY shown while someone is actually carrying.
local deposit = Instance.new("ProximityPrompt")
deposit.Name = "DepositPrompt"
deposit.ActionText = "Deposit"
deposit.ObjectText = "Cargo"
deposit.HoldDuration = 0.5
deposit.RequiresLineOfSight = false
deposit.MaxActivationDistance = 16
deposit.Enabled = false -- hidden until you pick up loot
deposit.Parent = hull
deposit.Triggered:Connect(function(player: Player)
	local carried = carrying[player]
	if not carried then
		return
	end
	local resource = (carried:GetAttribute("Resource") :: string?) or "Metal"
	boat:SetAttribute(resource, ((boat:GetAttribute(resource) :: number?) or 0) + 1)
	carried:Destroy()
	carrying[player] = nil
	player:SetAttribute("Busy", false)
	local char = player.Character
	if char then
		char:SetAttribute("Carrying", nil)
	end
	deposit.Enabled = next(carrying) ~= nil -- hide again once nobody's carrying
end)

local function pickupLoot(player: Player, crate: Part)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not root or carrying[player] then
		return
	end
	local resource = (crate:GetAttribute("Resource") :: string?) or "Metal"
	local carried = Instance.new("Part")
	carried.Name = "CarriedCrate"
	carried.Size = Vector3.new(3, 3, 3)
	carried.Color = Color3.fromRGB(150, 120, 70)
	carried.Material = Enum.Material.WoodPlanks
	carried.CanCollide = false
	carried.Massless = true
	carried.CFrame = root.CFrame * CFrame.new(0, 2.5, 0)
	carried:SetAttribute("Resource", resource)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = carried
	weld.Parent = carried
	carried.Parent = char
	carrying[player] = carried
	char:SetAttribute("Carrying", resource)
	player:SetAttribute("Busy", true) -- hands full → can't shoot (weapon already respects Busy)
	deposit.Enabled = true -- now show the boat's Deposit prompt
	crate:Destroy()
end

local function spawnGuard(campPos: Vector3, parent: Instance): Model
	local def = EnemyDefs.Defs.Panther
	local guard = Instance.new("Model")
	guard.Name = "CampGuard"
	local anchorPos = campPos + Vector3.new(0, 0, 8)
	local body = block("Body", def.size, def.color, CFrame.new(anchorPos + Vector3.new(0, def.size.Y / 2, 0)), guard)
	guard.PrimaryPart = body
	guard:SetAttribute("HP", def.hp)
	guard:SetAttribute("MaxHP", def.hp)
	CollectionService:AddTag(guard, "CampGuard") -- ExcursionServer ticks it; WeaponServer can shoot it
	guard.Parent = parent
	guardState[guard] = { biteTimer = def.biteCooldown, anchor = Vector3.new(anchorPos.X, CLEAR_Y + def.size.Y / 2, anchorPos.Z) }
	return guard
end

local function buildCamp(dock: RiverData.Dock, index: number)
	if built[index] then
		return
	end
	built[index] = true
	local campX = RiverData.centerlineX(dock.z) + dock.side * (RiverData.widthAt(dock.z) * 0.5 + CAMP_INLAND)
	local campPos = Vector3.new(campX, CLEAR_Y, dock.z)
	carveClearing(campX, dock.z)

	local model = Instance.new("Model")
	model.Name = "Camp"
	block("Hut", Vector3.new(10, 8, 10), Color3.fromRGB(92, 70, 45), CFrame.new(campPos + Vector3.new(-12, 4, 10)), model)
	block("Hut", Vector3.new(8, 6, 8), Color3.fromRGB(104, 82, 55), CFrame.new(campPos + Vector3.new(13, 3, 4)), model)

	local crate = block("LootCrate", Vector3.new(4, 4, 4), Color3.fromRGB(150, 120, 70), CFrame.new(campPos + Vector3.new(0, 2, -8)), model, Enum.Material.WoodPlanks)
	crate:SetAttribute("Resource", "Metal")
	local loot = Instance.new("ProximityPrompt")
	loot.Name = "LootPrompt"
	loot.ActionText = "Loot"
	loot.ObjectText = "Crate"
	loot.HoldDuration = 1.2
	loot.RequiresLineOfSight = false
	loot.MaxActivationDistance = 10
	loot.Parent = crate
	loot.Triggered:Connect(function(player: Player)
		pickupLoot(player, crate)
	end)

	spawnGuard(campPos, model)
	model.Parent = campsRoot
end

-- guard AI: chase the nearest on-foot player, leashed to the camp; bite = damage player HP
local function tickGuard(guard: Model, dt: number)
	local def = EnemyDefs.Defs.Panther
	local body = guard.PrimaryPart
	local st = guardState[guard]
	if not body or not st then
		guard:Destroy()
		return
	end
	if ((guard:GetAttribute("HP") :: number?) or 0) <= 0 then
		guardState[guard] = nil
		guard:Destroy()
		return
	end
	st.biteTimer += dt
	local pos = body.Position

	local target: BasePart? = nil
	local bestD = def.aggroRadius
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and char and not char:GetAttribute("Downed") then
			local d = (root.Position - pos).Magnitude
			if d <= bestD then
				target, bestD = root, d
			end
		end
	end

	local goal = if target then target.Position else st.anchor
	local dir = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z)
	local dist = dir.Magnitude
	if dist > 0.5 then
		dir = dir.Unit
		local stop = if target then def.biteRange * 0.5 else 1
		local step = math.min(def.speed * dt, math.max(dist - stop, 0))
		local np = Vector3.new(pos.X + dir.X * step, CLEAR_Y + def.size.Y / 2, pos.Z + dir.Z * step)
		local off = Vector3.new(np.X - st.anchor.X, 0, np.Z - st.anchor.Z)
		if off.Magnitude > GUARD_LEASH then
			local c = st.anchor + off.Unit * GUARD_LEASH
			np = Vector3.new(c.X, CLEAR_Y + def.size.Y / 2, c.Z)
		end
		guard:PivotTo(CFrame.lookAt(np, np + dir))
	end

	if target and bestD <= def.biteRange and st.biteTimer >= def.biteCooldown then
		st.biteTimer = 0
		local char = target.Parent
		if char then
			char:SetAttribute("HP", math.max(0, ((char:GetAttribute("HP") :: number?) or 0) - def.biteDamage))
		end
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	for _, guard in CollectionService:GetTagged("CampGuard") do
		if guard:IsA("Model") and guard.Parent then
			tickGuard(guard, dt)
		end
	end
end)

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - 200, boatZ + CAMP_AHEAD) do
		buildCamp(dock, dockIndex(dock.z))
	end
	task.wait(0.5)
end
