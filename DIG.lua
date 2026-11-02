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
local bossInterval = 0.1

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
local digDelay = 0.1
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
-- 主要功能页控件
-- ============================================================
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
    Default = "0.1",
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
    Default = "0.1",
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
