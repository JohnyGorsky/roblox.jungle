--!strict
-- MeleeClient.local.luau — tap-to-swing when the Sword is the active item (Job 015).
--
-- Only requests a swing when the active loadout item is the Sword; the guns are handled by WeaponClient.
-- The server does all validation + hit detection (see MeleeServer). Anim/feedback polish is a later pass.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SwordSwing") :: RemoteEvent

local function swordActive(): boolean
	return player:GetAttribute("ActiveItem") == "Sword" and player:GetAttribute("Busy") ~= true
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- tap landed on a GUI button (e.g. the hotbar)
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if swordActive() then
			remote:FireServer()
		end
	end
end)
