if not game:IsLoaded() then
	game.Loaded:Wait()
end

----------- [ Services ] ----------------

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

----------- [ Player ] ----------------

local plr = Players.LocalPlayer
local PlayerGui = script.Parent

----------- [ UI ] ----------------

local Buttons = PlayerGui:WaitForChild("Buttons")
local RollingUI = PlayerGui:WaitForChild("Rolling")
local WarningUI = RollingUI:WaitForChild("Warning")
local AuraDisplay = RollingUI:WaitForChild("PSI")

----------- [ Modules ] ----------------

local ClientModules = ReplicatedStorage:WaitForChild("ClientModules")

local SummonModule = require(ClientModules:WaitForChild("Summon"))
local AuraDetails = require(ClientModules:WaitForChild("AuraDetails"))

----------- [ Sounds ] ----------------

local UISounds = workspace:WaitForChild("UISounds")

----------- [ Remotes ] ----------------

local ClientChecks = script:WaitForChild("ClientChecks")

----------- [ Player Data ] ----------------

local Settings = plr:WaitForChild("Settings")
local EffectsFolder = plr:WaitForChild("Junk"):WaitForChild("Effects")

local AutoEquip = Settings:WaitForChild("AutoEquip")
local SkipWarning = Settings:WaitForChild("SkipWarning")

----------- [ States ] ----------------

local Rolling = false
local AutoRoll = false
local QuickRoll = false

----------- [ Config ] ----------------

local FakeRollAmount = 8
local AutoRollDelay = 0.05
local BaseSpeed = 1

local DefaultGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255))
})

local PotBoosts = {
	["Speed Potion I"] = 0.15,
	["Speed Potion II"] = 0.35,
	["Speed Potion III"] = 0.5,
}

local GearBoosts = {
	["None"] = 0.05,
	["Flare Gear"] = 0.15,
	["Starry Device"] = 4.44,
}

----------- [ Functions ] ----------------

--// gets aura ui gradient
local function GetAuraGradient(AuraName)
	local AuraFolder = ReplicatedStorage:WaitForChild("Auras")
	local Aura = AuraFolder:FindFirstChild(AuraName)

	if Aura and Aura:FindFirstChild("HeadUI") then
		return Aura.HeadUI.Chance.UIGradient.Color
	end

	return DefaultGradient
end

--// calculates total roll speed
local function GetRollSpeed()
	local Speed = BaseSpeed

	for PotionName, Boost in PotBoosts do
		if EffectsFolder:FindFirstChild(PotionName) then
			Speed += Boost
		end
	end

	local EquippedGear = plr:WaitForChild("gear").Value
	Speed += GearBoosts[EquippedGear] or 0

	return Speed
end

--// plays rolling sound effect
local function PlayRollSound(Speed)
	local RollSound = UISounds.Cutscenes.Roll:Clone()

	RollSound.Parent = workspace
	RollSound.PlaybackSpeed = Speed

	RollSound:Play()

	Debris:AddItem(RollSound, 1)
end

--// displays current rolled aura
local function ShowAura(AuraName, AuraChance, Speed)

	PlayRollSound(Speed)

	local Gradient = GetAuraGradient(AuraName)

	AuraDisplay.AuraName.Text = AuraName
	AuraDisplay.Chance.Text = `1 in {AuraChance}`

	AuraDisplay.AuraName.UIGradient.Color = Gradient
	AuraDisplay.Chance.UIGradient.Color = Gradient

	AuraDisplay.Size = UDim2.new(.5,0,.376,0)

	TweenService:Create(
		AuraDisplay,
		TweenInfo.new(.125 / Speed, Enum.EasingStyle.Sine),
		{
			Size = UDim2.new(.5,0,.484,0)
		}
	):Play()

	task.wait(.14 / Speed)
end

--// fake roll animation
local function FakeRoll()
	return SummonModule.Roll(plr)
end

--// checks if inventory is full
local function InventoryFull()
	return plr.Junk.CurrentValue.Value >= plr.Junk.MaxValue.Value
end

----------- [ Roll Function ] ----------------

local function RollAura()

	if Rolling then
		return
	end

	if not PlayerGui.Enabled then
		return
	end

	Rolling = true

	RollingUI.Visible = true
	WarningUI.Visible = false

	local Speed = GetRollSpeed()

	--// fake rolls before actual roll
	if not QuickRoll then
		for i = 1, FakeRollAmount do

			local FakeAura, FakeChance = FakeRoll()
			ShowAura(FakeAura, FakeChance, Speed)
		end
	end

	--// server-sided roll result(what they actually roolled)
	local AuraName, AuraChance = ClientChecks:InvokeServer("GetRoll")
	ShowAura(AuraName, AuraChance, Speed)

	--// auto equip logic
	if AutoEquip.Value >= AuraChance then
		if InventoryFull() then
			WarningUI.Visible = true
		else
			ClientChecks:InvokeServer("EquipThing")
		end
	end

	task.wait(.5)

	RollingUI.Visible = false
	Rolling = false
end

----------- [ Buttons ] ----------------

PlayerGui.Roll.MouseButton1Click:Connect(function()
	UISounds.gui_click:Play()
	RollAura() --// roll an aura wow
end)

PlayerGui.QuickRoll.MouseButton1Click:Connect(function()

	UISounds.gui_click:Play()

	local HasQuickRoll = ClientChecks:InvokeServer("GRCD") --// check if the player has the quick roll gamepass on the sever

	if not HasQuickRoll then
		UISounds["error-WINDOWS XP"]:Play()
		return
	end

	QuickRoll = not QuickRoll
	PlayerGui.QuickRoll.Text =	QuickRoll and "QuickRoll : On"	or "QuickRoll : Off"

	UISounds.Success_Sound:Play()
end)

PlayerGui.AutoRoll.MouseButton1Click:Connect(function()

	AutoRoll = not AutoRoll
	PlayerGui.AutoRoll.Text = AutoRoll and "AutoRoll : On" or "AutoRoll : Off"

	if not AutoRoll then
		return
	end

	task.spawn(function()

		while AutoRoll do

			local Success, Error = pcall(function()
				RollAura()
			end)

			if not Success then
				warn(Error)
			end

			task.wait(AutoRollDelay)
		end
	end)
        
end)
