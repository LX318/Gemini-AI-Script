-- ============================================================
-- 琳琅天上 | DIG 完整整合版
-- LiquidGlass UI
-- ============================================================

local LiquidGlass = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/fischgesichtert/LiquidGlass/main/dist/LiquidGlass.lua"
))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- UI 初始化
-- ============================================================

local Window = LiquidGlass:CreateWindow({
    Title = "琳琅天上",
    Subtitle = "dig 挖矿模块",
    Icon = "bolt",
})

local MainTab = Window:AddTab({
    Title = "主要功能",
    Icon = "star"
})

local MainSec = MainTab:AddSection("常用功能")
local DrillSec = MainTab:AddSection("钻头传送")

local DigTab = Window:AddTab({
    Title = "挖矿",
    Icon = "home"
})

local Dig = DigTab:AddSection("挖矿")

local AutoTab = Window:AddTab({
    Title = "自动化",
    Icon = "zap"
})

local Auto = AutoTab:AddSection("自动化")

-- ============================================================
-- 共享变量
-- ============================================================

local autoHitEnabled = false
local miningConnection = nil

local autoBossEnabled = false
local bossInterval = 0.8

local instantDigEnabled = false
local digDelay = 0.8

local autoEquipEnabled = false
local equipInterval = 0.01

local autoClickEnabled = false
local clickInterval = 4

local xpNotifyEnabled = true

-- ============================================================
-- 静音游戏内所有声音
-- ============================================================

local isMuted = false
local SAVED_ATTR = "_savedVol"

local function muteOneSound(sound)
    if not sound:IsA("Sound") then return end

    if sound:GetAttribute(SAVED_ATTR) == nil then
        sound:SetAttribute(SAVED_ATTR, sound.Volume)
    end

    sound.Volume = 0
end

local function restoreOneSound(sound)
    if not sound:IsA("Sound") then return end

    local saved = sound:GetAttribute(SAVED_ATTR)

    if saved ~= nil then
        sound.Volume = saved
        sound:SetAttribute(SAVED_ATTR, nil)
    end
end

local function muteOneSoundGroup(sg)
    if not sg:IsA("SoundGroup") then return end

    if sg:GetAttribute(SAVED_ATTR) == nil then
        sg:SetAttribute(SAVED_ATTR, sg.Volume)
    end

    sg.Volume = 0
end

local function restoreOneSoundGroup(sg)
    if not sg:IsA("SoundGroup") then return end

    local saved = sg:GetAttribute(SAVED_ATTR)

    if saved ~= nil then
        sg.Volume = saved
        sg:SetAttribute(SAVED_ATTR, nil)
    end
end

local function muteAllNow()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") then
            muteOneSound(obj)
        elseif obj:IsA("SoundGroup") then
            muteOneSoundGroup(obj)
        end
    end
end

local function restoreAllNow()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") then
            restoreOneSound(obj)
        elseif obj:IsA("SoundGroup") then
            restoreOneSoundGroup(obj)
        end
    end
end

game.DescendantAdded:Connect(function(obj)
    if not isMuted then return end

    if obj:IsA("Sound") then
        muteOneSound(obj)
    elseif obj:IsA("SoundGroup") then
        muteOneSoundGroup(obj)
    end
end)

local function muteAll()
    if isMuted then return end

    isMuted = true
    muteAllNow()
end

local function unmuteAll()
    if not isMuted then return end

    isMuted = false
    restoreAllNow()
end

-- ============================================================
-- 通用传送功能
-- ============================================================

local function teleportTo(obj, offset)
    if not obj or not obj.Parent then
        return false
    end

    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")

    if not hrp then
        return false
    end

    local targetPos

    if obj:IsA("BasePart") then
        targetPos = obj.Position
    else
        local primary = obj.PrimaryPart

        if primary then
            targetPos = primary.Position
        else
            local sum = Vector3.zero
            local count = 0

            for _, d in ipairs(obj:GetDescendants()) do
                if d:IsA("BasePart") then
                    sum = sum + d.Position
                    count = count + 1
                end
            end

            if count == 0 then
                return false
            end

            targetPos = sum / count
        end
    end

    hrp.CFrame =
        CFrame.new(targetPos + (offset or Vector3.new(0, 3, 0)))
        * (hrp.CFrame - hrp.CFrame.Position)

    return true
end

-- ============================================================
-- 确认传送弹窗
-- ============================================================

local function askConfirm(titleText, callback)

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local oldGui = playerGui:FindFirstChild("LingLangConfirmGui")

    if oldGui then
        oldGui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LingLangConfirmGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 99999
    gui.Parent = playerGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.4
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, 300, 0, 150)
    frame.BackgroundColor3 = Color3.fromRGB(30, 32, 38)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(90, 160, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 15)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "确认传送"
    title.Parent = frame

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, 0, 0, 40)
    desc.Position = UDim2.new(0, 0, 0, 45)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 14
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Text = "确定要传送到 " .. titleText .. " 吗？"
    desc.Parent = frame

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0, 120, 0, 36)
    confirmBtn.Position = UDim2.new(0, 20, 0, 95)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(90, 160, 255)
    confirmBtn.Font = Enum.Font.GothamBold
    confirmBtn.TextSize = 14
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.Text = "确认传送"
    confirmBtn.Parent = frame

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = confirmBtn

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 120, 0, 36)
    cancelBtn.Position = UDim2.new(0, 160, 0, 95)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 64, 75)
    cancelBtn.Font = Enum.Font.GothamBold
    cancelBtn.TextSize = 14
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.Text = "取消"
    cancelBtn.Parent = frame

    local xCorner = Instance.new("UICorner")
    xCorner.CornerRadius = UDim.new(0, 6)
    xCorner.Parent = cancelBtn

    confirmBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        callback()
    end)

    cancelBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
end

-- ============================================================
-- 自动强力挖掘
-- ============================================================

local function autoStrongHit()

    if not autoHitEnabled then
        return
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")

    local digUI = playerGui and playerGui:FindFirstChild("Dig")

    if not digUI then
        return
    end

    local safezone = digUI:FindFirstChild("Safezone")
    local holder = safezone and safezone:FindFirstChild("Holder")

    local playerBar = holder and holder:FindFirstChild("PlayerBar")
    local areaStrong = holder and holder:FindFirstChild("Area_Strong")

    if not playerBar or not areaStrong then
        return
    end

    if areaStrong.Visible and areaStrong.AbsoluteSize.X >= 2 then

        local playerPos = playerBar.Position.X.Scale
        local strongLeft = areaStrong.Position.X.Scale
        local strongRight = strongLeft + areaStrong.Size.X.Scale

        if playerPos >= strongLeft and playerPos <= strongRight then

            VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)

        end

    end

end

-- ============================================================
-- 自动打 Boss
-- ============================================================

local function autoBossLoop()

    while autoBossEnabled do

        local success, err = pcall(function()

            ReplicatedStorage.Remotes.Dig_Boss_OnHit:FireServer(true)

        end)

        if not success then
            warn("[dig] 自动打Boss失败: " .. tostring(err))
        end

        local waited = 0

        while waited < bossInterval and autoBossEnabled do

            local step = math.min(0.05, bossInterval - waited)

            task.wait(step)

            waited = waited + step

        end

    end

end

-- ============================================================
-- 秒挖
-- ============================================================

local digArgs = {
    0,
    {
        {
            Color = Color3.new(
                0.63921570777893,
                0.63529413938522,
                0.64705884456635
            ),

            Transparency = 1,

            Name = "PositionPart",

            Position = Vector3.new(
                2080.5751953125,
                108.66889190674,
                -343.86813354492
            ),

            Orientation = Vector3.zero,

            Material = Enum.Material.Plastic,

            Shape = Enum.PartType.Block,

            Size = Vector3.new(
                0.10000000149012,
                0.10000000149012,
                0.10000000149012
            )
        }
    }
}

local function fireDigOnce()

    local success, err = pcall(function()

        ReplicatedStorage.Remotes.Dig_Finished:FireServer(
            unpack(digArgs)
        )

    end)

    if not success then
        warn("[dig] 秒挖失败: " .. tostring(err))
    end

    return success

end

local function instantDigLoop()

    while instantDigEnabled do

        fireDigOnce()

        local waited = 0

        while waited < digDelay and instantDigEnabled do

            local step = math.min(0.05, digDelay - waited)

            task.wait(step)

            waited = waited + step

        end

    end

end

-- ============================================================
-- 等级 / 经验状态
-- ============================================================

local currentLevel = nil
local currentXP = nil
local xpNeeded = nil

local function formatInt(n)

    if not n then
        return "?"
    end

    return tostring(math.floor(n + 0.5))

end

-- ============================================================
-- 外置状态栏
-- ============================================================

local infoGui
local timeLabel
local bagTotalLabel
local levelLabel

local TOOL_OFFSET = 8

local function formatClock()
    return os.date("%H:%M:%S")
end

local function countBagItems()

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    local toolCount = 0

    if backpack then

        for _, child in ipairs(backpack:GetChildren()) do

            if child:IsA("Tool") then
                toolCount = toolCount + 1
            end

        end

    end

    if character then

        for _, child in ipairs(character:GetChildren()) do

            if child:IsA("Tool") then
                toolCount = toolCount + 1
            end

        end

    end

    return math.max(0, toolCount - TOOL_OFFSET)

end

local function updateLevelLabel()

    if not levelLabel then
        return
    end

    if currentLevel and currentXP and xpNeeded then

        levelLabel.Text = string.format(
            "等级 %s（%s/%s）",
            tostring(currentLevel),
            formatInt(currentXP),
            formatInt(xpNeeded)
        )

    elseif currentLevel then

        levelLabel.Text = "等级 " .. tostring(currentLevel)

    else

        levelLabel.Text = "等级 --"

    end

end

local function createInfoGui()

    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("LingLangInfoGui")

    if existing then
        existing:Destroy()
    end

    infoGui = Instance.new("ScreenGui")

    infoGui.Name = "LingLangInfoGui"
    infoGui.ResetOnSpawn = false
    infoGui.IgnoreGuiInset = true
    infoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    infoGui.Parent = playerGui

    local frame = Instance.new("Frame")

    frame.Name = "InfoFrame"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -16, 0, 16)
    frame.Size = UDim2.new(0, 190, 0, 82)

    frame.BackgroundColor3 = Color3.fromRGB(248, 250, 255)
    frame.BackgroundTransparency = 0.45
    frame.BorderSizePixel = 0
    frame.Parent = infoGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.65
    stroke.Parent = frame

    local padding = Instance.new("UIPadding")

    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = frame

    local layout = Instance.new("UIListLayout")

    layout.FillDirection = Enum.FillDirection.Vertical
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.Parent = frame

    local function makeLabel(name, color, order)

        local label = Instance.new("TextLabel")

        label.Name = name
        label.BackgroundTransparency = 1
        label.Size = UDim2.new(1, 0, 0, 18)

        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextColor3 = color

        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center

        label.Text = ""
        label.LayoutOrder = order
        label.Parent = frame

        return label

    end

    timeLabel = makeLabel(
        "TimeLabel",
        Color3.fromRGB(45, 52, 68),
        1
    )

    bagTotalLabel = makeLabel(
        "BagTotalLabel",
        Color3.fromRGB(35, 100, 190),
        2
    )

    levelLabel = makeLabel(
        "LevelLabel",
        Color3.fromRGB(120, 80, 200),
        3
    )

    updateLevelLabel()

    local gui = infoGui

    -- 时间更新
    task.spawn(function()

        while gui and gui.Parent do

            if timeLabel then
                timeLabel.Text = "时间  " .. formatClock()
            end

            task.wait(1)

        end

    end)

    -- 物品数量更新
    task.spawn(function()

        while gui and gui.Parent do

            local ok, n = pcall(countBagItems)

            if ok and bagTotalLabel then
                bagTotalLabel.Text = "物品  " .. tostring(n)
            end

            task.wait(0.5)

        end

    end)

end

local function destroyInfoGui()

    if infoGui then

        infoGui:Destroy()

        infoGui = nil
        timeLabel = nil
        bagTotalLabel = nil
        levelLabel = nil

    end

end

createInfoGui()

-- ============================================================
-- XP 经验通知
-- ============================================================

local lastXPTime = 0
local lastXPGain = 0

local function roundNum(n)

    if n >= 1000 then
        return math.floor(n + 0.5)
    end

    return math.floor(n * 10 + 0.5) / 10

end

local function handleXP(args)

    local gained = tonumber(args[1])
    local level = tonumber(args[2])
    local progress = args[3]

    if level then
        currentLevel = level
    end

    if typeof(progress) == "table" and #progress >= 3 then

        local v1 = tonumber(progress[1])
        local v3 = tonumber(progress[3])

        if v1 then currentXP = v1 end
        if v3 then xpNeeded = v3 end

    end

    updateLevelLabel()

    if not gained or gained <= 0 then
        return
    end

    local now = os.clock()

    -- 防止重复通知
    if gained == lastXPGain and (now - lastXPTime) < 0.5 then
        return
    end

    lastXPTime = now
    lastXPGain = gained

    if xpNotifyEnabled then

        local content =
            "+" .. tostring(roundNum(gained)) .. " 经验"

        if level then
            content = content .. "（等级 " .. tostring(level) .. "）"
        end

        LiquidGlass:Notify({

            Title = "经验获得",
            Content = content,
            Type = "Success",
            Duration = 2,

        })

    end

end

task.spawn(function()

    local remotes = ReplicatedStorage:WaitForChild("Remotes")

    local xpEvent = remotes:WaitForChild("Replicate_XP_Bar")

    xpEvent.OnClientEvent:Connect(function(...)

        local ok, err = pcall(handleXP, { ... })

        if not ok then
            warn("[dig] 经验通知处理失败: " .. tostring(err))
        end

    end)

end)

-- ============================================================
-- 自动装备铲子
-- ============================================================

local EQUIP_OPTIONS = {

    ["星火铲"] = "Starfire Shovel",

    ["新月铲"] = "Crescent Shovel"

}

local equipSelectedDisplay = "星火铲"

local function equipToolOnce()

    local character = LocalPlayer.Character

    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")

    if not humanoid or not backpack then
        return
    end

    local toolName = EQUIP_OPTIONS[equipSelectedDisplay]

    if not toolName then
        return
    end

    local tool = backpack:FindFirstChild(toolName)

    if tool and tool:IsA("Tool") then
        humanoid:EquipTool(tool)
    end

end

local function autoEquipLoop()

    while autoEquipEnabled do

        local ok, err = pcall(equipToolOnce)

        if not ok then
            warn("[dig] 自动装备失败: " .. tostring(err))
        end

        local waited = 0

        while waited < equipInterval and autoEquipEnabled do

            local step = math.min(0.05, equipInterval - waited)

            task.wait(step)

            waited = waited + step

        end

    end

end

-- ============================================================
-- 自动点击屏幕
-- ============================================================

local function autoClickLoop()

    while autoClickEnabled do

        local waited = 0

        while waited < clickInterval and autoClickEnabled do

            local step = math.min(0.05, clickInterval - waited)

            task.wait(step)

            waited = waited + step

        end

        if not autoClickEnabled then
            break
        end

        local ok, err = pcall(function()

            local camera = workspace.CurrentCamera

            if not camera then
                return
            end

            local screenPos = camera.ViewportSize / 2

            VIM:SendMouseButtonEvent(
                screenPos.X,
                screenPos.Y,
                0,
                true,
                game,
                0
            )

            task.wait(0.05)

            VIM:SendMouseButtonEvent(
                screenPos.X,
                screenPos.Y,
                0,
                false,
                game,
                0
            )

        end)

        if not ok then
            warn("[dig] 自动点击失败: " .. tostring(err))
        end

    end

end

-- ============================================================
-- 钻头监控
-- ============================================================

local drillOptions = {}
local drillSelectedName = nil
local drillDropdown = nil

local function scanDrills()

    drillOptions = {}

    local names = {}

    local active = workspace:FindFirstChild("Active")
    local drills = active and active:FindFirstChild("Drills")

    if not drills then
        return {"等待加载..."}
    end

    local nameCount = {}

    for _, child in ipairs(drills:GetChildren()) do

        if child:IsA("Model") or child:IsA("BasePart") then

            local realName = child.Name

            nameCount[realName] = (nameCount[realName] or 0) + 1

            local displayName = realName

            if nameCount[realName] > 1 then

                displayName =
                    realName .. " (" .. tostring(nameCount[realName]) .. ")"

            end

            table.insert(names, displayName)

            drillOptions[displayName] = child

        end

    end

    if #names == 0 then
        return {"等待加载..."}
    end

    return names

end

-- ============================================================
-- 主要功能页 UI
-- ============================================================

MainSec:AddToggle({

    Title = "显示外置UI",

    Default = true,

    Flag = "show_info_gui",

    Callback = function(on)

        if on then
            createInfoGui()
        else
            destroyInfoGui()
        end

    end

})

MainSec:AddToggle({

    Title = "经验值通知",

    Default = true,

    Flag = "xp_notify",

    Callback = function(on)

        xpNotifyEnabled = on

    end

})

MainSec:AddToggle({

    Title = "静音游戏内所有声音",

    Default = false,

    Flag = "mute_all_sound",

    Callback = function(on)

        if on then
            muteAll()
        else
            unmuteAll()
        end

    end

})

-- 旅行商人传送
MainSec:AddButton({

    Title = "传送到旅行商人上方5米",

    Style = "Primary",

    Callback = function()

        local world = workspace:FindFirstChild("World")
        local npcs = world and world:FindFirstChild("NPCs")
        local npc = npcs and npcs:FindFirstChild("Merchant Cart")

        if not npc then

            LiquidGlass:Notify({
                Title = "传送失败",
                Content = "找不到旅行商人",
                Type = "Error"
            })

            return
        end

        askConfirm("旅行商人", function()

            if teleportTo(npc, Vector3.new(0, 5, 0)) then

                LiquidGlass:Notify({
                    Title = "传送",
                    Content = "已传送到旅行商人",
                    Type = "Success"
                })

            end

        end)

    end

})

-- 一键售卖
MainSec:AddButton({

    Title = "一键售卖所有物品",

    Style = "Primary",

    Callback = function()

        local success, err = pcall(function()

            ReplicatedStorage.DialogueRemotes.SellAllItems:FireServer(
                workspace.World.NPCs.Rocky
            )

        end)

        if not success then

            warn("[dig] 售卖失败: " .. tostring(err))

            LiquidGlass:Notify({
                Title = "售卖失败",
                Content = tostring(err),
                Type = "Error"
            })

        else

            LiquidGlass:Notify({
                Title = "售卖",
                Content = "已发送售卖请求",
                Type = "Success"
            })

        end

    end

})

-- ============================================================
-- 钻头传送 UI
-- ============================================================

drillDropdown = DrillSec:AddDropdown({

    Title = "选择钻头",

    Options = scanDrills(),

    Flag = "drill_choice",

    Callback = function(option)

        drillSelectedName = option

    end

})

-- 刷新钻头
DrillSec:AddButton({

    Title = "刷新钻头列表",

    Callback = function()

        local newNames = scanDrills()

        local updated = false

        if drillDropdown then

            if type(drillDropdown.SetOptions) == "function" then

                drillDropdown:SetOptions(newNames)
                updated = true

            elseif type(drillDropdown.Refresh) == "function" then

                drillDropdown:Refresh(newNames)
                updated = true

            elseif type(drillDropdown.Update) == "function" then

                drillDropdown:Update(newNames)
                updated = true

            end

        end

        LiquidGlass:Notify({

            Title = "钻头列表",

            Content = updated
                and "钻头列表已刷新"
                or "已扫描，请重新打开菜单查看",

            Type = "Info"

        })

    end

})

-- 传送到钻头
DrillSec:AddButton({

    Title = "传送到钻头附近",

    Style = "Primary",

    Callback = function()

        if not drillSelectedName
            or not drillOptions[drillSelectedName] then

            return LiquidGlass:Notify({

                Title = "传送",
                Content = "请先选择钻头",
                Type = "Warning"

            })

        end

        local drill = drillOptions[drillSelectedName]

        if not drill or not drill.Parent then

            return LiquidGlass:Notify({

                Title = "传送",
                Content = "钻头已消失，请刷新列表",
                Type = "Error"

            })

        end

        askConfirm(drillSelectedName, function()

            if teleportTo(drill, Vector3.new(6, 3, 0)) then

                LiquidGlass:Notify({

                    Title = "传送",
                    Content = "已传送至：" .. drillSelectedName,
                    Type = "Success"

                })

            end

        end)

    end

})

-- ============================================================
-- 挖矿页 UI
-- ============================================================

-- 自动挖掘
Dig:AddToggle({

    Title = "自动挖掘",

    Flag = "auto_dig",

    Callback = function(on)

        autoHitEnabled = on

        if on then

            if not miningConnection then

                miningConnection = RunService.Heartbeat:Connect(
                    autoStrongHit
                )

            end

        else

            if miningConnection then

                miningConnection:Disconnect()
                miningConnection = nil

            end

        end

    end

})

-- 自动打 Boss
Dig:AddToggle({

    Title = "自动打Boss",

    Flag = "auto_boss",

    Callback = function(on)

        autoBossEnabled = on

        if on then
            task.spawn(autoBossLoop)
        end

    end

})

Dig:AddInput({

    Title = "打Boss间隔(秒)",

    Default = "0.8",

    Callback = function(text)

        local num = tonumber(text)

        if num and num > 0 then
            bossInterval = num
        end

    end

})

-- 秒挖循环
Dig:AddToggle({

    Title = "秒挖循环（可调延迟）",

    Flag = "instant_dig",

    Callback = function(on)

        instantDigEnabled = on

        if on then
            task.spawn(instantDigLoop)
        end

    end

})

Dig:AddInput({

    Title = "挖掘延迟(秒)",

    Default = "0.8",

    Callback = function(text)

        local num = tonumber(text)

        if num and num > 0 then
            digDelay = num
        end

    end

})

Dig:AddButton({

    Title = "手动秒挖一次",

    Style = "Primary",

    Callback = function()

        fireDigOnce()

    end

})

Dig:AddButton({

    Title = "手动打Boss一次",

    Callback = function()

        local success, err = pcall(function()

            ReplicatedStorage.Remotes.Dig_Boss_OnHit:FireServer(true)

        end)

        if not success then
            warn("[dig] 手动打Boss失败: " .. tostring(err))
        end

    end

})

-- ============================================================
-- 自动化页 UI
-- ============================================================

Auto:AddDropdown({

    Title = "选择铲子",

    Options = {
        "星火铲",
        "新月铲"
    },

    Default = "星火铲",

    Flag = "equip_tool_choice",

    Callback = function(option)

        equipSelectedDisplay = option

    end

})

Auto:AddToggle({

    Title = "自动装备所选铲子",

    Flag = "auto_equip_shovel",

    Callback = function(on)

        autoEquipEnabled = on

        if on then
            task.spawn(autoEquipLoop)
        end

    end

})

Auto:AddInput({

    Title = "装备间隔(秒)",

    Default = "0.01",

    Callback = function(text)

        local num = tonumber(text)

        if num and num > 0 then
            equipInterval = num
        end

    end

})

Auto:AddToggle({

    Title = "自动点击屏幕",

    Flag = "auto_click_screen",

    Callback = function(on)

        autoClickEnabled = on

        if on then
            task.spawn(autoClickLoop)
        end

    end

})

Auto:AddInput({

    Title = "点击间隔(秒)",

    Default = "4",

    Callback = function(text)

        local num = tonumber(text)

        if num and num > 0 then
            clickInterval = num
        end

    end

})

-- ============================================================
-- 设置与加载通知
-- ============================================================

Window:AddSettingsTab()

LiquidGlass:Notify({

    Title = "琳琅天上",

    Content = "完整整合版加载完成",

    Type = "Success",

})
