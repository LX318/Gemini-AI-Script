-- ============================================================
-- dig 挖矿功能（LiquidGlass UI，滑块改输入框）
-- ============================================================

local LiquidGlass = loadstring(game:HttpGet("https://raw.githubusercontent.com/fischgesichtert/LiquidGlass/main/dist/LiquidGlass.lua"))()

local Window = LiquidGlass:CreateWindow({
    Title = "琳琅天上",
    Subtitle = "dig 挖矿模块",
    Icon = "bolt",
})

-- 主要功能页（在上）
local MainTab = Window:AddTab({ Title = "主要功能", Icon = "star" })
local MainSec = MainTab:AddSection("主要功能")

-- 挖矿页（在下）
local DigTab = Window:AddTab({ Title = "挖矿", Icon = "home" })
local Dig = DigTab:AddSection("挖矿")

-- ============================================================
-- 共享变量
-- ============================================================
local autoHitEnabled = false
local miningConnection = nil

local autoBossEnabled = false
local bossInterval = 0.8

-- ============================================================
-- 自动强力挖掘
-- ============================================================
local function autoStrongHit()
    if not autoHitEnabled then return end

    local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local digUI = PlayerGui:FindFirstChild("Dig")
    if not digUI then return end

    local safezone = digUI:FindFirstChild("Safezone")
    local holder = safezone and safezone:FindFirstChild("Holder")
    local playerBar = holder and holder:FindFirstChild("PlayerBar")
    local areaStrong = holder and holder:FindFirstChild("Area_Strong")

    if not playerBar or not areaStrong then return end

    if areaStrong.Visible and areaStrong.AbsoluteSize.X >= 2 then
        local playerPos = playerBar.Position.X.Scale
        local strongLeft = areaStrong.Position.X.Scale
        local strongRight = strongLeft + areaStrong.Size.X.Scale

        if playerPos >= strongLeft and playerPos <= strongRight then
            local VIM = game:GetService("VirtualInputManager")
            VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end
    end
end

-- ============================================================
-- 自动打 boss
-- ============================================================
local function autoBossLoop()
    while autoBossEnabled do
        local success, err = pcall(function()
            game:GetService("ReplicatedStorage").Remotes.Dig_Boss_OnHit:FireServer(true)
        end)
        if not success then
            warn("[dig] 自动打boss失败: " .. tostring(err))
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
local instantDigEnabled = false
local digDelay = 0.8
local digLoopThread = nil

local digArgs = {
    0,
    {
        {
            Color = Color3.new(0.63921570777893, 0.63529413938522, 0.64705884456635),
            Transparency = 1,
            Name = "PositionPart",
            Position = Vector3.new(2080.5751953125, 108.66889190674, -343.86813354492),
            Orientation = Vector3.zero,
            Material = Enum.Material.Plastic,
            Shape = Enum.PartType.Block,
            Size = Vector3.new(0.10000000149012, 0.10000000149012, 0.10000000149012)
        },
        -- 原脚本注释说明：其他 Rock 数据被省略，实际使用需补全
    }
}

local function fireDigOnce()
    local success, err = pcall(function()
        game:GetService("ReplicatedStorage").Remotes.Dig_Finished:FireServer(unpack(digArgs))
    end)
    if not success then
        warn("[dig] FireServer 失败: " .. tostring(err))
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
-- 外置小 GUI：当前时间 + 背包物品数量（极简毛玻璃 / 右上角）
-- ============================================================
local infoGui
local timeLabel
local bagTotalLabel

local TOOL_OFFSET = 8  -- 背包里固定 8 个是工具，不计入物品数

local function formatClock()
    return os.date("%H:%M:%S")
end

-- 统计背包“物品”数量：Tool 总数 - 8，最小为 0
local function countBagItems()
    local player = game:GetService("Players").LocalPlayer
    local backpack = player:FindFirstChild("Backpack")
    local char = player.Character

    local toolCount = 0

    if backpack then
        for _, child in ipairs(backpack:GetChildren()) do
            if child:IsA("Tool") then
                toolCount = toolCount + 1
            end
        end
    end

    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                toolCount = toolCount + 1
            end
        end
    end

    local items = toolCount - TOOL_OFFSET
    if items < 0 then items = 0 end
    return items
end

local function createInfoGui()
    local player = game:GetService("Players").LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local existing = playerGui:FindFirstChild("LingLangInfoGui")
    if existing then existing:Destroy() end

    infoGui = Instance.new("ScreenGui")
    infoGui.Name = "LingLangInfoGui"
    infoGui.ResetOnSpawn = false
    infoGui.IgnoreGuiInset = true
    infoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    infoGui.Parent = playerGui

    -- 极简毛玻璃框：右上角
    local frame = Instance.new("Frame")
    frame.Name = "InfoFrame"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -16, 0, 16)   -- 右上角
    frame.Size = UDim2.new(0, 150, 0, 58)
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

    timeLabel = makeLabel("TimeLabel", Color3.fromRGB(45, 52, 68), 1)
    bagTotalLabel = makeLabel("BagTotalLabel", Color3.fromRGB(35, 100, 190), 2)

    -- 时间刷新
    task.spawn(function()
        local gui = infoGui
        while gui and gui.Parent do
            if timeLabel then
                timeLabel.Text = "时间  " .. formatClock()
            end
            task.wait(1)
        end
    end)

    -- 背包数量刷新
    task.spawn(function()
        local gui = infoGui
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
    end
end

-- 默认创建
createInfoGui()

-- ============================================================
-- 主要功能页控件
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

MainSec:AddButton({
    Title = "传送到旅行商人上方5米",
    Style = "Primary",
    Callback = function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            warn("[dig] 找不到 HumanoidRootPart")
            return
        end

        local world = workspace:FindFirstChild("World")
        local npcs = world and world:FindFirstChild("NPCs")
        local npc = npcs and npcs:FindFirstChild("Merchant Cart")
        if not npc then
            warn("[dig] 找不到 workspace.World.NPCs.Merchant Cart")
            return
        end

        local npcPos
        if npc:IsA("BasePart") then
            npcPos = npc.Position
        else
            local primary = npc.PrimaryPart
            if primary then
                npcPos = primary.Position
            else
                local sum, count = Vector3.zero, 0
                for _, d in ipairs(npc:GetDescendants()) do
                    if d:IsA("BasePart") then
                        sum = sum + d.Position
                        count = count + 1
                    end
                end
                if count == 0 then
                    warn("[dig] NPC 没有可用部件")
                    return
                end
                npcPos = sum / count
            end
        end

        local targetPos = npcPos + Vector3.new(0, 5, 0)
        hrp.CFrame = CFrame.new(targetPos) * (hrp.CFrame - hrp.CFrame.Position)
    end
})

MainSec:AddButton({
    Title = "一键售卖所有物品",
    Style = "Primary",
    Callback = function()
        local success, err = pcall(function()
            game:GetService("ReplicatedStorage").DialogueRemotes.SellAllItems:FireServer(
                workspace.World.NPCs.Rocky
            )
        end)
        if not success then
            warn("[dig] 一键售卖失败: " .. tostring(err))
        end
    end
})

-- ============================================================
-- 挖矿页控件
-- ============================================================
Dig:AddToggle({
    Title = "自动挖掘",
    Flag = "auto_dig",
    Callback = function(on)
        autoHitEnabled = on

        if on then
            if not miningConnection then
                miningConnection = game:GetService("RunService").Heartbeat:Connect(autoStrongHit)
            end
        else
            if miningConnection then
                miningConnection:Disconnect()
                miningConnection = nil
            end
        end
    end
})

Dig:AddToggle({
    Title = "自动打boss",
    Flag = "auto_boss",
    Callback = function(on)
        autoBossEnabled = on

        if on then
            coroutine.wrap(autoBossLoop)()
        end
    end
})

Dig:AddInput({
    Title = "打boss间隔(秒)",
    Default = "0.8",
    Callback = function(text)
        local num = tonumber(text)
        if num and num > 0 then
            bossInterval = num
        end
    end
})

Dig:AddToggle({
    Title = "秒挖循环（可调延迟）",
    Flag = "instant_dig",
    Callback = function(on)
        instantDigEnabled = on

        if on then
            if not digLoopThread or coroutine.status(digLoopThread) == "dead" then
                digLoopThread = coroutine.create(instantDigLoop)
            end
            coroutine.resume(digLoopThread)
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
    Title = "手动打boss一次",
    Callback = function()
        local success, err = pcall(function()
            game:GetService("ReplicatedStorage").Remotes.Dig_Boss_OnHit:FireServer(true)
        end)
        if not success then
            warn("[dig] 手动打boss失败: " .. tostring(err))
        end
    end
})

Window:AddSettingsTab()

LiquidGlass:Notify({
    Title = "琳琅天上",
    Content = "加载完成，按 Right Ctrl 隐藏窗口",
    Type = "Success",
})
