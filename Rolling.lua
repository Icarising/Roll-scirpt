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
local WarningOpen = false

----------- [ Config ] ----------------

local FakeRollAmount = 8
local AutoRollDelay = 0.05
local BaseSpeed = 1
local RollCooldown = 1

local UIAnimations = {
	RollTweenTime = .125,
	FadeTime = .2
}

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

----------- [ Cache ] ----------------

local AuraCache = {}

----------- [ Functions ] ----------------

--// reusable tween function
local function CreateTween(Object, Time, Properties, Style, Direction)

	local Tween = TweenService:Create(
		Object,
		TweenInfo.new(
			Time,
			Style or Enum.EasingStyle.Sine,
			Direction or Enum.EasingDirection.Out
		),
		Properties
	)

	Tween:Play()

	return Tween
end

--// caches aura gradients for faster access
local function BuildAuraCache()

	local AuraFolder = ReplicatedStorage:WaitForChild("Auras")

	for _, Aura in AuraFolder:GetChildren() do

		if Aura:FindFirstChild("HeadUI") then

			AuraCache[Aura.Name] =
				Aura.HeadUI.Chance.UIGradient.Color
		end
	end
end

BuildAuraCache()

--// gets aura ui gradient
local function GetAuraGradient(AuraName)

	return AuraCache[AuraName] or DefaultGradient
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

--// resets ui back to default state
local function ResetRollUI()

	AuraDisplay.Position = UDim2.new(.25,0,.25,0)
	AuraDisplay.Size = UDim2.new(.5,0,.376,0)

	AuraDisplay.TextTransparency = 0
	AuraDisplay.BackgroundTransparency = 0

	WarningUI.Visible = false
	RollingUI.Visible = false
end

--// creates cooldown visual effect
local function CreateCooldownVisual()

	local CooldownFrame = Instance.new("Frame")

	CooldownFrame.Name = "CooldownFrame"
	CooldownFrame.Parent = PlayerGui.Roll

	CooldownFrame.BackgroundColor3 = Color3.fromRGB(255,0,0)
	CooldownFrame.BackgroundTransparency = .5

	CooldownFrame.BorderSizePixel = 0
	CooldownFrame.ZIndex = 100

	CooldownFrame.Size = UDim2.new(1,0,1,0)

	local Tween = CreateTween(
		CooldownFrame,
		RollCooldown,
		{
			Size = UDim2.new(0,0,1,0)
		}
	)

	Tween.Completed:Wait()

	CooldownFrame:Destroy()
end

--// opens warning ui
local function OpenWarning(Type, AuraName)

	WarningOpen = true

	local Gradient = GetAuraGradient(AuraName)

	WarningUI.Visible = true
	WarningUI.UIGradient.Color = Gradient

	if Type == "Skip" then

		WarningUI.Keep.Text = "Keep"
		WarningUI.Remov.Text = "Skip"

		WarningUI["DAWG?"].Text =
			`Skip {AuraName}?`

	else

		WarningUI.Keep.Text = "Equip"
		WarningUI.Remov.Text = "Don't Equip"

		WarningUI["DAWG?"].Text =
			"Inventory Full"
	end
end

--// closes warning ui
local function CloseWarning()

	WarningOpen = false
	WarningUI.Visible = false
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

	local Tween = CreateTween(
		AuraDisplay,
		UIAnimations.RollTweenTime / Speed,
		{
			Size = UDim2.new(.5,0,.484,0)
		}
	)

	Tween.Completed:Wait()
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

	Buttons.Visible = false

	RollingUI.Visible = true
	WarningUI.Visible = false

	local Speed = GetRollSpeed()

	--// fake roll animation before actual result
	if not QuickRoll then --// if they have quickrool on skip this animation
		for i = 1, FakeRollAmount do
			local FakeAura, FakeChance = FakeRoll()
			ShowAura(FakeAura, FakeChance, Speed)
		end
	end

	--// actual server-sided aura roll(what the player actualled rollyed)
	local AuraName, AuraChance = ClientChecks:InvokeServer("GetRoll")
	ShowAura(AuraName, AuraChance, Speed)

	--// random quickroll ownership verification
	if QuickRoll and math.random(1,100) == 1 then
		local Valid = ClientChecks:InvokeServer("GRCD")

		if not Valid then
			plr:Kick("QuickRoll Verification Failed")
		end
	end

	--// auto equip logic
	if AutoEquip.Value >= AuraChance then
		if InventoryFull() then
			OpenWarning("Equip", AuraName)
		else
			ClientChecks:InvokeServer("EquipThing")
		end
	end

	--// fade ui out after roll
	CreateTween(
		AuraDisplay,
		UIAnimations.FadeTime,
		{
			BackgroundTransparency = 1
		}
	).Completed:Wait()

	task.spawn(CreateCooldownVisual)

	task.wait(.25)

	ResetRollUI()

	Buttons.Visible = true
	Rolling = false
end

----------- [ Buttons ] ----------------

PlayerGui.Roll.MouseButton1Click:Connect(function()
	UISounds.gui_click:Play()
	RollAura()
end)

PlayerGui.QuickRoll.MouseButton1Click:Connect(function()

	UISounds.gui_click:Play()

	--// checks if player owns quickroll
	local HasQuickRoll = ClientChecks:InvokeServer("GRCD")

	if not HasQuickRoll then
		UISounds["error-WINDOWS XP"]:Play()
		return
	end

	QuickRoll = not QuickRoll

	PlayerGui.QuickRoll.Text =	QuickRoll and "QuickRoll : On"		or "QuickRoll : Off"

	UISounds.Success_Sound:Play()
end)

PlayerGui.AutoRoll.MouseButton1Click:Connect(function()

	if Rolling then
		return
	end

	AutoRoll = not AutoRoll

	PlayerGui.AutoRoll.Text =	AutoRoll and "AutoRoll : On"	or "AutoRoll : Off"

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

----------- [ Warning Buttons ] ----------------

WarningUI.Keep.MouseButton1Click:Connect(function()
	UISounds.gui_click:Play()
	CloseWarning()
	ClientChecks:InvokeServer("EquipThing")
end)

WarningUI.Remov.MouseButton1Click:Connect(function()
	UISounds.gui_click:Play()
	CloseWarning()
end)
