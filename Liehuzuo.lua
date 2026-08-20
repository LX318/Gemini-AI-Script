--[[
    Orion UI - Apple iOS/macOS Modern Pro Edition
    Enhanced: Multi-function AssistiveTouch, Ambient Shadows, Glassmorphism & Spring Animations
--]]

local OrionLib = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local TargetParent = CoreGui:FindFirstChild("RobloxGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- ==================== 1. Apple 主题与动画预设 ====================
OrionLib.Theme = {
    Background = Color3.fromRGB(10, 10, 14),         -- OLED 深邃黑
    Header = Color3.fromRGB(16, 16, 22),             -- 顶部导航栏
    CardBackground = Color3.fromRGB(24, 24, 32),     -- 容器卡片底色
    CardHover = Color3.fromRGB(36, 36, 48),          -- 悬浮底色
    Accent = Color3.fromRGB(10, 132, 255),           -- iOS 系统蓝
    AccentGlow = Color3.fromRGB(0, 198, 255),        -- 蓝色高光
    TextPrimary = Color3.fromRGB(255, 255, 255),     -- 主文本
    TextSecondary = Color3.fromRGB(142, 142, 147),   -- 次要灰色
    ShadowColor = Color3.fromRGB(0, 0, 0)            -- 阴影基色
}

-- 弹性/流体物理动画预设
local SPRING_QUICK  = TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
local SPRING_BOUNCE = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPRING_SMOOTH = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ==================== 2. 高阶视觉渲染工具 ====================
local function CreateTween(instance, properties, tweenInfo)
    local tween = TweenService:Create(instance, tweenInfo or SPRING_QUICK, properties)
    tween:Play()
    return tween
end

-- 制造苹果质感的“立体弥散阴影”与 G2.5 圆角
local function ApplyAppleGlass(frame, radius, shadowIntensity)
    -- 1. 圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 16)
    corner.Parent = frame

    -- 2. 晶莹微光边框 (Rim Light)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.88
    stroke.Thickness = 1.2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 45
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 120, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 30))
    })
    gradient.Parent = stroke

    -- 3. 弥散阴影 (Layered Ambient Drop Shadow)
    if shadowIntensity then
        local shadow = Instance.new("ImageLabel")
        shadow.Name = "AppleAmbientShadow"
        shadow.AnchorPoint = Vector2.new(0.5, 0.5)
        shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
        shadow.Size = UDim2.new(1, 24, 1, 24)
        shadow.BackgroundTransparency = 1
        shadow.Image = "rbxassetid://1316045217" -- 高斯模糊圆角阴影纹理
        shadow.ImageColor3 = OrionLib.Theme.ShadowColor
        shadow.ImageTransparency = shadowIntensity or 0.55
        shadow.ZIndex = frame.ZIndex - 1
        shadow.Parent = frame
    end
end

-- 添加 iOS 点击按压与 Hover 悬浮反馈
local function AddInteractiveEffects(button)
    local uiScale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
    
    button.MouseEnter:Connect(function()
        CreateTween(button, {BackgroundColor3 = OrionLib.Theme.CardHover}, SPRING_QUICK)
        CreateTween(uiScale, {Scale = 1.015}, SPRING_QUICK)
    end)

    button.MouseLeave:Connect(function()
        CreateTween(button, {BackgroundColor3 = OrionLib.Theme.CardBackground}, SPRING_QUICK)
        CreateTween(uiScale, {Scale = 1.0}, SPRING_QUICK)
    end)

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            CreateTween(uiScale, {Scale = 0.95}, SPRING_QUICK)
        end
    end)

    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            CreateTween(uiScale, {Scale = 1.015}, SPRING_BOUNCE)
        end
    end)
end

-- ==================== 3. 极速智能 AssistiveTouch 悬浮球 ====================
local function CreateAssistiveTouch(parentGui, mainFrame)
    local Ball = Instance.new("TextButton")
    Ball.Name = "AssistiveTouchBall"
    Ball.Size = UDim2.new(0, 50, 0, 50)
    Ball.Position = UDim2.new(0.02, 0, 0.4, 0)
    Ball.BackgroundColor3 = OrionLib.Theme.Header
    Ball.Text = ""
    Ball.AutoButtonColor = false
    Ball.ZIndex = 100
    Ball.Parent = parentGui

    ApplyAppleGlass(Ball, 25, 0.4)

    -- 中心 iOS 图标圈圈
    local InnerRing = Instance.new("Frame")
    InnerRing.Size = UDim2.new(0, 26, 0, 26)
    InnerRing.Position = UDim2.new(0.5, -13, 0.5, -13)
    InnerRing.BackgroundColor3 = OrionLib.Theme.Accent
    InnerRing.Parent = Ball
    ApplyAppleGlass(InnerRing, 13, nil)

    -- 展开功能菜单 (Mini Menu Popup)
    local Menu = Instance.new("Frame")
    Menu.Name = "AssistiveMenu"
    Menu.Size = UDim2.new(0, 170, 0, 160)
    Menu.Position = UDim2.new(1, 15, 0, -55)
    Menu.BackgroundColor3 = OrionLib.Theme.Background
    Menu.Visible = false
    Menu.ClipsDescendants = true
    Menu.Parent = Ball
    ApplyAppleGlass(Menu, 16, 0.3)

    local MenuList = Instance.new("UIListLayout")
    MenuList.Padding = UDim.new(0, 6)
    MenuList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    MenuList.VerticalAlignment = Enum.VerticalAlignment.Center
    MenuList.Parent = Menu

    -- 菜单项生成辅助
    local function CreateMenuItem(name, icon, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.88, 0, 0, 32)
        btn.BackgroundColor3 = OrionLib.Theme.CardBackground
        btn.Text = icon .. "  " .. name
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextColor3 = OrionLib.Theme.TextPrimary
        btn.AutoButtonColor = false
        btn.Parent = Menu
        ApplyAppleGlass(btn, 8, nil)
        AddInteractiveEffects(btn)

        btn.MouseButton1Click:Connect(function()
            callback()
            Menu.Visible = false
        end)
    end

    -- 添加多功能快捷按键
    CreateMenuItem("显隐主界面", "⌘", function()
        mainFrame.Visible = not mainFrame.Visible
    end)
    
    CreateMenuItem("重置位置", "⟲", function()
        mainFrame.Position = UDim2.new(0.5, -310, 0.5, -190)
        mainFrame.Visible = true
    end)

    CreateMenuItem("销毁界面", "✕", function()
        parentGui:Destroy()
    end)

    -- FPS 显示标签
    local FpsLabel = Instance.new("TextLabel")
    FpsLabel.Size = UDim2.new(0.88, 0, 0, 20)
    FpsLabel.BackgroundTransparency = 1
    FpsLabel.Font = Enum.Font.GothamBold
    FpsLabel.TextSize = 10
    FpsLabel.TextColor3 = OrionLib.Theme.TextSecondary
    FpsLabel.Text = "FPS: 60 | Ping: 20ms"
    FpsLabel.Parent = Menu

    RunService.RenderStepped:Connect(function(fps)
        FpsLabel.Text = string.format("FPS: %d | Apple Engine", math.floor(1/fps))
    end)

    -- 闲置 3 秒自动半透明逻辑
    local lastActivity = tick()
    local function ResetIdleTimer()
        lastActivity = tick()
        CreateTween(Ball, {BackgroundTransparency = 0}, SPRING_QUICK)
        CreateTween(InnerRing, {BackgroundTransparency = 0}, SPRING_QUICK)
    end

    RunService.Heartbeat:Connect(function()
        if tick() - lastActivity > 3 and not Menu.Visible then
            CreateTween(Ball, {BackgroundTransparency = 0.5}, SPRING_SMOOTH)
            CreateTween(InnerRing, {BackgroundTransparency = 0.5}, SPRING_SMOOTH)
        end
    end)

    -- 磁吸吸附逻辑 (Snap To Edge)
    local dragging, dragStart, startPos
    Ball.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Ball.Position
            ResetIdleTimer()
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Ball.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            -- 计算磁吸向左还是向右边缘
            local viewportSize = workspace.CurrentCamera.ViewportSize
            local currentX = Ball.AbsolutePosition.X
            local targetXScale = (currentX < viewportSize.X / 2) and 0.01 or 0.94

            CreateTween(Ball, {Position = UDim2.new(targetXScale, 0, Ball.Position.Y.Scale, Ball.Position.Y.Offset)}, SPRING_BOUNCE)
        end
    end)

    -- 点击控制球展开/收起菜单
    Ball.MouseButton1Click:Connect(function()
        ResetIdleTimer()
        Menu.Visible = not Menu.Visible
        if Menu.Visible then
            Menu.Size = UDim2.new(0, 170, 0, 0)
            CreateTween(Menu, {Size = UDim2.new(0, 170, 0, 160)}, SPRING_BOUNCE)
        end
    end)
end

-- ==================== 4. 主窗口架构 (Main Window) ====================
function OrionLib:MakeWindow(Settings)
    Settings = Settings or {}
    local TitleText = Settings.Name or "Orion UI Pro"

    local OrionGui = Instance.new("ScreenGui")
    OrionGui.Name = "Orion_AppleProEdition"
    OrionGui.ResetOnSpawn = false
    OrionGui.Parent = TargetParent

    -- 主框架
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 620, 0, 390)
    MainFrame.Position = UDim2.new(0.5, -310, 0.5, -195)
    MainFrame.BackgroundColor3 = OrionLib.Theme.Background
    MainFrame.ClipsDescendants = false
    MainFrame.Parent = OrionGui

    -- 应用高级 G2.5 玻璃质感与立体阴影
    ApplyAppleGlass(MainFrame, 20, 0.65)

    -- 创建悬浮控制球
    CreateAssistiveTouch(OrionGui, MainFrame)

    -- 顶部栏 Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.BackgroundColor3 = OrionLib.Theme.Header
    Header.BackgroundTransparency = 0.3
    Header.Parent = MainFrame
    ApplyAppleGlass(Header, 20, nil)

    -- macOS 风格红黄绿红绿灯红灯/最小化按钮
    local TrafficLights = Instance.new("Frame")
    TrafficLights.Size = UDim2.new(0, 60, 0, 12)
    TrafficLights.Position = UDim2.new(0, 16, 0.5, -6)
    TrafficLights.BackgroundTransparency = 1
    TrafficLights.Parent = Header

    local function CreateDot(color, posX, clickFn)
        local dot = Instance.new("TextButton")
        dot.Size = UDim2.new(0, 12, 0, 12)
        dot.Position = UDim2.new(0, posX, 0, 0)
        dot.BackgroundColor3 = color
        dot.Text = ""
        dot.AutoButtonColor = false
        dot.Parent = TrafficLights
        ApplyAppleGlass(dot, 6, nil)
        if clickFn then dot.MouseButton1Click:Connect(clickFn) end
    end

    CreateDot(Color3.fromRGB(255, 95, 87), 0, function() -- 红灯关闭
        CreateTween(MainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, SPRING_QUICK).Completed:Connect(function()
            OrionGui:Destroy()
        end)
    end)
    CreateDot(Color3.fromRGB(254, 188, 46), 18, function() -- 黄灯最小化
        MainFrame.Visible = false
    end)
    CreateDot(Color3.fromRGB(40, 200, 64), 36, nil) -- 绿灯

    -- 标题
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -120, 1, 0)
    Title.Position = UDim2.new(0, 70, 0, 0)
    Title.Text = TitleText
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 15
    Title.TextColor3 = OrionLib.Theme.TextPrimary
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.BackgroundTransparency = 1
    Title.Parent = Header

    -- 窗口拖拽 (Drag System)
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- 内容主区域 (Sidebar + Tab Display)
    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Size = UDim2.new(0, 150, 1, -50)
    Sidebar.Position = UDim2.new(0, 0, 0, 50)
    Sidebar.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 0
    Sidebar.Parent = MainFrame

    local SidebarList = Instance.new("UIListLayout")
    SidebarList.Padding = UDim.new(0, 6)
    SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    SidebarList.Parent = Sidebar

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.PaddingTop = UDim.new(0, 12)
    SidebarPadding.Parent = Sidebar

    local ContentContainer = Instance.new("Frame")
    ContentContainer.Size = UDim2.new(1, -150, 1, -50)
    ContentContainer.Position = UDim2.new(0, 150, 0, 50)
    ContentContainer.BackgroundTransparency = 1
    ContentContainer.Parent = MainFrame

    local WindowObj = { CurrentTab = nil }

    -- ==================== 5. Tab 选项卡 ====================
    function WindowObj:MakeTab(TabSettings)
        TabSettings = TabSettings or {}
        local TabName = TabSettings.Name or "Tab"

        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(0, 132, 0, 36)
        TabBtn.BackgroundColor3 = OrionLib.Theme.CardBackground
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = TabName
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 13
        TabBtn.TextColor3 = OrionLib.Theme.TextSecondary
        TabBtn.AutoButtonColor = false
        TabBtn.Parent = Sidebar
        ApplyAppleGlass(TabBtn, 10, nil)

        local TabPage = Instance.new("ScrollingFrame")
        TabPage.Size = UDim2.new(1, 0, 1, 0)
        TabPage.BackgroundTransparency = 1
        TabPage.Visible = false
        TabPage.ScrollBarThickness = 2
        TabPage.ScrollBarImageColor3 = OrionLib.Theme.TextSecondary
        TabPage.Parent = ContentContainer

        local PageList = Instance.new("UIListLayout")
        PageList.Padding = UDim.new(0, 10)
        PageList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        PageList.Parent = TabPage

        local PagePadding = Instance.new("UIPadding")
        PagePadding.PaddingTop = UDim.new(0, 14)
        PagePadding.PaddingBottom = UDim.new(0, 14)
        PagePadding.Parent = TabPage

        -- 切换选项卡平滑动画
        TabBtn.MouseButton1Click:Connect(function()
            for _, child in pairs(ContentContainer:GetChildren()) do
                if child:IsA("ScrollingFrame") then child.Visible = false end
            end
            for _, btn in pairs(Sidebar:GetChildren()) do
                if btn:IsA("TextButton") then
                    CreateTween(btn, {BackgroundTransparency = 1, TextColor3 = OrionLib.Theme.TextSecondary}, SPRING_QUICK)
                end
            end
            TabPage.Visible = true
            TabPage.Position = UDim2.new(0, 15, 0, 0)
            CreateTween(TabPage, {Position = UDim2.new(0, 0, 0, 0)}, SPRING_SMOOTH)
            CreateTween(TabBtn, {BackgroundTransparency = 0, TextColor3 = OrionLib.Theme.TextPrimary}, SPRING_QUICK)
        end)

        if not WindowObj.CurrentTab then
            WindowObj.CurrentTab = TabPage
            TabPage.Visible = true
            TabBtn.BackgroundTransparency = 0
            TabBtn.TextColor3 = OrionLib.Theme.TextPrimary
        end

        local TabObj = {}

        -- ==================== 组件 1: 按钮 (Button) ====================
        function TabObj:AddButton(BtnSettings)
            BtnSettings = BtnSettings or {}
            local Text = BtnSettings.Name or "Button"
            local Callback = BtnSettings.Callback or function() end

            local Btn = Instance.new("TextButton")
            Btn.Size = UDim2.new(0.92, 0, 0, 42)
            Btn.BackgroundColor3 = OrionLib.Theme.CardBackground
            Btn.Text = ""
            Btn.AutoButtonColor = false
            Btn.Parent = TabPage
            ApplyAppleGlass(Btn, 12, 0.15)
            AddInteractiveEffects(Btn)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(1, -20, 1, 0)
            Label.Position = UDim2.new(0, 14, 0, 0)
            Label.Text = Text
            Label.Font = Enum.Font.GothamMedium
            Label.TextSize = 13
            Label.TextColor3 = OrionLib.Theme.TextPrimary
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.BackgroundTransparency = 1
            Label.Parent = Btn

            Btn.MouseButton1Click:Connect(Callback)
        end

        -- ==================== 组件 2: 开关 (Toggle) ====================
        function TabObj:AddToggle(ToggleSettings)
            ToggleSettings = ToggleSettings or {}
            local Text = ToggleSettings.Name or "Toggle"
            local Default = ToggleSettings.Default or false
            local Callback = ToggleSettings.Callback or function() end

            local TglBtn = Instance.new("TextButton")
            TglBtn.Size = UDim2.new(0.92, 0, 0, 44)
            TglBtn.BackgroundColor3 = OrionLib.Theme.CardBackground
            TglBtn.Text = ""
            TglBtn.AutoButtonColor = false
            TglBtn.Parent = TabPage
            ApplyAppleGlass(TglBtn, 12, 0.15)
            AddInteractiveEffects(TglBtn)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(0.65, 0, 1, 0)
            Label.Position = UDim2.new(0, 14, 0, 0)
            Label.Text = Text
            Label.Font = Enum.Font.GothamMedium
            Label.TextSize = 13
            Label.TextColor3 = OrionLib.Theme.TextPrimary
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.BackgroundTransparency = 1
            Label.Parent = TglBtn

            -- iOS 软底座开关轨道
            local Track = Instance.new("Frame")
            Track.Size = UDim2.new(0, 44, 0, 24)
            Track.Position = UDim2.new(1, -58, 0.5, -12)
            Track.BackgroundColor3 = Default and OrionLib.Theme.Accent or Color3.fromRGB(50, 50, 60)
            Track.Parent = TglBtn
            ApplyAppleGlass(Track, 12, nil)

            local Knob = Instance.new("Frame")
            Knob.Size = UDim2.new(0, 20, 0, 20)
            Knob.Position = Default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Knob.Parent = Track
            ApplyAppleGlass(Knob, 10, nil)

            local state = Default
            TglBtn.MouseButton1Click:Connect(function()
                state = not state
                local targetPos = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
                local targetColor = state and OrionLib.Theme.Accent or Color3.fromRGB(50, 50, 60)

                CreateTween(Knob, {Position = targetPos}, SPRING_BOUNCE)
                CreateTween(Track, {BackgroundColor3 = targetColor}, SPRING_QUICK)

                Callback(state)
            end)
        end

        -- ==================== 组件 3: 滑动条 (Slider) ====================
        function TabObj:AddSlider(SliderSettings)
            SliderSettings = SliderSettings or {}
            local Text = SliderSettings.Name or "Slider"
            local Min = SliderSettings.Min or 0
            local Max = SliderSettings.Max or 100
            local Default = SliderSettings.Default or Min
            local Callback = SliderSettings.Callback or function() end

            local SldFrame = Instance.new("Frame")
            SldFrame.Size = UDim2.new(0.92, 0, 0, 58)
            SldFrame.BackgroundColor3 = OrionLib.Theme.CardBackground
            SldFrame.Parent = TabPage
            ApplyAppleGlass(SldFrame, 12, 0.15)

            local Label = Instance.new("TextLabel")
            Label.Size = UDim2.new(0.6, 0, 0, 24)
            Label.Position = UDim2.new(0, 14, 0, 8)
            Label.Text = Text
            Label.Font = Enum.Font.GothamMedium
            Label.TextSize = 13
            Label.TextColor3 = OrionLib.Theme.TextPrimary
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.BackgroundTransparency = 1
            Label.Parent = SldFrame

            local ValLabel = Instance.new("TextLabel")
            ValLabel.Size = UDim2.new(0.3, 0, 0, 24)
            ValLabel.Position = UDim2.new(0.7, -14, 0, 8)
            ValLabel.Text = tostring(Default)
            ValLabel.Font = Enum.Font.GothamBold
            ValLabel.TextSize = 13
            ValLabel.TextColor3 = OrionLib.Theme.Accent
            ValLabel.TextXAlignment = Enum.TextXAlignment.Right
            ValLabel.BackgroundTransparency = 1
            ValLabel.Parent = SldFrame

            local Track = Instance.new("Frame")
            Track.Size = UDim2.new(1, -28, 0, 6)
            Track.Position = UDim2.new(0, 14, 1, -18)
            Track.BackgroundColor3 = Color3.fromRGB(48, 48, 58)
            Track.Parent = SldFrame
            ApplyAppleGlass(Track, 3, nil)

            local pct = math.clamp((Default - Min) / (Max - Min), 0, 1)
            local Fill = Instance.new("Frame")
            Fill.Size = UDim2.new(pct, 0, 1, 0)
            Fill.BackgroundColor3 = OrionLib.Theme.Accent
            Fill.Parent = Track
            ApplyAppleGlass(Fill, 3, nil)

            local function UpdateSlider(input)
                local posX = input.Position.X - Track.AbsolutePosition.X
                local percentage = math.clamp(posX / Track.AbsoluteSize.X, 0, 1)
                local value = math.floor(Min + (Max - Min) * percentage)

                CreateTween(Fill, {Size = UDim2.new(percentage, 0, 1, 0)}, SPRING_QUICK)
                ValLabel.Text = tostring(value)
                Callback(value)
            end

            local isDragging = false
            SldFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = true
                    UpdateSlider(input)
                end
            end)

            UserInputService.InputChanged:Connect(function(input)
                if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
 updateSlider(input)
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isDragging = false
                end
            end)
        end

        return TabObj
    end

    return WindowObj
end

return OrionLib
