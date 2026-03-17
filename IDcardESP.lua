local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local secureContainer = (gethui and gethui()) or (pcall(function() return CoreGui.Name end) and CoreGui) or LocalPlayer:WaitForChild("PlayerGui")

local espFolder = secureContainer:FindFirstChild("IDCardESP_Storage")
if not espFolder then
    espFolder = Instance.new("Folder")
    espFolder.Name = "IDCardESP_Storage"
    espFolder.Parent = secureContainer
end

local IDScannerModule = {
    Enabled = false,
    PlayerCache = {},
    Connections = {}
}

local STYLE = {
    PanelSize = UDim2.new(0, 260, 0, 160),
    HeightOffset = Vector3.new(0, 3.5, 0),
    BgImageId = "rbxassetid://97942107772966",
    BgImageTransparency = 0.35,
    StrokeColor = Color3.fromRGB(180, 200, 200),
    CornerRadius = UDim.new(0, 8),
    LabelColor = Color3.fromRGB(41, 128, 185),
    TextColor = Color3.fromRGB(20, 20, 20),
}

local function createPanel(player)
    if player == LocalPlayer or IDScannerModule.PlayerCache[player] then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = player.Name .. "_IDCard"
    billboard.Size = STYLE.PanelSize
    billboard.StudsOffset = STYLE.HeightOffset
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 5000
    billboard.ResetOnSpawn = false
    billboard.Enabled = false
    billboard.Parent = espFolder

    local mainFrame = Instance.new("ImageLabel")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.Image = STYLE.BgImageId
    mainFrame.ImageTransparency = STYLE.BgImageTransparency
    mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mainFrame.Parent = billboard
    Instance.new("UICorner", mainFrame).CornerRadius = STYLE.CornerRadius
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = STYLE.StrokeColor
    stroke.Thickness = 1
    stroke.Parent = mainFrame

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, 65, 0, 85)
    avatarImg.Position = UDim2.new(1, -75, 0, 15)
    avatarImg.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
    avatarImg.ScaleType = Enum.ScaleType.Crop
    avatarImg.Parent = mainFrame
    Instance.new("UICorner", avatarImg).CornerRadius = UDim.new(0, 4)
    
    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Color = Color3.fromRGB(150, 150, 150)
    avatarStroke.Thickness = 1
    avatarStroke.Parent = avatarImg

    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -90, 0, 100)
    infoFrame.Position = UDim2.new(0, 15, 0, 15)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = infoFrame

    local function createRow(name, labelText, valueText, isBold)
        local row = Instance.new("TextLabel")
        row.Name = name
        row.Size = UDim2.new(1, 0, 0, 16)
        row.BackgroundTransparency = 1
        row.RichText = true
        
        local fontFormat = isBold and "<b>%s</b>" or "%s"
        row.Text = string.format("<font color=\"rgb(%d,%d,%d)\">%s</font>  <font color=\"rgb(%d,%d,%d)\">" .. fontFormat .. "</font>", 
            STYLE.LabelColor.R*255, STYLE.LabelColor.G*255, STYLE.LabelColor.B*255, labelText,
            STYLE.TextColor.R*255, STYLE.TextColor.G*255, STYLE.TextColor.B*255, valueText)
            
        row.Font = Enum.Font.GothamMedium
        row.TextSize = 12
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.Parent = infoFrame
        return row
    end

    local rows = {
        Name = createRow("Name", "姓  名", player.DisplayName, true),
        Username = createRow("Username", "代  号", "@" .. player.Name, false),
        Vitals = createRow("Vitals", "体  征", "更新中...", false),
        Tool = createRow("Tool", "武  装", "更新中...", false),
        Distance = createRow("Distance", "距  离", "更新中...", false),
    }

    local idTitle = Instance.new("TextLabel")
    idTitle.Size = UDim2.new(1, -30, 0, 14)
    idTitle.Position = UDim2.new(0, 15, 1, -45)
    idTitle.BackgroundTransparency = 1
    idTitle.Text = "公民身份号码 (UID / 局龄)"
    idTitle.Font = Enum.Font.GothamMedium
    idTitle.TextSize = 10
    idTitle.TextColor3 = STYLE.LabelColor
    idTitle.TextXAlignment = Enum.TextXAlignment.Left
    idTitle.Parent = mainFrame

    local idValue = Instance.new("TextLabel")
    idValue.Size = UDim2.new(1, -30, 0, 20)
    idValue.Position = UDim2.new(0, 15, 1, -28)
    idValue.BackgroundTransparency = 1
    idValue.RichText = true
    idValue.Font = Enum.Font.GothamBold
    idValue.TextSize = 16
    idValue.TextColor3 = STYLE.TextColor
    idValue.TextXAlignment = Enum.TextXAlignment.Left
    idValue.Parent = mainFrame
    
    local ageWarning = player.AccountAge < 7 and "<font color=\"rgb(231,76,60)\"> [黑户预警]</font>" or ""
    idValue.Text = string.format("%d<font size=\"12\"> (%d天)%s</font>", player.UserId, player.AccountAge, ageWarning)

    IDScannerModule.PlayerCache[player] = {
        Billboard = billboard,
        Rows = rows
    }
end

local function removePanel(player)
    if IDScannerModule.PlayerCache[player] then
        pcall(function() IDScannerModule.PlayerCache[player].Billboard:Destroy() end)
        IDScannerModule.PlayerCache[player] = nil
    end
end

local function updateTarget()
    if not IDScannerModule.Enabled then return end

    local myPos = Camera.CFrame.Position
    local closestPlayer = nil
    local shortestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if head and hum and hum.Health > 0 then
                local dist = (myPos - head.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestPlayer = player
                end
            end
        end
    end

    for player, data in pairs(IDScannerModule.PlayerCache) do
        if player == closestPlayer then
            local char = player.Character
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChild("Humanoid")
            
            data.Billboard.Adornee = head
            data.Billboard.Enabled = true

            local function updateRowText(rowLabel, labelText, valueText)
                rowLabel.Text = string.format("<font color=\"rgb(%d,%d,%d)\">%s</font>  <font color=\"rgb(%d,%d,%d)\">%s</font>", 
                    STYLE.LabelColor.R*255, STYLE.LabelColor.G*255, STYLE.LabelColor.B*255, labelText,
                    STYLE.TextColor.R*255, STYLE.TextColor.G*255, STYLE.TextColor.B*255, valueText)
            end

            local hpColor = hum.Health > (hum.MaxHealth/2) and "rgb(46,204,113)" or "rgb(231,76,60)"
            local speedWarning = hum.WalkSpeed > 16.5 and "<font color=\"rgb(231,76,60)\">(异常)</font>" or ""
            local vitalsStr = string.format("HP <font color=\"%s\">%d</font> / 移速 %d%s", hpColor, math.floor(hum.Health), math.floor(hum.WalkSpeed), speedWarning)
            updateRowText(data.Rows.Vitals, "体  征", vitalsStr)

            local tool = char:FindFirstChildOfClass("Tool")
            local toolName = tool and string.format("<font color=\"rgb(211,84,0)\">%s</font>", tool.Name) or "无 (安全)"
            updateRowText(data.Rows.Tool, "武  装", toolName)

            updateRowText(data.Rows.Distance, "距  离", string.format("<b>%d</b> 米", math.floor(shortestDistance)))

        else
            data.Billboard.Enabled = false
            data.Billboard.Adornee = nil
        end
    end
end

function IDScannerModule:Toggle(state)
    self.Enabled = state
    if self.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do createPanel(p) end
        if not self.Connections.Added then self.Connections.Added = Players.PlayerAdded:Connect(function(p) task.wait(1) createPanel(p) end) end
        if not self.Connections.Removing then self.Connections.Removing = Players.PlayerRemoving:Connect(removePanel) end
        if not self.Connections.Render then self.Connections.Render = RunService.RenderStepped:Connect(updateTarget) end
    else
        for k, v in pairs(self.Connections) do v:Disconnect(); self.Connections[k] = nil end
        for p, _ in pairs(self.PlayerCache) do removePanel(p) end
    end
end

getgenv().IDScanner = IDScannerModule
IDScanner:Toggle(true)
