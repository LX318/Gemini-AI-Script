local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

local FolderName = "MC_Waypoints_Final"
local FileName = FolderName .. "/Waypoints_" .. tostring(PlaceId) .. ".json"
local WaypointsData = {}

local function SaveWaypoints()
    if isfile and isfolder and writefile then
        if not isfolder(FolderName) then pcall(function() makefolder(FolderName) end) end
        local success, encoded = pcall(function() return HttpService:JSONEncode(WaypointsData) end)
        if success then pcall(function() writefile(FileName, encoded) end) end
    end
end

local function LoadWaypoints()
    if isfile and isfile(FileName) then
        local success, content = pcall(function() return readfile(FileName) end)
        if success and content then
            local decSuccess, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decSuccess and type(decoded) == "table" then WaypointsData = decoded end
        end
    end
end

local function TeleportTo(coords)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(coords.X, coords.Y + 3, coords.Z)
    end
end

local MC_FONT = Enum.Font.GothamBlack
local THEMES = {
    GrayBtn = {
        Main = Color3.fromRGB(72, 73, 78),
        High = Color3.fromRGB(95, 96, 101),
        Shadow = Color3.fromRGB(45, 45, 48),
        Outer = Color3.fromRGB(28, 28, 31)
    },
    GreenBtn = {
        Main = Color3.fromRGB(52, 114, 33),
        High = Color3.fromRGB(86, 173, 57),
        Shadow = Color3.fromRGB(38, 79, 24),
        Outer = Color3.fromRGB(24, 44, 13)
    }
}

local function createThickButton(parent, text, size, pos, theme)
    local Container = Instance.new("Frame")
    Container.Size = size
    Container.Position = pos
    Container.BackgroundTransparency = 1
    Container.Parent = parent

    local BaseShadow = Instance.new("Frame")
    BaseShadow.Size = UDim2.new(1, 0, 1, 0)
    BaseShadow.BackgroundColor3 = theme.Outer
    BaseShadow.BorderSizePixel = 0
    BaseShadow.Parent = Container

    local VisualGroup = Instance.new("Frame")
    VisualGroup.Size = UDim2.new(1, -2, 1, -4)
    VisualGroup.Position = UDim2.new(0, 1, 0, 1)
    VisualGroup.BackgroundColor3 = theme.Main
    VisualGroup.BorderSizePixel = 0
    VisualGroup.Parent = BaseShadow

    local Highlight = Instance.new("Frame")
    Highlight.Size = UDim2.new(1, -2, 1, -2)
    Highlight.BackgroundColor3 = theme.High
    Highlight.BorderSizePixel = 0
    Highlight.Parent = VisualGroup

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2.new(1, -2, 1, -2)
    Fill.Position = UDim2.new(0, 2, 0, 2)
    Fill.BackgroundColor3 = theme.Main
    Fill.BorderSizePixel = 0
    Fill.Parent = VisualGroup

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.BackgroundTransparency = 1
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.Text = text
    TextLabel.Font = MC_FONT
    TextLabel.TextSize = 13
    TextLabel.ZIndex = 5
    TextLabel.Parent = VisualGroup

    local Hitbox = Instance.new("TextButton")
    Hitbox.Size = UDim2.new(1, 0, 1, 0)
    Hitbox.BackgroundTransparency = 1
    Hitbox.Text = ""
    Hitbox.ZIndex = 10
    Hitbox.Parent = Container

    Hitbox.MouseButton1Down:Connect(function() VisualGroup.Position = UDim2.new(0, 1, 0, 3) end)
    Hitbox.MouseButton1Up:Connect(function() VisualGroup.Position = UDim2.new(0, 1, 0, 1) end)
    Hitbox.MouseLeave:Connect(function() VisualGroup.Position = UDim2.new(0, 1, 0, 1) end)

    return Container, Hitbox, TextLabel
end

local function InitUI()
    local existing = CoreGui:FindFirstChild("MC_Waypoints_System")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MC_Waypoints_System"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui

    local ToggleContainer, ToggleHitbox, ToggleText = createThickButton(ScreenGui, "锚点\n菜单", UDim2.new(0, 56, 0, 56), UDim2.new(1, -70, 0.5, -28), THEMES.GrayBtn)

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 320, 0, 450) 
    MainFrame.Position = UDim2.new(0.5, -160, 0.5, -225)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.BackgroundTransparency = 0.3
    MainFrame.BorderSizePixel = 0
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Thickness = 2
    MainStroke.Color = Color3.fromRGB(60, 60, 60)
    MainStroke.Parent = MainFrame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.BackgroundTransparency = 1
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Text = "MINE-WAYPOINTS"
    Title.Font = MC_FONT
    Title.TextSize = 16
    Title.Parent = MainFrame

    local InputBg = Instance.new("Frame")
    InputBg.Size = UDim2.new(1, -30, 0, 35)
    InputBg.Position = UDim2.new(0, 15, 0, 50)
    InputBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    InputBg.BackgroundTransparency = 0.5
    InputBg.BorderSizePixel = 1
    InputBg.BorderColor3 = Color3.fromRGB(80, 80, 80)
    InputBg.Parent = MainFrame

    local NameInput = Instance.new("TextBox")
    NameInput.Size = UDim2.new(1, -10, 1, 0)
    NameInput.Position = UDim2.new(0, 5, 0, 0)
    NameInput.BackgroundTransparency = 1
    NameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameInput.PlaceholderText = "输入位置名称..."
    NameInput.Font = MC_FONT
    NameInput.TextSize = 14
    NameInput.TextXAlignment = Enum.TextXAlignment.Left
    NameInput.Parent = InputBg

    local SaveContainer, SaveHitbox = createThickButton(MainFrame, "确 定 建 立 锚 点", UDim2.new(1, -30, 0, 35), UDim2.new(0, 15, 0, 95), THEMES.GreenBtn)

    local ScrollList = Instance.new("ScrollingFrame")
    ScrollList.Size = UDim2.new(1, -30, 1, -160)
    ScrollList.Position = UDim2.new(0, 15, 0, 145)
    ScrollList.BackgroundTransparency = 1
    ScrollList.ScrollBarThickness = 3
    ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollList.Parent = MainFrame

    local ListLayout = Instance.new("UIListLayout", ScrollList)
    ListLayout.Padding = UDim.new(0, 8)

    local function Refresh()
        for _, v in pairs(ScrollList:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
        for name, pos in pairs(WaypointsData) do
            local item = Instance.new("Frame")
            item.Size = UDim2.new(1, -5, 0, 40)
            item.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            item.BackgroundTransparency = 0.9
            item.BorderSizePixel = 0
            item.Parent = ScrollList

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0.5, 0, 1, 0)
            label.Position = UDim2.new(0, 10, 0, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Text = name
            label.Font = MC_FONT
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = item

            local TpC, TpH = createThickButton(item, "传 送", UDim2.new(0, 50, 0, 30), UDim2.new(1, -110, 0.5, -15), THEMES.GreenBtn)
            local DelC, DelH = createThickButton(item, "删 除", UDim2.new(0, 50, 0, 30), UDim2.new(1, -55, 0.5, -15), THEMES.GrayBtn)

            TpH.MouseButton1Click:Connect(function() TeleportTo(pos) end)
            DelH.MouseButton1Click:Connect(function() WaypointsData[name] = nil SaveWaypoints() Refresh() end)
        end
        ScrollList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y)
    end

    ToggleHitbox.MouseButton1Click:Connect(function()
        MainFrame.Visible = not MainFrame.Visible
        ToggleText.Text = MainFrame.Visible and "关 闭" or "锚 点\n菜 单"
    end)

    SaveHitbox.MouseButton1Click:Connect(function()
        local name = NameInput.Text
        if name ~= "" and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local p = LocalPlayer.Character.HumanoidRootPart.Position
            WaypointsData[name] = {X = math.floor(p.X), Y = math.floor(p.Y), Z = math.floor(p.Z)}
            NameInput.Text = ""
            SaveWaypoints()
            Refresh()
        end
    end)

    local dragging, dragInput, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true dragStart = input.Position startPos = MainFrame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    MainFrame.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    LoadWaypoints()
    Refresh()
end

task.spawn(InitUI)
