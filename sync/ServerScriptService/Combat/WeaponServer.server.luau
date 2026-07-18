--!strict
-- WeaponServer.server.luau — authoritative free-aim hitscan (Job 006 POC).
--
-- The client sends only the world AIM POINT it tapped. The SERVER re-raycasts from the shooter's own
-- character toward that point and applies damage — the client never says "I hit X", so it can't fake
-- hits. Rate-limited per player. Enemies are identified by the "Enemy" CollectionService tag.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WEAPON_DAMAGE = 20 -- croc hp 40 → 2 clean hits
local WEAPON_RANGE = 220 -- can only hit enemies within this distance of the shooter
local FIRE_INTERVAL = 0.22 -- min seconds between shots per player (anti-spam)
local ROUNDS_PER_AMMO = 12 -- shots reloaded per looted ammo crate

local remote = Instance.new("RemoteEvent")
remote.Name = "FireWeapon"
remote.Parent = ReplicatedStorage

local lastShot: { [Player]: number } = {}

local function enemyFrom(inst: Instance?): Model?
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and (CollectionService:HasTag(cur, "Enemy") or CollectionService:HasTag(cur, "CampGuard")) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

-- the player currently driving the boat (occupant of the DriverSeat)
local function isDriver(player: Player): boolean
	local boat = Workspace:FindFirstChild("Boat")
	local seat = boat and boat:FindFirstChild("DriverSeat")
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return seat ~= nil and seat:IsA("VehicleSeat") and hum ~= nil and seat.Occupant == hum
end

-- who's allowed to shoot: not the driver, and not "Busy" (fishing/catching sets this attribute)
local function canShoot(player: Player): boolean
	if isDriver(player) then
		return false
	end
	if player:GetAttribute("Busy") == true then
		return false
	end
	return true
end

remote.OnServerEvent:Connect(function(player: Player, aimPoint: any)
	if typeof(aimPoint) ~= "Vector3" then
		return
	end
	local now = time()
	local last = lastShot[player]
	if last and now - last < FIRE_INTERVAL then
		return
	end
	lastShot[player] = now

	-- only certain players may shoot (not the driver, not while fishing/busy)
	if not canShoot(player) then
		return
	end

	-- ammo: draw a round from the boat's cargo; reload the round-pool from ammo crates; out of ammo = no shot
	local ammoStore = Workspace:FindFirstChild("Boat")
	if ammoStore then
		local rounds = (ammoStore:GetAttribute("Rounds") :: number?) or 0
		if rounds <= 0 then
			local crates = (ammoStore:GetAttribute("Ammo") :: number?) or 0
			if crates <= 0 then
				return -- out of ammo
			end
			ammoStore:SetAttribute("Ammo", crates - 1)
			rounds = ROUNDS_PER_AMMO
		end
		ammoStore:SetAttribute("Rounds", rounds - 1)
	end

	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local origin = root.Position
	local delta = aimPoint - origin
	local dist = math.min(delta.Magnitude, WEAPON_RANGE) -- ray stops at range → enemies beyond can't be hit
	if dist < 0.1 then
		return
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = { char }
	local boatModel = Workspace:FindFirstChild("Boat")
	if boatModel then
		table.insert(filter, boatModel)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, delta.Unit * dist, params)
	if result then
		local enemy = enemyFrom(result.Instance)
		if enemy then
			local hp = (enemy:GetAttribute("HP") :: number?) or 0
			enemy:SetAttribute("HP", math.max(0, hp - WEAPON_DAMAGE))
		end
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastShot[p] = nil
end)
