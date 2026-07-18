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
local MAX_RANGE = 350
local FIRE_INTERVAL = 0.22 -- min seconds between shots per player (anti-spam)

local remote = Instance.new("RemoteEvent")
remote.Name = "FireWeapon"
remote.Parent = ReplicatedStorage

local lastShot: { [Player]: number } = {}

local function enemyFrom(inst: Instance?): Model?
	local cur: Instance? = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and CollectionService:HasTag(cur, "Enemy") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
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
	local dist = math.min(delta.Magnitude, MAX_RANGE)
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
