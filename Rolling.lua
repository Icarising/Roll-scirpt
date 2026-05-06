repeat task.wait() until game:IsLoaded()

--// whole bunch of variables yes
local TS = game:GetService("TweenService")
local Rep = game:GetService("ReplicatedStorage")
local UISounds = workspace:WaitForChild("UISounds")
local UI = script.Parent
local Buttons = UI:WaitForChild("Buttons")
local SettingsFrame = UI:WaitForChild("Settings")
local SettingsF = SettingsFrame:WaitForChild("Objs")
local Effects = UI:WaitForChild("Effects")
local Players = game:GetService("Players")
local SummonMod = require(game:GetService("ReplicatedStorage"):WaitForChild("ClientModules"):WaitForChild("Summon"))
local plr = Players.LocalPlayer
local Events = require(script:WaitForChild("Events"))
local MenuStuff = UI.MenuStuff
local Inventorys = MenuStuff.Inventorys
local Settings = plr:FindFirstChild("Settings")
local EffectsFolder = plr:WaitForChild("Junk"):WaitForChild("Effects")
local Controls = require(plr.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local WaitTime, Open, Selection = 0, false, ""
local RollCooldown = 1
local QuickRoll = false
local AutoRoll = false
local Cutscenes = require(Rep:WaitForChild("ClientModules"):WaitForChild("AuraDetails"))
local Wclicked = false
local Lclicked = false	
local WarningUI = UI.Rolling.Warning
local PSettings = plr:WaitForChild("Settings")
local autoEquip = PSettings:FindFirstChild("AutoEquip") 
local skipWarning = PSettings:FindFirstChild("SkipWarning") 
local playCutscene = PSettings:FindFirstChild("PlayCutscene") 
local Rolling = false

local function GetAuraGradientColor(AuraName)
    local Auras = Rep:WaitForChild("Auras")
    local GradientColor = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255, 0, 4)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 0, 4))})

    for i,v in pairs(Auras:GetChildren()) do
        if v.Name == AuraName then
            if v:FindFirstChild("HeadUI") ~= nil then
                GradientColor = v.HeadUI.Chance.UIGradient.Color
            end
        end
    end

    return GradientColor
end

local function Warn(Type,Aura)
    if Type == "Skip" then
        WarningUI.Keep.Text = "Don't Skip"
        WarningUI.Remov.Text = "Skip"
        WarningUI["DAWG?"].Text = "Are you sure you want to skip this "..tostring(Aura).." aura?"
        WarningUI.Deleting.Text = "Skipping : "..tostring(Aura)
        WarningUI.UIGradient.Color = GetAuraGradientColor(Aura) or ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 255, 255))})
        WarningUI.Visible = true
    else
        WarningUI.Keep.Text = "Equip"
        WarningUI.Remov.Text = "Don't Equip"
        WarningUI["DAWG?"].Text = "Your inventory is full, are you sure you want to equip this aura?"
        WarningUI.Deleting.Text = "Equipping : "..tostring(Aura)
        WarningUI.UIGradient.Color = GetAuraGradientColor(Aura) or ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 255, 255))})
        WarningUI.Visible = true
    end
end

local function fakeroll()
    local fake,fake2 = SummonMod.Roll(plr)
    return fake,fake2
end;

local function ShowAura(AuraName,Chance,Speed)
    local RUI = UI.Rolling
    local PSI = RUI.PSI

    local RollSound = UISounds:WaitForChild("Cutscenes").Roll:Clone()
    RollSound.Parent = workspace
    RollSound.PlaybackSpeed = Speed
    RollSound:Play()

    game.Debris:AddItem(RollSound,.5)

    local GradientColor = GetAuraGradientColor(AuraName)
    PSI.AuraName.Text = AuraName
    PSI.Chance.Text = "1 in "..tostring(Chance)
    PSI.AuraName.UIGradient.Color = GradientColor
    PSI.Chance.UIGradient.Color = GradientColor
    PSI.Size = UDim2.new(.5,0,.376,0)
    PSI.Position = UDim2.new(.25,0,.25,0)

    TS:Create(PSI,TweenInfo.new(.125/Speed,Enum.EasingStyle.Sine),{Size = UDim2.new(.5,0,0.484,0);Position = UDim2.new(.25,0,.25,0)}):Play()

    task.wait(.14/Speed)

end


local function rollForAura()
    if Rolling or not UI.Enabled then return end
    UI.MenuStuff.Inventorys.Visible = false

    Rolling = true
    local Roll = UI.Rolling
    Roll.Warning.Visible = false
    Roll.Visible = true
    Roll.Equip.Visible = false
    Roll.Skip.Visible = false

    local Speed = 1
    local RollCooldown = 1

    --// Adjust speed and cooldown based on potions
    local potions = {"Speed Potion I", "Speed Potion II", "Speed Potion III"}
    local potionEffects = {0.15, 0.35, 0.5}
    local potionCooldowns = {0.15, 0.34, 0.5}
    for i, potion in ipairs(potions) do
        if EffectsFolder:FindFirstChild(potion) then
            Speed += potionEffects[i]
            RollCooldown -= potionCooldowns[i]
        end
    end

    --// Gear effects
    local gval = Players.LocalPlayer:WaitForChild("gear").Value
    local gearSpeedMap = {["None"] = 0.05, ["Flare Gear"] = 0.15, ["Starry Device"] = 4.44}
    Speed += gearSpeedMap[gval] or 0

    Buttons.Visible = true
    Roll.BackgroundTransparency = (RollCooldown < 0.1 and AutoRoll) and 1 or 0.5

    if not QuickRoll then
        for i = 1, 8 do
            local Aura, Chance = fakeroll()
            ShowAura(Aura, Chance, Speed)
        end
    end

    local ActualThing, Chance = script.ClientChecks:InvokeServer("GetRoll")
    ShowAura(ActualThing, Chance, Speed)

    --// handle aura warnings, equipping, skipping, etc

    local function handleWarnings(Type)
        local inventoryFull = plr.Junk.CurrentValue.Value >= plr.Junk.MaxValue.Value
        if Type == "Skip" and skipWarning.Value < tonumber(Chance) then
            Warn("Skip", ActualThing)
            return false, true
        elseif inventoryFull then
            Warn("Equip", ActualThing)
            return true, false
        end
        return false, false
    end

    local function EquipAura()
        if plr.Junk.CurrentValue.Value >= plr.Junk.MaxValue.Value then
            local Equip, _ = handleWarnings()
            if not Equip then return false end
        end
        script.ClientChecks:InvokeServer("EquipThing")
        return true
    end

    local function SkipAura()
        if tonumber(skipWarning.Value) < tonumber(Chance) then
            local _, Skip = handleWarnings("Skip")
            if not Skip then return false end
        end
        return true
    end

    local function waitForChoice()
        Wclicked, Lclicked = false, false
        local choiceMade = false

        local function connectButton(btn, func)
            local conn
            conn = btn.MouseButton1Click:Connect(function()
                if func() then
                    choiceMade = true
                    btn.Visible = false
                    conn:Disconnect()
                end
            end)
            return conn
        end

        if AutoRoll then
            if autoEquip.Value < tonumber(Chance) then
                connectButton(Roll.Equip, EquipAura)
            elseif tonumber(skipWarning.Value) < tonumber(Chance) then
                connectButton(Roll.Skip, SkipAura)
            end
        else
            Roll.Equip.Visible = true
            Roll.Skip.Visible = true
            connectButton(Roll.Equip, EquipAura)
            connectButton(Roll.Skip, SkipAura)
        end

        repeat task.wait(0.1) until choiceMade
    end

    waitForChoice()

    --// QuickRoll remote check
    if QuickRoll and math.random(1, 100) == 1 then
        if not script.ClientChecks:InvokeServer("GRCD") then
            game.Players.LocalPlayer:Kick("(Quickroll Not Found) An Error Occured")
        end
    end

    --// Reset UI
    if UI.Enabled then
        for _, v in pairs(script.Parent:GetChildren()) do
            if v:IsA("TextButton") then v.Visible = true end
        end

        Roll.Visible = false
        local F = Instance.new("Frame", UI.Roll)
        F.Size = UDim2.new(1, 0, 1, 0)
        F.ZIndex = 100
        F.BackgroundTransparency = 0.5
        F.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        TS:Create(F, TweenInfo.new(RollCooldown), {Size = UDim2.new(0, 0, 1, 0)}):Play()
        game.Debris:AddItem(F, RollCooldown)
    end

    task.delay(RollCooldown, function() Rolling = false end)
end


UI.QuickRoll.MouseButton1Click:Connect(function()
    UISounds.gui_click:Play()
    local QR = script.ClientChecks:InvokeServer("GRCD")
    if QR == true then
        QuickRoll = not QuickRoll
        if QuickRoll == true then

            UI.QuickRoll.Text = "QuickRoll : On"
        else
            UI.QuickRoll.Text = "QuickRoll : Off"
        end

        UISounds.Success_Sound:Play()
    else
        UISounds["error-WINDOWS XP"]:Play()
    end
end)

UI.Roll.MouseButton1Click:Connect(rollForAura)

UI.AutoRoll.MouseButton1Click:Connect(function()
    AutoRoll = not AutoRoll
    if AutoRoll == true then
        UI.AutoRoll.Text = "AutoRoll : On"
        while AutoRoll == true do
            rollForAura()
            task.wait(.02)
        end
    else
        UI.AutoRoll.Text = "AutoRoll : Off"
    end
end)

UI.Rolling.Warning.Keep.MouseButton1Click:Connect(function()	UISounds.gui_click:Play()	Wclicked = true end)
UI.Rolling.Warning.Remov.MouseButton1Click:Connect(function() UISounds.gui_click:Play()    Lclicked = true end)	
