local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local WindUI = {}
WindUI.__index = WindUI

local Theme = {
    Background = Color3.fromHex("#101010"),
    ElementBg = Color3.fromHex("#2A2A2C"),
    Accent = Color3.fromHex("#0091FF"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#7a7a7a"),
    Outline = Color3.fromHex("#FFFFFF"),
    OutlineTrans = 0.92,
    Radius = UDim.new(0, 6),
    Font = Enum.Font.GothamMedium
}

local ANIM_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local GlobalState = {
    Windows = {},
    ActiveToggles = {},
    ListVisible = true,
    UIHidden = false,
    WinOffset = 25
}

local ParentContainer = pcall(function() return gethui() end) and gethui() or LocalPlayer:WaitForChild("PlayerGui")
local UI_ID = "Buleliner_UI"
if ParentContainer:FindFirstChild(UI_ID) then ParentContainer[UI_ID]:Destroy() end

local ScreenGui = Instance.new("ScreenGui", ParentContainer)
ScreenGui.Name = UI_ID
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local WindowsFolder = Instance.new("Folder", ScreenGui)
WindowsFolder.Name = "Windows"

local ArrayList = Instance.new("Frame", ScreenGui)
ArrayList.Size = UDim2.new(0, 200, 1, -50)
ArrayList.Position = UDim2.new(1, -15, 0, 45)
ArrayList.AnchorPoint = Vector2.new(1, 0)
ArrayList.BackgroundTransparency = 1

local ListLayout = Instance.new("UIListLayout", ArrayList)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ListLayout.Padding = UDim.new(0, 4)

local function RefreshList()
    for _, c in ipairs(ArrayList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
    if not GlobalState.ListVisible then return end
    
    local sorted = {}
    for name in pairs(GlobalState.ActiveToggles) do table.insert(sorted, name) end
    table.sort(sorted, function(a, b)
        return TextService:GetTextSize(a, 12, Theme.Font, Vector2.new(999, 999)).X > TextService:GetTextSize(b, 12, Theme.Font, Vector2.new(999, 999)).X
    end)

    for i, name in ipairs(sorted) do
        local Item = Instance.new("TextLabel", ArrayList)
        Item.BackgroundTransparency = 1; Item.Text = name; Item.Font = Enum.Font.GothamBold; Item.TextColor3 = Theme.Accent; Item.TextSize = 11; Item.Size = UDim2.new(1, 0, 0, 14); Item.TextXAlignment = Enum.TextXAlignment.Right; Item.LayoutOrder = i
        local Stroke = Instance.new("UIStroke", Item); Stroke.Color = Color3.new(0,0,0); Stroke.Transparency = 0.4; Stroke.Thickness = 1
    end
end

local TopControls = Instance.new("Frame", ScreenGui)
TopControls.Size = UDim2.new(0, 100, 0, 20); TopControls.Position = UDim2.new(1, -15, 0, 15); TopControls.AnchorPoint = Vector2.new(1, 0); TopControls.BackgroundTransparency = 1
local ControlLayout = Instance.new("UIListLayout", TopControls); ControlLayout.FillDirection = Enum.FillDirection.Horizontal; ControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; ControlLayout.Padding = UDim.new(0, 6)

local function CreateMiniBtn(text, order, callback)
    local Btn = Instance.new("TextButton", TopControls); Btn.Size = UDim2.new(0, 20, 0, 20); Btn.BackgroundColor3 = Theme.ElementBg; Btn.Text = text; Btn.Font = Enum.Font.GothamBold; Btn.TextColor3 = Theme.Text; Btn.TextSize = 12; Btn.LayoutOrder = order; Btn.AutoButtonColor = false
    Instance.new("UICorner", Btn).CornerRadius = Theme.Radius; local Stroke = Instance.new("UIStroke", Btn); Stroke.Color = Theme.Outline; Stroke.Transparency = Theme.OutlineTrans; Stroke.Thickness = 1
    Btn.MouseEnter:Connect(function() TweenService:Create(Btn, ANIM_FAST, {BackgroundColor3 = Color3.fromRGB(60, 60, 62)}):Play() end)
    Btn.MouseLeave:Connect(function() TweenService:Create(Btn, ANIM_FAST, {BackgroundColor3 = Theme.ElementBg}):Play() end)
    Btn.MouseButton1Click:Connect(callback)
end

CreateMiniBtn("≡", 1, function() GlobalState.ListVisible = not GlobalState.ListVisible; RefreshList() end)
CreateMiniBtn("↺", 2, function() for _, w in ipairs(GlobalState.Windows) do TweenService:Create(w.Frame, ANIM_FAST, {Position = w.DefaultPos}):Play() end end)
CreateMiniBtn("−", 3, function() GlobalState.UIHidden = not GlobalState.UIHidden; for _, w in ipairs(GlobalState.Windows) do w.Frame.Visible = not GlobalState.UIHidden end end)

function WindUI:CreateWindow(config)
    local Window = {}
    local Title = config.Title or "窗口"
    
    local MainFrame = Instance.new("Frame", WindowsFolder)
    MainFrame.Size = UDim2.new(0, 200, 0, 30); MainFrame.BackgroundColor3 = Theme.Background; MainFrame.BorderSizePixel = 0
    
    local InitPos = UDim2.new(0, GlobalState.WinOffset, 0, 25)
    MainFrame.Position = InitPos
    GlobalState.WinOffset = GlobalState.WinOffset + 215
    table.insert(GlobalState.Windows, {Frame = MainFrame, DefaultPos = InitPos})
    
    Instance.new("UICorner", MainFrame).CornerRadius = Theme.Radius
    local MainStroke = Instance.new("UIStroke", MainFrame); MainStroke.Color = Theme.Outline; MainStroke.Transparency = Theme.OutlineTrans; MainStroke.Thickness = 1

    local Header = Instance.new("TextButton", MainFrame)
    Header.Size = UDim2.new(1, 0, 0, 30); Header.BackgroundTransparency = 1; Header.Text = ""
    local TitleLabel = Instance.new("TextLabel", Header); TitleLabel.Size = UDim2.new(1, -20, 1, 0); TitleLabel.Position = UDim2.new(0, 10, 0, 0); TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = Title; TitleLabel.Font = Enum.Font.GothamBold; TitleLabel.TextColor3 = Theme.Text; TitleLabel.TextSize = 12; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local Content = Instance.new("Frame", MainFrame)
    Content.Size = UDim2.new(1, 0, 0, 0); Content.Position = UDim2.new(0, 0, 0, 30); Content.BackgroundTransparency = 1; Content.ClipsDescendants = true
    local Layout = Instance.new("UIListLayout", Content); Layout.Padding = UDim.new(0, 5)
    local Padding = Instance.new("UIPadding", Content); Padding.PaddingTop = UDim.new(0, 4); Padding.PaddingBottom = UDim.new(0, 8); Padding.PaddingLeft = UDim.new(0, 8); Padding.PaddingRight = UDim.new(0, 8)

    local IsExpanded = true
    local function UpdateHeight()
        local h = IsExpanded and (Layout.AbsoluteContentSize.Y + 12) or 0
        TweenService:Create(Content, ANIM_FAST, {Size = UDim2.new(1, 0, 0, h)}):Play()
        TweenService:Create(MainFrame, ANIM_FAST, {Size = UDim2.new(0, 200, 0, h + 30)}):Play()
    end
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateHeight)
    Header.MouseButton1Click:Connect(function() IsExpanded = not IsExpanded; UpdateHeight() end)

    local Dragging, DragStart, StartPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Dragging = true; DragStart = input.Position; StartPos = MainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + (input.Position.X - DragStart.X), StartPos.Y.Scale, StartPos.Y.Offset + (input.Position.Y - DragStart.Y))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = false end
    end)

    function Window:CreateToggle(cfg)
        local Title = cfg.Title or "开关"
        local Default = cfg.Default or false
        local Callback = cfg.Callback or function() end

        local Container = Instance.new("TextButton", Content); Container.Size = UDim2.new(1, 0, 0, 28); Container.BackgroundColor3 = Theme.ElementBg; Container.AutoButtonColor = false; Container.Text = ""; Instance.new("UICorner", Container).CornerRadius = Theme.Radius
        local Stroke = Instance.new("UIStroke", Container); Stroke.Color = Theme.Outline; Stroke.Transparency = Theme.OutlineTrans; Stroke.Thickness = 1
        Instance.new("TextLabel", Container).Size = UDim2.new(0.6, 0, 1, 0); Container.TextLabel.Position = UDim2.new(0, 8, 0, 0); Container.TextLabel.BackgroundTransparency = 1; Container.TextLabel.Text = Title; Container.TextLabel.Font = Theme.Font; Container.TextLabel.TextColor3 = Theme.Text; Container.TextLabel.TextSize = 11; Container.TextLabel.TextXAlignment = Enum.TextXAlignment.Left

        local BindBtn = Instance.new("TextButton", Container); BindBtn.Size = UDim2.new(0, 36, 0, 16); BindBtn.Position = UDim2.new(1, -76, 0.5, -8); BindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 32); BindBtn.Text = "[无]"; BindBtn.Font = Theme.Font; BindBtn.TextColor3 = Theme.Placeholder; BindBtn.TextSize = 9; BindBtn.AutoButtonColor = false; Instance.new("UICorner", BindBtn).CornerRadius = UDim.new(0, 4)
        local Track = Instance.new("Frame", Container); Track.Size = UDim2.fromOffset(26, 14); Track.Position = UDim2.new(1, -34, 0.5, -7); Track.BackgroundColor3 = Default and Theme.Accent or Color3.fromHex("#3E3E40"); Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
        local Knob = Instance.new("Frame", Track); Knob.Size = UDim2.fromOffset(10, 10); Knob.Position = Default and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5); Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

        local State = Default; local CurrentBind = nil; local IsBinding = false
        local function FireToggle(forceState)
            if forceState ~= nil then State = forceState else State = not State end
            TweenService:Create(Knob, ANIM_FAST, {Position = State and UDim2.new(1, -12, 0.5, -5) or UDim2.new(0, 2, 0.5, -5)}):Play()
            TweenService:Create(Track, ANIM_FAST, {BackgroundColor3 = State and Theme.Accent or Color3.fromHex("#3E3E40")}):Play()
            if State then GlobalState.ActiveToggles[Title] = true else GlobalState.ActiveToggles[Title] = nil end
            RefreshList(); Callback(State)
        end

        if State then GlobalState.ActiveToggles[Title] = true; RefreshList() end
        Container.MouseButton1Click:Connect(function() FireToggle() end)
        BindBtn.MouseButton1Click:Connect(function() IsBinding = true; BindBtn.Text = "..."; BindBtn.TextColor3 = Theme.Accent end)

        UserInputService.InputBegan:Connect(function(input)
            if IsBinding and input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then CurrentBind = nil; BindBtn.Text = "[无]" else CurrentBind = input.KeyCode; BindBtn.Text = "[" .. input.KeyCode.Name .. "]" end
                BindBtn.TextColor3 = Theme.Placeholder; IsBinding = false
            elseif not IsBinding and CurrentBind and input.KeyCode == CurrentBind and not UserInputService:GetFocusedTextBox() then FireToggle() end
        end)
    end

    function Window:CreateSlider(cfg)
        local Title = cfg.Title or "滑块"
        local Min = cfg.Min or 0
        local Max = cfg.Max or 100
        local Default = cfg.Default or Min
        local Callback = cfg.Callback or function() end

        local Container = Instance.new("Frame", Content); Container.Size = UDim2.new(1, 0, 0, 42); Container.BackgroundColor3 = Theme.ElementBg; Instance.new("UICorner", Container).CornerRadius = Theme.Radius; local Stroke = Instance.new("UIStroke", Container); Stroke.Color = Theme.Outline; Stroke.Transparency = Theme.OutlineTrans; Stroke.Thickness = 1
        Instance.new("TextLabel", Container).Size = UDim2.new(0.5, 0, 0, 16); Container.TextLabel.Position = UDim2.new(0, 8, 0, 6); Container.TextLabel.BackgroundTransparency = 1; Container.TextLabel.Text = Title; Container.TextLabel.Font = Theme.Font; Container.TextLabel.TextColor3 = Theme.Text; Container.TextLabel.TextSize = 11; Container.TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local ValueBox = Instance.new("TextBox", Container); ValueBox.Size = UDim2.new(0, 50, 0, 16); ValueBox.Position = UDim2.new(1, -58, 0, 6); ValueBox.BackgroundTransparency = 1; ValueBox.Text = tostring(Default); ValueBox.Font = Enum.Font.GothamBold; ValueBox.TextColor3 = Theme.Accent; ValueBox.TextSize = 11; ValueBox.TextXAlignment = Enum.TextXAlignment.Right
        
        local Pad = Instance.new("TextButton", Container); Pad.Size = UDim2.new(1, 0, 0, 20); Pad.Position = UDim2.new(0, 0, 0, 22); Pad.BackgroundTransparency = 1; Pad.Text = ""
        local Track = Instance.new("Frame", Pad); Track.Size = UDim2.new(1, -16, 0, 4); Track.Position = UDim2.new(0, 8, 0.5, -2); Track.BackgroundColor3 = Color3.fromHex("#3E3E40"); Track.BorderSizePixel = 0; Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)
        local Fill = Instance.new("Frame", Track); Fill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0); Fill.BackgroundColor3 = Theme.Accent; Fill.BorderSizePixel = 0; Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)
        local Knob = Instance.new("Frame", Fill); Knob.Size = UDim2.new(0, 10, 0, 10); Knob.AnchorPoint = Vector2.new(0.5, 0.5); Knob.Position = UDim2.new(1, 0, 0.5, 0); Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

        local Dragging = false
        local function UpdateVal(input)
            local pos = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
            local val = math.floor((Min + (Max - Min) * pos) * 10) / 10; if val == math.floor(val) then val = math.floor(val) end
            ValueBox.Text = tostring(val)
            TweenService:Create(Fill, TweenInfo.new(0.08), {Size = UDim2.new(pos, 0, 1, 0)}):Play()
            Callback(val)
        end

        Pad.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = true; UpdateVal(input) end end)
        UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Dragging = false end end)
        UserInputService.InputChanged:Connect(function(input) if Dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then UpdateVal(input) end end)
        ValueBox.FocusLost:Connect(function() local num = tonumber(ValueBox.Text); if num then num = math.clamp(num, Min, Max); ValueBox.Text = tostring(num); TweenService:Create(Fill, ANIM_FAST, {Size = UDim2.new((num - Min) / (Max - Min), 0, 1, 0)}):Play(); Callback(num) else ValueBox.Text = tostring(Default) end end)
    end

    function Window:CreateDropdown(cfg)
        local Title = cfg.Title or "下拉"
        local List = cfg.List or {}
        local Callback = cfg.Callback or function() end
        local HeaderH = 30; local PickerH = 120; local ItemH = 26; local Pad = (PickerH - ItemH) / 2

        local Container = Instance.new("Frame", Content); Container.Size = UDim2.new(1, 0, 0, HeaderH); Container.BackgroundColor3 = Theme.ElementBg; Container.ClipsDescendants = true; Instance.new("UICorner", Container).CornerRadius = Theme.Radius; local Stroke = Instance.new("UIStroke", Container); Stroke.Color = Theme.Outline; Stroke.Transparency = Theme.OutlineTrans; Stroke.Thickness = 1
        local Trigger = Instance.new("TextButton", Container); Trigger.Size = UDim2.new(1, 0, 0, HeaderH); Trigger.BackgroundTransparency = 1; Trigger.Text = ""
        Instance.new("TextLabel", Trigger).Size = UDim2.new(1, -30, 1, 0); Trigger.TextLabel.Position = UDim2.new(0, 8, 0, 0); Trigger.TextLabel.BackgroundTransparency = 1; Trigger.TextLabel.Text = Title .. ": " .. (List[1] or ""); Trigger.TextLabel.Font = Theme.Font; Trigger.TextLabel.TextColor3 = Theme.Text; Trigger.TextLabel.TextSize = 11; Trigger.TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        Instance.new("TextLabel", Trigger).Name = "Icon"; Trigger.Icon.Size = UDim2.new(0, 20, 1, 0); Trigger.Icon.Position = UDim2.new(1, -22, 0, 0); Trigger.Icon.BackgroundTransparency = 1; Trigger.Icon.Text = "▼"; Trigger.Icon.Font = Enum.Font.Gotham; Trigger.Icon.TextColor3 = Theme.Placeholder; Trigger.Icon.TextSize = 10

        local PContainer = Instance.new("Frame", Container); PContainer.Size = UDim2.new(1, 0, 1, -HeaderH); PContainer.Position = UDim2.new(0, 0, 0, HeaderH); PContainer.BackgroundTransparency = 1
        Instance.new("Frame", PContainer).Size = UDim2.new(1, -20, 0, 1); PContainer.Frame.Position = UDim2.new(0, 10, 0, Pad); PContainer.Frame.BackgroundColor3 = Theme.Outline; PContainer.Frame.BackgroundTransparency = 0.85; PContainer.Frame.BorderSizePixel = 0
        Instance.new("Frame", PContainer).Name = "B"; PContainer.B.Size = UDim2.new(1, -20, 0, 1); PContainer.B.Position = UDim2.new(0, 10, 0, Pad + ItemH); PContainer.B.BackgroundColor3 = Theme.Outline; PContainer.B.BackgroundTransparency = 0.85; PContainer.B.BorderSizePixel = 0

        local Scroll = Instance.new("ScrollingFrame", PContainer); Scroll.Size = UDim2.new(1, 0, 1, 0); Scroll.BackgroundTransparency = 1; Scroll.ScrollBarThickness = 0; Scroll.ElasticBehavior = Enum.ElasticBehavior.Always; Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        Instance.new("UIListLayout", Scroll).HorizontalAlignment = Enum.HorizontalAlignment.Center
        Instance.new("UIPadding", Scroll).PaddingTop = UDim.new(0, Pad); Scroll.UIPadding.PaddingBottom = UDim.new(0, Pad)

        local items = {}
        for i, item in ipairs(List) do
            local Btn = Instance.new("TextButton", Scroll); Btn.Name = item; Btn.Size = UDim2.new(1, 0, 0, ItemH); Btn.BackgroundTransparency = 1; Btn.Text = item; Btn.Font = Enum.Font.GothamBold; Btn.TextColor3 = Theme.Text; Btn.TextSize = 10; Btn.TextTransparency = 0.7; Btn.AutoButtonColor = false; Btn.LayoutOrder = i
            table.insert(items, Btn)
            Btn.MouseButton1Click:Connect(function() TweenService:Create(Scroll, TweenInfo.new(0.2), {CanvasPosition = Vector2.new(0, (i - 1) * ItemH)}):Play() end)
        end
        Scroll.CanvasSize = UDim2.new(0, 0, 0, (#items * ItemH) + (Pad * 2))

        local function UpdateVisuals()
            local cy = Scroll.CanvasPosition.Y
            for i, itm in ipairs(items) do
                local dist = math.abs(cy - ((i - 1) * ItemH))
                local ratio = math.clamp(dist / (ItemH * 1.5), 0, 1)
                itm.TextTransparency = 0.05 + (0.8 * ratio); itm.TextSize = 12 - (2 * ratio)
            end
        end

        local snapDb = false
        local function Snap()
            if snapDb then return end; snapDb = true
            local idx = math.clamp(math.floor((Scroll.CanvasPosition.Y / ItemH) + 0.5) + 1, 1, #items)
            TweenService:Create(Scroll, TweenInfo.new(0.15), {CanvasPosition = Vector2.new(0, (idx - 1) * ItemH)}):Play()
            Trigger.TextLabel.Text = Title .. ": " .. items[idx].Name; Callback(items[idx].Name)
            task.wait(0.2); snapDb = false
        end

        Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            UpdateVisuals(); local c = Scroll.CanvasPosition.Y
            task.delay(0.1, function() if Scroll.CanvasPosition.Y == c then Snap() end end)
        end)
        UpdateVisuals()

        local IsOpen = false
        Trigger.MouseButton1Click:Connect(function()
            IsOpen = not IsOpen; Trigger.Icon.Text = IsOpen and "▲" or "▼"
            TweenService:Create(Container, ANIM_FAST, {Size = UDim2.new(1, 0, 0, IsOpen and (HeaderH + PickerH) or HeaderH)}):Play()
            if IsOpen then Snap() end
        end)
    end

    return Window
end

local HitboxSystem = {}

local showHitbox = false
local showSelf = false
local scaleMultiplier = 1.0

local hitboxObjects = {}

local function addHitbox(character, isLocalPlayer)
    if isLocalPlayer and not showSelf then return end
    
    local boxes = {}
    
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "EnlargedHitbox" then
            if not part:FindFirstChild("HitboxVisual") then
                local box = Instance.new("SelectionBox")
                box.Name = "HitboxVisual"
                box.Adornee = part
                
                if part.Name == "HumanoidRootPart" then
                    box.Color3 = Color3.fromRGB(0, 170, 255)
                    box.SurfaceColor3 = Color3.fromRGB(0, 170, 255)
                    box.SurfaceTransparency = 0.7
                    box.LineThickness = 0.05
                else
                    box.Color3 = Color3.fromRGB(255, 50, 50)
                    box.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
                    box.SurfaceTransparency = 0.85
                    box.LineThickness = 0.03
                end
                
                box.Parent = part
                table.insert(boxes, box)
            end
        end
    end
    
    if scaleMultiplier > 1.0 and not isLocalPlayer then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            if character:FindFirstChild("EnlargedHitbox") then
                character.EnlargedHitbox:Destroy()
            end
            
            local enlargedBox = Instance.new("Part")
            enlargedBox.Name = "EnlargedHitbox"
            enlargedBox.Size = rootPart.Size * scaleMultiplier
            enlargedBox.CFrame = rootPart.CFrame
            enlargedBox.Transparency = 0.7
            enlargedBox.Color = Color3.fromRGB(255, 255, 0)
            enlargedBox.Material = Enum.Material.Neon
            enlargedBox.Anchored = false
            enlargedBox.CanCollide = false
            enlargedBox.Parent = character
            
            local highlight = Instance.new("SelectionBox")
            highlight.Adornee = enlargedBox
            highlight.Color3 = Color3.fromRGB(255, 255, 0)
            highlight.SurfaceColor3 = Color3.fromRGB(255, 255, 0)
            highlight.SurfaceTransparency = 0.5
            highlight.LineThickness = 0.03
            highlight.Parent = enlargedBox
            
            local connection
            connection = RunService.Heartbeat:Connect(function()
                if not enlargedBox or not enlargedBox.Parent or not rootPart or not rootPart.Parent then
                    if connection then connection:Disconnect() end
                    return
                end
                enlargedBox.Size = rootPart.Size * scaleMultiplier
                enlargedBox.CFrame = rootPart.CFrame
            end)
            
            table.insert(boxes, enlargedBox)
        end
    end
    
    hitboxObjects[character] = boxes
end

local function removeHitbox(character)
    if hitboxObjects[character] then
        for _, obj in ipairs(hitboxObjects[character]) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
        hitboxObjects[character] = nil
    end
    
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            local box = part:FindFirstChild("HitboxVisual")
            if box then box:Destroy() end
        end
    end
    
    local enlarged = character:FindFirstChild("EnlargedHitbox")
    if enlarged then enlarged:Destroy() end
end

function HitboxSystem.UpdateAll()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            local isLocal = player == LocalPlayer
            if showHitbox then
                addHitbox(player.Character, isLocal)
            else
                removeHitbox(player.Character)
            end
        end
    end
end

function HitboxSystem.SetShowHitbox(state)
    showHitbox = state
    HitboxSystem.UpdateAll()
end

function HitboxSystem.SetShowSelf(state)
    showSelf = state
    HitboxSystem.UpdateAll()
end

function HitboxSystem.SetScale(multiplier)
    scaleMultiplier = multiplier
    HitboxSystem.UpdateAll()
end

local function setupPlayer(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if showHitbox then
            addHitbox(character, player == LocalPlayer)
        end
    end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
    setupPlayer(player)
end

local Library = WindUI

local MainWindow = Library:CreateWindow({
    Title = "Buleliner"
})

MainWindow:CreateToggle({
    Title = "显示碰撞箱",
    Default = false,
    Callback = function(state)
        HitboxSystem.SetShowHitbox(state)
    end
})

MainWindow:CreateToggle({
    Title = "显示自己",
    Default = false,
    Callback = function(state)
        HitboxSystem.SetShowSelf(state)
    end
})

MainWindow:CreateSlider({
    Title = "碰撞箱放大",
    Min = 1,
    Max = 10,
    Default = 1,
    Callback = function(value)
        HitboxSystem.SetScale(value)
    end
})

local SettingsWindow = Library:CreateWindow({
    Title = "设置"
})

SettingsWindow:CreateDropdown({
    Title = "颜色方案",
    List = {"默认", "彩虹", "霓虹", "简约"},
    Callback = function(selected)
        print("选择颜色方案: " .. selected)
    end
})

SettingsWindow:CreateSlider({
    Title = "透明度",
    Min = 0,
    Max = 100,
    Default = 85,
    Callback = function(value)
        print("透明度: " .. value .. "%")
    end
})

print("Buleliner 加载完成！")

return Librarylua
