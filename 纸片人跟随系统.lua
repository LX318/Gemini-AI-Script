local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local secureParent = pcall(function() return CoreGui end) and CoreGui or LocalPlayer:WaitForChild("PlayerGui")

if getgenv()._CleanHoloLib then getgenv()._CleanHoloLib() end

local HoloLib = {}
local UI_Instances = {}

local AppleTheme = {
    GlassBG = Color3.fromRGB(25, 25, 28),
    GlassTransparency = 0.35,
    Stroke = Color3.fromRGB(255, 255, 255),
    StrokeTransparency = 0.88,
    Accent = Color3.fromRGB(10, 132, 255),
    ComponentBG = Color3.fromRGB(45, 45, 50),
    TextPrimary = Color3.fromRGB(245, 245, 245),
    TextSecondary = Color3.fromRGB(150, 150, 155),
    Corner = UDim.new(0, 16)
}

local function ParseImageAsset(input)
    if tonumber(input) then return "rbxassetid://" .. input end
    if string.match(input, "^http") then
        local getasset = getcustomasset or getsynasset
        if getasset and writefile then
            local success, result = pcall(function()
                local req = (syn and syn.request) or (http and http.request) or http_request or request
                local imgData = req({Url = input, Method = "GET"}).Body
                local fileName = "HoloImage_" .. tostring(math.random(1000, 9999)) .. ".png"
                writefile(fileName, imgData)
                return getasset(fileName)
            end)
            if success then return result else warn("Image DL Failed") return "" end
        end
    end
    return input
end

local function CreateSpatialPanel(title, initialOffset, isMain)
    local isVisible = isMain 
    local isPinned = false
    local pinnedPosition = Vector3.new()
    local currentHoloOffset = initialOffset
    
    local PanelPart = Instance.new("Part")
    PanelPart.Size = Vector3.new(3.2, 2.8, 0.01)
    PanelPart.Anchored = true
    PanelPart.CanCollide = false
    PanelPart.Transparency = 1 
    PanelPart.Parent = workspace
    table.insert(UI_Instances, PanelPart)

    local SurfaceUI = Instance.new("SurfaceGui")
    SurfaceUI.Adornee = PanelPart
    SurfaceUI.Face = Enum.NormalId.Back 
    SurfaceUI.AlwaysOnTop = true 
    SurfaceUI.LightInfluence = 0 
    SurfaceUI.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud 
    SurfaceUI.PixelsPerStud = 100 
    SurfaceUI.Enabled = isVisible
    SurfaceUI.Parent = secureParent
    table.insert(UI_Instances, SurfaceUI)

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(1, 0, 1, 0)
    MainFrame.BackgroundColor3 = AppleTheme.GlassBG
    MainFrame.BackgroundTransparency = AppleTheme.GlassTransparency
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = SurfaceUI
    Instance.new("UICorner", MainFrame).CornerRadius = AppleTheme.Corner
    local uiStroke = Instance.new("UIStroke", MainFrame)
    uiStroke.Color = AppleTheme.Stroke
    uiStroke.Transparency = AppleTheme.StrokeTransparency
    uiStroke.Thickness = 1.5

    local TopBar = Instance.new("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundTransparency = 1
    TopBar.Parent = MainFrame

    local DragBar = Instance.new("TextButton")
    DragBar.Size = UDim2.new(1, -50, 1, 0)
    DragBar.BackgroundTransparency = 1
    DragBar.Text = "  " .. title
    DragBar.TextColor3 = AppleTheme.TextPrimary
    DragBar.Font = Enum.Font.GothamBold
    DragBar.TextSize = 16
    DragBar.TextXAlignment = Enum.TextXAlignment.Left
    DragBar.Parent = TopBar

    local PinBtn = Instance.new("TextButton")
    PinBtn.Size = UDim2.new(0, 30, 0, 30)
    PinBtn.Position = UDim2.new(1, -40, 0, 5)
    PinBtn.BackgroundColor3 = AppleTheme.ComponentBG
    PinBtn.BackgroundTransparency = 0.5
    PinBtn.Text = "📍"
    PinBtn.TextSize = 16
    PinBtn.Parent = TopBar
    Instance.new("UICorner", PinBtn).CornerRadius = UDim.new(1, 0)

    PinBtn.MouseButton1Click:Connect(function()
        isPinned = not isPinned
        if isPinned then
            pinnedPosition = PanelPart.Position
            TweenService:Create(PinBtn, TweenInfo.new(0.3), {BackgroundColor3 = AppleTheme.Accent, BackgroundTransparency = 0}):Play()
            PinBtn.Text = "📌"
        else
            TweenService:Create(PinBtn, TweenInfo.new(0.3), {BackgroundColor3 = AppleTheme.ComponentBG, BackgroundTransparency = 0.5}):Play()
            PinBtn.Text = "📍"
        end
    end)

    local isDraggingHolo, initTouch, initOffset = false, Vector2.new(), CFrame.new()
    DragBar.InputBegan:Connect(function(input)
        if not isPinned and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isDraggingHolo = true; initTouch = input.Position; initOffset = currentHoloOffset
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDraggingHolo and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - initTouch
            currentHoloOffset = CFrame.new(
                math.clamp(initOffset.X - (delta.X * 0.005), -6, 6),
                math.clamp(initOffset.Y - (delta.Y * 0.005), -3, 4),
                initOffset.Z
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingHolo = false end
    end)

    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -30, 1, -55)
    ScrollFrame.Position = UDim2.new(0, 15, 0, 40)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.ScrollBarThickness = 3
    ScrollFrame.ScrollBarImageColor3 = AppleTheme.TextSecondary
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.Parent = MainFrame

    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Padding = UDim.new(0, 12)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollFrame

    UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local contentHeight = UIListLayout.AbsoluteContentSize.Y
        local totalPixelsY = contentHeight + 60
        totalPixelsY = math.clamp(totalPixelsY, 280, 650) 
        TweenService:Create(PanelPart, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(3.2, totalPixelsY / 100, 0.01)
        }):Play()
    end)

    local followConn = RunService.RenderStepped:Connect(function(dt)
        if not isVisible then 
            PanelPart.CFrame = CFrame.new(0, -9999, 0)
            return 
        end
        if not isPinned then
            PanelPart.CFrame = PanelPart.CFrame:Lerp(Camera.CFrame * currentHoloOffset, dt * 15)
        else
            local targetRot = CFrame.lookAt(pinnedPosition, Camera.CFrame.Position) * CFrame.Angles(0, math.pi, 0)
            PanelPart.CFrame = PanelPart.CFrame:Lerp(targetRot, dt * 10)
        end
    end)
    table.insert(UI_Instances, followConn)

    local PanelAPI = {}
    
    function PanelAPI:SetVisible(state)
        isVisible = state; SurfaceUI.Enabled = state
        if state and isPinned then
            isPinned = false; PinBtn.Text = "📍"
            TweenService:Create(PinBtn, TweenInfo.new(0.3), {BackgroundColor3 = AppleTheme.ComponentBG, BackgroundTransparency = 0.5}):Play()
            PanelPart.CFrame = Camera.CFrame * currentHoloOffset
        end
    end

    function PanelAPI:ToggleVisible() self:SetVisible(not isVisible) end

    function PanelAPI:CreateLabel(text)
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 0, 20)
        Label.BackgroundTransparency = 1
        Label.Text = text
        Label.TextColor3 = AppleTheme.TextSecondary
        Label.Font = Enum.Font.GothamMedium
        Label.TextSize = 13
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ScrollFrame
        return Label
    end

    function PanelAPI:CreateButton(text, callback)
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 40)
        Btn.BackgroundColor3 = AppleTheme.ComponentBG
        Btn.BackgroundTransparency = 0.4
        Btn.Text = text
        Btn.TextColor3 = AppleTheme.TextPrimary
        Btn.Font = Enum.Font.GothamMedium
        Btn.TextSize = 14
        Btn.Parent = ScrollFrame
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
        
        Btn.MouseButton1Click:Connect(function()
            TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = AppleTheme.Accent}):Play()
            pcall(callback)
            task.wait(0.1)
            TweenService:Create(Btn, TweenInfo.new(0.3), {BackgroundColor3 = AppleTheme.ComponentBG}):Play()
        end)
        return Btn
    end

    function PanelAPI:CreateToggle(text, default, callback)
        local state = default or false
        local TglFrame = Instance.new("TextButton")
        TglFrame.Size = UDim2.new(1, 0, 0, 45)
        TglFrame.BackgroundColor3 = AppleTheme.ComponentBG
        TglFrame.BackgroundTransparency = 0.6
        TglFrame.Text = ""
        TglFrame.Parent = ScrollFrame
        Instance.new("UICorner", TglFrame).CornerRadius = UDim.new(0, 12)

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(0.7, 0, 1, 0)
        Title.Position = UDim2.new(0, 15, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Text = text
        Title.TextColor3 = AppleTheme.TextPrimary
        Title.Font = Enum.Font.GothamMedium
        Title.TextSize = 14
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = TglFrame

        local Capsule = Instance.new("Frame")
        Capsule.Size = UDim2.new(0, 50, 0, 26)
        Capsule.Position = UDim2.new(1, -65, 0.5, -13)
        Capsule.BackgroundColor3 = state and AppleTheme.Accent or Color3.fromRGB(80, 80, 85)
        Capsule.Parent = TglFrame
        Instance.new("UICorner", Capsule).CornerRadius = UDim.new(1, 0)

        local Knob = Instance.new("Frame")
        Knob.Size = UDim2.new(0, 22, 0, 22)
        Knob.Position = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.Parent = Capsule
        Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

        local function Fire()
            state = not state
            local targetBgColor = state and AppleTheme.Accent or Color3.fromRGB(80, 80, 85)
            local targetKnobPos = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
            
            TweenService:Create(Capsule, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetBgColor}):Play()
            TweenService:Create(Knob, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetKnobPos}):Play()
            pcall(callback, state)
        end
        TglFrame.MouseButton1Click:Connect(Fire)
        pcall(callback, state)
        return TglFrame
    end

    function PanelAPI:CreateSlider(text, min, max, default, callback)
        local val = math.clamp(default or min, min, max)
        
        local SliderFrame = Instance.new("Frame")
        SliderFrame.Size = UDim2.new(1, 0, 0, 55)
        SliderFrame.BackgroundColor3 = AppleTheme.ComponentBG
        SliderFrame.BackgroundTransparency = 0.6
        SliderFrame.Parent = ScrollFrame
        Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 12)

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, -30, 0, 25)
        Title.Position = UDim2.new(0, 15, 0, 5)
        Title.BackgroundTransparency = 1
        Title.Text = text .. " : " .. tostring(val)
        Title.TextColor3 = AppleTheme.TextPrimary
        Title.Font = Enum.Font.GothamMedium
        Title.TextSize = 13
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = SliderFrame

        local Track = Instance.new("TextButton")
        Track.Size = UDim2.new(1, -30, 0, 4)
        Track.Position = UDim2.new(0, 15, 0, 38)
        Track.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
        Track.Text = ""
        Track.Parent = SliderFrame
        Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

        local Fill = Instance.new("Frame")
        Fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        Fill.BackgroundColor3 = AppleTheme.Accent
        Fill.Parent = Track
        Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

        local Thumb = Instance.new("Frame")
        Thumb.Size = UDim2.new(0, 16, 0, 16)
        Thumb.Position = UDim2.new(1, -8, 0.5, -8)
        Thumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Thumb.Parent = Fill
        Instance.new("UICorner", Thumb).CornerRadius = UDim.new(1, 0)

        local dragging = false
        local function UpdateSlider(input)
            local relX = math.clamp(input.Position.X - Track.AbsolutePosition.X, 0, Track.AbsoluteSize.X)
            local percent = relX / Track.AbsoluteSize.X
            val = math.floor(min + (max - min) * percent)
            Title.Text = text .. " : " .. tostring(val)
            TweenService:Create(Fill, TweenInfo.new(0.1), {Size = UDim2.new(percent, 0, 1, 0)}):Play()
            pcall(callback, val)
        end

        Track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; UpdateSlider(input)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                UpdateSlider(input)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
        
        pcall(callback, val)
    end

    function PanelAPI:CreateInput(placeholder, callback)
        local InputFrame = Instance.new("Frame")
        InputFrame.Size = UDim2.new(1, 0, 0, 40)
        InputFrame.BackgroundColor3 = AppleTheme.ComponentBG
        InputFrame.BackgroundTransparency = 0.6
        InputFrame.Parent = ScrollFrame
        Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 10)

        local TextBox = Instance.new("TextBox")
        TextBox.Size = UDim2.new(1, -20, 1, 0)
        TextBox.Position = UDim2.new(0, 10, 0, 0)
        TextBox.BackgroundTransparency = 1
        TextBox.PlaceholderText = placeholder
        TextBox.Text = ""
        TextBox.TextColor3 = AppleTheme.TextPrimary
        TextBox.PlaceholderColor3 = AppleTheme.TextSecondary
        TextBox.Font = Enum.Font.GothamMedium
        TextBox.TextSize = 13
        TextBox.TextXAlignment = Enum.TextXAlignment.Left
        TextBox.ClearTextOnFocus = false
        TextBox.Parent = InputFrame

        TextBox.FocusLost:Connect(function()
            pcall(callback, TextBox.Text)
        end)
    end

    function PanelAPI:CreateImageDisplay()
        local ImgFrame = Instance.new("Frame")
        ImgFrame.Size = UDim2.new(1, 0, 0, 0)
        ImgFrame.BackgroundTransparency = 1
        ImgFrame.ClipsDescendants = true
        ImgFrame.Parent = ScrollFrame

        local ImageLabel = Instance.new("ImageLabel")
        ImageLabel.Size = UDim2.new(1, 0, 1, 0)
        ImageLabel.BackgroundTransparency = 1
        ImageLabel.ScaleType = Enum.ScaleType.Fit 
        ImageLabel.Parent = ImgFrame
        Instance.new("UICorner", ImageLabel).CornerRadius = UDim.new(0, 10)

        local function UpdateImage(src)
            local asset = ParseImageAsset(src)
            if asset ~= "" then
                ImageLabel.Image = asset
                TweenService:Create(ImgFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(1, 0, 0, 220)}):Play()
            else
                TweenService:Create(ImgFrame, TweenInfo.new(0.4), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            end
        end

        return UpdateImage
    end

    function PanelAPI:CreateSubTab(subTitle)
        local subOffset = currentHoloOffset * CFrame.new(2.8, 0, 0)
        local SubPanel = CreateSpatialPanel(subTitle, subOffset, false)
        
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, 0, 0, 45)
        Btn.BackgroundColor3 = AppleTheme.ComponentBG
        Btn.BackgroundTransparency = 0.4
        Btn.Text = subTitle .. "  ➡️"
        Btn.TextColor3 = AppleTheme.TextPrimary
        Btn.Font = Enum.Font.GothamMedium
        Btn.TextSize = 14
        Btn.Parent = ScrollFrame
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 10)
        
        Btn.MouseButton1Click:Connect(function()
            TweenService:Create(Btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(80, 80, 90)}):Play()
            SubPanel:ToggleVisible() 
            task.wait(0.1)
            TweenService:Create(Btn, TweenInfo.new(0.3), {BackgroundColor3 = AppleTheme.ComponentBG}):Play()
        end)

        return SubPanel
    end

    return PanelAPI
end

function HoloLib:CreateWindow(config)
    local title = config.Title or "Vision UI"
    local MainPanel = CreateSpatialPanel(title, CFrame.new(-1.2, -0.2, -3.2), true)

    local MobileUI = Instance.new("ScreenGui")
    MobileUI.ResetOnSpawn = false
    MobileUI.Parent = secureParent
    table.insert(UI_Instances, MobileUI)

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
    ToggleBtn.Position = UDim2.new(0.5, -22, 0.05, 0)
    ToggleBtn.BackgroundColor3 = AppleTheme.GlassBG
    ToggleBtn.BackgroundTransparency = 0.2
    ToggleBtn.Text = ""
    ToggleBtn.TextColor3 = AppleTheme.TextPrimary
    ToggleBtn.TextSize = 24
    ToggleBtn.Parent = MobileUI
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", ToggleBtn)
    stroke.Color = AppleTheme.Stroke
    stroke.Transparency = 0.5
    stroke.Thickness = 1.5

    local dragToggle, dragStart, startPos
    ToggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragToggle = true; dragStart = input.Position; startPos = ToggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            ToggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragToggle = false end
    end)

    ToggleBtn.MouseButton1Click:Connect(function()
        MainPanel:ToggleVisible()
    end)

    return MainPanel
end

getgenv()._CleanHoloLib = function()
    for _, item in ipairs(UI_Instances) do
        if typeof(item) == "RBXScriptConnection" then item:Disconnect() else item:Destroy() end
    end
    UI_Instances = {}
end

local isFollowing = false
local currentImageId = "rbxassetid://97942107772966"
local followerPart = nil
local followConnection = nil

local followDistance = 6  
local imageSize = 5       

local function cleanupFollower()
    if followConnection then
        followConnection:Disconnect()
        followConnection = nil
    end
    if followerPart then
        followerPart:Destroy()
        followerPart = nil
    end
end

local function updateFollowingImage()
    cleanupFollower()
    
    if not isFollowing then return end

    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    followerPart = Instance.new("Part")
    followerPart.Name = "PaperCompanion"
    followerPart.Size = Vector3.new(imageSize, imageSize, 0.05) 
    followerPart.Transparency = 1 
    followerPart.CanCollide = false 
    followerPart.Anchored = true 
    followerPart.CastShadow = false
    followerPart.Parent = workspace

    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = "FollowerGUI"
    surfaceGui.Face = Enum.NormalId.Front 
    surfaceGui.Adornee = followerPart
    surfaceGui.AlwaysOnTop = true 
    surfaceGui.LightInfluence = 0 
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 100 
    surfaceGui.Parent = followerPart

    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Name = "DisplayImage"
    imageLabel.BackgroundTransparency = 1
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.Image = currentImageId
    imageLabel.ScaleType = Enum.ScaleType.Fit 
    imageLabel.Parent = surfaceGui

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    followConnection = RunService.Heartbeat:Connect(function(deltaTime)
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return end

        raycastParams.FilterDescendantsInstances = {char, followerPart}

        local currentPos = followerPart.Position
        local playerPos = root.Position

        local currentPos2D = Vector3.new(currentPos.X, 0, currentPos.Z)
        local playerPos2D = Vector3.new(playerPos.X, 0, playerPos.Z)
        local dist2D = (playerPos2D - currentPos2D).Magnitude

        local targetPos2D = currentPos2D

        if dist2D > followDistance then
            local directionFromPlayer = (currentPos2D - playerPos2D).Unit
            targetPos2D = playerPos2D + (directionFromPlayer * followDistance)
        end

        local rayOrigin = Vector3.new(targetPos2D.X, playerPos.Y + 10, targetPos2D.Z)
        local rayDirection = Vector3.new(0, -20, 0)
        local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

        local floorY = root.Position.Y - humanoid.HipHeight - (root.Size.Y / 2)
        if rayResult then
            floorY = rayResult.Position.Y
        end

        local currentHeight = followerPart.Size.Y
        local targetPosition = Vector3.new(targetPos2D.X, floorY + (currentHeight / 2), targetPos2D.Z)

        local dist3D = (targetPosition - currentPos).Magnitude
        local newPos = currentPos
        if dist3D > 30 then
            newPos = targetPosition  
        else
            newPos = currentPos:Lerp(targetPosition, 0.15) 
        end

        local lookAtPos = Vector3.new(playerPos.X, newPos.Y, playerPos.Z)
        if (lookAtPos - newPos).Magnitude > 0.1 then
            followerPart.CFrame = CFrame.new(newPos, lookAtPos)
        else
            followerPart.CFrame = CFrame.new(newPos)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    pcall(function()
        if isFollowing then updateFollowingImage() end
    end)
end)

local UI = HoloLib:CreateWindow({ Title = "✨ 纸片人伙伴系统" })

UI:CreateLabel("📌 核心控制")

UI:CreateInput("输入图片 ID (纯数字)...", function(text)
    local numberId = tonumber(text)
    if numberId then
        currentImageId = "rbxassetid://" .. tostring(numberId)
    else
        currentImageId = text
    end
    if isFollowing and followerPart then
        local img = followerPart:FindFirstChild("FollowerGUI") and followerPart.FollowerGUI:FindFirstChild("DisplayImage")
        if img then img.Image = currentImageId end
    end
end)

UI:CreateToggle("召唤伙伴", false, function(state)
    isFollowing = state
    if isFollowing then
        pcall(updateFollowingImage)
    else
        pcall(cleanupFollower)
    end
end)

local SubPanel = UI:CreateSubTab("⚙️ 高级参数微调")

SubPanel:CreateLabel("在此调整三维尺寸与距离")

SubPanel:CreateSlider("调整大小", 1, 20, 5, function(Value)
    imageSize = Value
    if followerPart then
        followerPart.Size = Vector3.new(imageSize, imageSize, 0.05)
    end
end)

SubPanel:CreateSlider("调整跟随距离", 3, 15, 6, function(Value)
    followDistance = Value
end)

SubPanel:CreateButton("卸载脚本", function()
    isFollowing = false
    pcall(cleanupFollower)
    if getgenv()._CleanHoloLib then 
        getgenv()._CleanHoloLib() 
    end
end)