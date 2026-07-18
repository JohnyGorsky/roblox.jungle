--!strict
-- PlayerCombat.server.luau — player health, downed state, bandage revive (Job 008).
--
-- Players carry an "HP" attribute on their character (threats reduce it — see EnemyServer). At 0 HP a
-- player goes DOWNED instead of dying: can't move, a bleed-out timer runs, and a teammate can revive
-- them by holding a ProximityPrompt (costs one scarce bandage). Bleed-out expiry = real death/respawn.
-- Server-authoritative.

local Players = game:GetService("Players")

local MAX_HP = 100
local REVIVE_HP = 50
local BLEEDOUT = 30 -- seconds downed before dying
local REVIVE_HOLD = 3 -- seconds a teammate must hold to revive
local START_BANDAGES = 3
local REVIVE_RANGE = 12

local function setupCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	local root = char:WaitForChild("HumanoidRootPart") :: BasePart
	local walk, jump = hum.WalkSpeed, hum.JumpHeight

	char:SetAttribute("MaxHP", MAX_HP)
	char:SetAttribute("HP", MAX_HP)
	char:SetAttribute("Downed", false)

	local bleedThread: thread? = nil

	local function clearBleed()
		if bleedThread then
			task.cancel(bleedThread)
			bleedThread = nil
		end
	end

	local function revive()
		if not char:GetAttribute("Downed") then
			return
		end
		char:SetAttribute("Downed", false)
		char:SetAttribute("HP", REVIVE_HP)
		hum.WalkSpeed, hum.JumpHeight = walk, jump
		local prompt = root:FindFirstChild("RevivePrompt")
		if prompt then
			prompt:Destroy()
		end
		clearBleed()
	end

	local function enterDowned()
		if char:GetAttribute("Downed") then
			return
		end
		char:SetAttribute("Downed", true)
		char:SetAttribute("HP", 0)
		hum.WalkSpeed, hum.JumpHeight = 0, 0
		hum.PlatformStand = true -- flop over (greybox "downed" pose)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = REVIVE_HOLD
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = REVIVE_RANGE
		prompt.Parent = root

		prompt.Triggered:Connect(function(reviver: Player)
			if reviver == player then
				return -- no self-revive (that's the paid revive, P8)
			end
			local rc = reviver.Character
			if not rc or rc:GetAttribute("Downed") then
				return
			end
			local bandages = (reviver:GetAttribute("Bandages") :: number?) or 0
			if bandages <= 0 then
				return
			end
			reviver:SetAttribute("Bandages", bandages - 1)
			revive()
		end)

		hum.PlatformStand = true
		bleedThread = task.delay(BLEEDOUT, function()
			if char:GetAttribute("Downed") then
				hum.Health = 0 -- bled out → real death → respawn
			end
		end)
	end

	char:GetAttributeChangedSignal("HP"):Connect(function()
		if not char:GetAttribute("Downed") and ((char:GetAttribute("HP") :: number?) or MAX_HP) <= 0 then
			enterDowned()
		end
	end)

	hum.Died:Connect(clearBleed)
end

local function setupPlayer(player: Player)
	player:SetAttribute("Bandages", START_BANDAGES)
	if player.Character then
		setupCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		setupCharacter(player, char)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)
