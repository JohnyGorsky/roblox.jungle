--!strict
-- StagingServer.server.luau — crash-site hub + moored-boat rope START gate (Job 016).
--
-- Inserts a STAGING phase in front of the river run (same place, phased). Players spawn at a greybox
-- crash-site hub (see PlayerCombat), the boat sits MOORED (anchored + tied) with a visible rope, and all
-- threats/progression are gated behind Workspace.RunStarted. Anyone can UNTIE the rope to start: the boat
-- is released and the run begins. Boat driving is unchanged after start.
--
-- Hand-built vs procedural (GROUND-RULES §2): the greybox hub here is a PLACEHOLDER — the human will
-- hand-build the real crash-site hub + startup river; a later job points the procedural generator at
-- HANDOFF_Z. Nothing here is hero art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local WATER_Y = RiverData.WATER_Y
local HUB_Z = RiverData.Z_START + 40 -- level with the boat spawn (BoatServer: positionAt(Z_START+40))
local HUB_SIDE = 1 -- which bank the hub sits on (+X)

-- Where the hand-built startup section ends and the procedural river takes over. DOCUMENTED ONLY for now
-- (the generator still builds from Z_START this POC); a follow-up job will start procedural gen here.
local HANDOFF_Z = RiverData.Z_START + 300 -- luau: keep referenced so the intent is greppable
assert(HANDOFF_Z > RiverData.Z_START)

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart

-- run state: not started until someone unties
Workspace:SetAttribute("RunStarted", false)

-- moor the boat (anchored → the constant current can't drift it; claimServerOwnership early-returns on a
-- grounded assembly so this doesn't fight network ownership — same pattern as DockServer's tie)
hull.Anchored = true
boat:SetAttribute("Tied", true)

local area = Instance.new("Folder")
area.Name = "StagingArea"
area.Parent = Workspace

local function block(name: string, size: Vector3, color: Color3, cf: CFrame, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.Parent = area
	return p
end

-- ---- PLACEHOLDER greybox hub (replace with the hand-built crash-site hub) ----
local centerX = RiverData.centerlineX(HUB_Z)
local waterEdgeX = centerX + HUB_SIDE * (RiverData.widthAt(HUB_Z) * 0.5)
local PLATFORM_SX = 36
local DOCK_MARGIN = 6 -- studs of clear water kept between the boat's bank-side edge and the shore (never beaches)

-- Keep ALL collidable land geometry on the LAND side (past waterEdgeX) so nothing overlaps the boat.
local platformCenter = Vector3.new(waterEdgeX + HUB_SIDE * (PLATFORM_SX / 2), WATER_Y + 2.5, HUB_Z)
block("HubPlatform", Vector3.new(PLATFORM_SX, 1, 46), Color3.fromRGB(120, 110, 92), CFrame.new(platformCenter), Enum.Material.Ground)
block(
	"PlaneWreck",
	Vector3.new(10, 7, 24),
	Color3.fromRGB(150, 150, 160),
	CFrame.new(platformCenter + Vector3.new(HUB_SIDE * 4, 4, -12)) * CFrame.Angles(0, math.rad(20), math.rad(8)),
	Enum.Material.Metal
)

-- The boat spawns mid-channel; it starts moored OFF the pier. Players PULL the rope to reel it in until it
-- docks ALONGSIDE the jetty — kept fully in the water (DOCK_MARGIN of clear water to shore). Translate only
-- (keep heading) so BoatServer's captured desiredYaw stays valid and the boat won't snap-rotate on release.
local rotOnly = hull.CFrame - hull.CFrame.Position
local DOCKED_X = waterEdgeX - HUB_SIDE * (hull.Size.X / 2 + DOCK_MARGIN)
local REEL_OFFSET = 26 -- how far off the pier it starts (studs)
local dockedPos = Vector3.new(DOCKED_X, WATER_Y + 2, HUB_Z)
local startPos = Vector3.new(DOCKED_X - HUB_SIDE * REEL_OFFSET, WATER_Y + 2, HUB_Z)

local function moveBoatTo(p: Vector3)
	boat:PivotTo(CFrame.new(p) * rotOnly)
end
moveBoatTo(startPos)

-- hub spawn point (read by PlayerCombat before the run starts)
local spawnPos = platformCenter + Vector3.new(0, 3, 0)
Workspace:SetAttribute("HubSpawn", spawnPos)

-- jetty: a walkway from the shore out over the water to the boat's side, ending ~1 stud short of the boat
-- (no overlap → the boat launches free). Players walk it to board. CanCollide so you can stand on it.
local boatEdgeX = DOCKED_X + HUB_SIDE * (hull.Size.X / 2) -- boat edge facing the shore
local jettyTipX = boatEdgeX + HUB_SIDE * 1 -- 1-stud step gap from the boat
local jettyLenX = math.max(2, math.abs(waterEdgeX - jettyTipX))
local jettyCenterX = (waterEdgeX + jettyTipX) / 2
block("Jetty", Vector3.new(jettyLenX, 0.5, 12), Color3.fromRGB(110, 80, 55), CFrame.new(jettyCenterX, WATER_Y + 2.7, HUB_Z), Enum.Material.WoodPlanks)

-- winch at the jetty's boat-side tip (PLACEHOLDER cube; non-colliding so it never blocks the boat). Pull lives here.
local post = block("Winch", Vector3.new(3, 3, 3), Color3.fromRGB(210, 120, 40), CFrame.new(jettyTipX, WATER_Y + 4.2, HUB_Z), Enum.Material.Metal)
post.CanCollide = false
local a0 = Instance.new("Attachment")
a0.Parent = hull
local a1 = Instance.new("Attachment")
a1.Parent = post -- parent first, then set world position
a1.WorldPosition = post.Position + Vector3.new(0, 1, 0)
local rope = Instance.new("RopeConstraint")
rope.Attachment0 = a0
rope.Attachment1 = a1
rope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude
rope.Thickness = 0.15
rope.Visible = true
rope.Color = BrickColor.new("Brown")
rope.Parent = hull

-- prompt: PULL (reel the boat to the pier) → then UNTIE (launch)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "MooringPrompt"
prompt.ActionText = "Pull rope"
prompt.ObjectText = "Winch"
prompt.HoldDuration = 0.4
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 24
prompt.Parent = post

local PULL_STEP = 8 -- studs reeled per pull
local DOCK_DIST = 3 -- within this of the dock = docked
local started = false
local docked = false
local reeling = false

local function refreshRope()
	rope.Length = math.max(1, (a0.WorldPosition - a1.WorldPosition).Magnitude)
end

local function reel()
	if reeling or docked then
		return
	end
	reeling = true
	local from = hull.Position
	local flat = Vector3.new(dockedPos.X - from.X, 0, dockedPos.Z - from.Z)
	local stepDist = math.min(PULL_STEP, flat.Magnitude)
	local to = from + (if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero) * stepDist
	for i = 1, 12 do -- smooth haul over ~0.25s
		moveBoatTo(from:Lerp(to, i / 12))
		refreshRope()
		task.wait(0.02)
	end
	if (Vector3.new(hull.Position.X - dockedPos.X, 0, hull.Position.Z - dockedPos.Z)).Magnitude <= DOCK_DIST then
		docked = true
		moveBoatTo(dockedPos)
		refreshRope()
		prompt.ActionText = "Untie rope — START"
		print("[Staging] boat docked — board it, then untie to start")
	end
	reeling = false
end

local function startRun()
	if started or not docked then
		return
	end
	if ((boat:GetAttribute("OnBoatCount") :: number?) or 0) < 1 then
		return -- someone must be aboard to launch (don't sail off without the crew)
	end
	started = true
	Workspace:SetAttribute("RunStarted", true)
	hull.Anchored = false
	boat:SetAttribute("Tied", false)
	rope:Destroy()
	a0:Destroy()
	a1:Destroy()
	prompt:Destroy()
	Workspace:SetAttribute("HubSpawn", nil)
	-- leave the greybox hub standing behind (the crew has sailed off on the boat)
	print("[Staging] rope untied — RUN STARTED")
end

prompt.Triggered:Connect(function()
	if not docked then
		reel()
	else
		startRun()
	end
end)

-- accurate "on boat" test: raycast straight down from the player and only count a hit on a BOAT part.
-- (A bounding box overlaps the pier when the boat is docked ~2 studs off it, wrongly counting pier-standers.)
local function isOnBoat(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { boat }
	params.IgnoreWater = true
	return Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params) ~= nil
end

-- boat-occupancy readout while staging: "N/M on boat" (published as Boat attributes for the client HUD)
task.spawn(function()
	while not started do
		local onBoat = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and isOnBoat(root) then
				onBoat += 1
			end
		end
		boat:SetAttribute("OnBoatCount", onBoat)
		boat:SetAttribute("CrewCount", #Players:GetPlayers())
		task.wait(0.4)
	end
end)

print("[Staging] crash-site hub + moored boat online (untie to start)")
