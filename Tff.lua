local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local CorePackages = game:GetService("CorePackages")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UI_NAME = "MobileFontHub_v4_Final"
local currentFontConnection = nil
local allFontsData = {}     
local filteredFonts = {}    
local currentPage = 1
local itemsPerPage = 20     

local getAsset = getcustomasset or getsynasset
if not getAsset or not writefile then
    return
end

if CoreGui:FindFirstChild(UI_NAME) then
    CoreGui[UI_NAME]:Destroy()
end

local GWFH_API_BASE = "https://gwfh.mranftl.com/api/fonts"

local PREMIUM_CUSTOM_FONTS = {
    { family = "阿里普惠体 (Alibaba PuHuiTi)", source = "Alibaba", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/Alibaba-PuHuiTi/main/AlibabaPuHuiTi-Regular.ttf" },
    { family = "小米字体 (MiSans)", source = "Xiaomi", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/MiSans/main/MiSans-Regular.ttf" },
    { family = "OPPO 官方体 (OPPO Sans)", source = "OPPO", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/OPPOSans/main/OPPOSans-R.ttf" },
    { family = "鸿蒙黑体 (HarmonyOS Sans)", source = "Huawei", isChinese = true, url = "https://raw.githubusercontent.com/haishanh/harmonyos-fonts/main/HarmonyOS_Sans_SC/HarmonyOS_Sans_SC_Regular.ttf" },
    { family = "金山云技术体", source = "Kingsoft", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/Kingsoft-Cloud-Font/main/Kingsoft_Cloud_Font.ttf" },
    { family = "斗鱼追光体", source = "Douyu", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/Douyu-Font/main/Douyu-Font.ttf" },
    { family = "站酷酷黑", source = "Zcool", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/ZCOOL-KuHei/main/ZCOOL-KuHei.ttf" },
    { family = "站酷快乐体", source = "Zcool", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/ZCOOL-Happy/main/ZCOOL-Happy.ttf" },
    { family = "站酷文艺体", source = "Zcool", isChinese = true, url = "https://raw.githubusercontent.com/Theovan123/ZCOOL-WenYi/main/ZCOOL-WenYi.ttf" },
    { family = "霞鹜文楷", source = "LXGW", isChinese = true, url = "https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/fonts/TTF/LXGWWenKai-Regular.ttf" },
    { family = "霞鹜新晰黑", source = "LXGW", isChinese = true, url = "https://raw.githubusercontent.com/lxgw/LxgwNeoXiHei/main/ttf/LXGWNeoXiHei.ttf" },
    { family = "悠哉字体", source = "Indie", isChinese = true, url = "https://raw.githubusercontent.com/lxgw/yozai/main/fonts/ttf/Yozai-Regular.ttf" },
    { family = "小赖字体", source = "Indie", isChinese = true, url = "https://raw.githubusercontent.com/lxgw/xiaolai/main/fonts/ttf/XiaolaiMonoSC-Regular.ttf" },
    { family = "我的世界经典", source = "Game", isChinese = true, url = "https://raw.githubusercontent.com/IdreesInc/Minecraft-Font/master/minecraft_font.ttf" },
    { family = "最像素 (Zpix)", source = "GitHub", isChinese = true, url = "https://raw.githubusercontent.com/SolidZORO/zpix-pixel-font/master/zpix.ttf" },
    { family = "得意黑", source = "GitHub", isChinese = true, url = "https://raw.githubusercontent.com/atelier-anchor/smiley-sans/main/SmileySans-Oblique.ttf" }
}

local function DownloadAndMountFont(fontName, ttfUrl)
    local success, fontAssetId = pcall(function()
        local safeName = string.gsub(fontName, "[^%w]", "")
        local ttfFileName = "finalfont_" .. safeName .. ".ttf"
        local jsonFileName = "finalfont_" .. safeName .. ".json"
        local ttfData = game:HttpGet(ttfUrl)
        writefile(ttfFileName, ttfData)
        local ttfAssetId = getAsset(ttfFileName)
        local fontFamilyData = {
            name = safeName,
            faces = {{ name = "Regular", weight = 400, style = "normal", assetId = ttfAssetId }}
        }
        writefile(jsonFileName, HttpService:JSONEncode(fontFamilyData))
        return getAsset(jsonFileName)
    end)
    return success and fontAssetId or nil
end

local function ApplyGlobalFont(fontId)
    if not fontId then return end
    if currentFontConnection then currentFontConnection:Disconnect() currentFontConnection = nil end
    local success, newFont = pcall(function() return Font.new(fontId) end)
    if not success then return end

    local function isSafeToModify(obj)
        if obj:IsDescendantOf(CorePackages) then return false end
        if obj:IsDescendantOf(CoreGui) then
            local current = obj
            while current and current ~= CoreGui do
                if current.Name == "RobloxGui" or current.Name == "RobloxPromptGui" or current.Name == "ThemeProvider" or current.Name == "TopBarApp" then
                    return false
                end
                current = current.Parent
            end
        end
        if obj:FindFirstAncestor(UI_NAME) then return false end 
        return true
    end

    local function fixText(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            if isSafeToModify(obj) then pcall(function() obj.FontFace = newFont end) end
        end
    end

    for _, v in ipairs(game:GetDescendants()) do task.spawn(fixText, v) end
    currentFontConnection = game.DescendantAdded:Connect(function(v) fixText(v) end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = UI_NAME
ScreenGui.Parent = CoreGui
ScreenGui.ResetOnSpawn = false

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Position = UDim2.new(0, 15, 0.5, -22)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
ToggleBtn.Image = "rbxassetid://6031280882" 
ToggleBtn.Parent = ScreenGui
local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleBtn
local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(230, 126, 34)
ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleBtn

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 640, 0, 360)
MainFrame.Position = UDim2.new(0.5, -320, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

ToggleBtn.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
TopBar.Parent = MainFrame
local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 10)
TopBarCorner.Parent = TopBar
local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 10)
TopBarFix.Position = UDim2.new(0, 0, 1, -10)
TopBarFix.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "字体 Hub (双排分页版)"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

local dragging, dragStart, startPos
local function updateInput(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
TopBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then updateInput(input) end
    end
end)

local ControlPanel = Instance.new("Frame")
ControlPanel.Size = UDim2.new(1, -20, 0, 40)
ControlPanel.Position = UDim2.new(0, 10, 0, 45)
ControlPanel.BackgroundTransparency = 1
ControlPanel.Parent = MainFrame

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0, 300, 1, 0)
SearchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SearchBox.PlaceholderText = "搜索字体..."
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = ControlPanel
local SearchCorner = Instance.new("UICorner")
SearchCorner.CornerRadius = UDim.new(0, 6)
SearchCorner.Parent = SearchBox
local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 10)
SearchPadding.Parent = SearchBox

local PrevBtn = Instance.new("TextButton")
PrevBtn.Size = UDim2.new(0, 40, 1, 0)
PrevBtn.Position = UDim2.new(1, -190, 0, 0)
PrevBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
PrevBtn.Text = "<"
PrevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevBtn.Font = Enum.Font.GothamBold
PrevBtn.TextSize = 16
PrevBtn.Parent = ControlPanel
local PrevCorner = Instance.new("UICorner")
PrevCorner.CornerRadius = UDim.new(0, 6)
PrevCorner.Parent = PrevBtn

local NextBtn = Instance.new("TextButton")
NextBtn.Size = UDim2.new(0, 40, 1, 0)
NextBtn.Position = UDim2.new(1, -40, 0, 0)
NextBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
NextBtn.Text = ">"
NextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NextBtn.Font = Enum.Font.GothamBold
NextBtn.TextSize = 16
NextBtn.Parent = ControlPanel
local NextCorner = Instance.new("UICorner")
NextCorner.CornerRadius = UDim.new(0, 6)
NextCorner.Parent = NextBtn

local PageLabel = Instance.new("TextLabel")
PageLabel.Size = UDim2.new(0, 100, 1, 0)
PageLabel.Position = UDim2.new(1, -145, 0, 0)
PageLabel.BackgroundTransparency = 1
PageLabel.Text = "1 / 1"
PageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PageLabel.Font = Enum.Font.GothamBold
PageLabel.TextSize = 14
PageLabel.Parent = ControlPanel

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -100)
ScrollFrame.Position = UDim2.new(0, 10, 0, 90)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.ScrollBarThickness = 3
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(230, 126, 34)
ScrollFrame.Parent = MainFrame

local UIGridLayout = Instance.new("UIGridLayout")
UIGridLayout.CellSize = UDim2.new(0, 300, 0, 65)
UIGridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIGridLayout.Parent = ScrollFrame

local function UpdatePagination()
    local totalItems = #filteredFonts
    local totalPages = math.max(1, math.ceil(totalItems / itemsPerPage))
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end
    PageLabel.Text = currentPage .. " / " .. totalPages
    for _, v in ipairs(ScrollFrame:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
    local startIndex = (currentPage - 1) * itemsPerPage + 1
    local endIndex = math.min(startIndex + itemsPerPage - 1, totalItems)
    for i = startIndex, endIndex do
        local font = filteredFonts[i]
        local ItemFrame = Instance.new("Frame")
        ItemFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
        ItemFrame.Parent = ScrollFrame
        local ItemCorner = Instance.new("UICorner")
        ItemCorner.CornerRadius = UDim.new(0, 8)
        ItemCorner.Parent = ItemFrame
        local NameLabel = Instance.new("TextLabel")
        NameLabel.Size = UDim2.new(1, -85, 0, 20)
        NameLabel.Position = UDim2.new(0, 10, 0, 8)
        NameLabel.BackgroundTransparency = 1
        NameLabel.Text = font.family
        NameLabel.TextColor3 = font.isChinese and Color3.fromRGB(241, 196, 15) or Color3.fromRGB(255, 255, 255)
        NameLabel.Font = Enum.Font.GothamBold
        NameLabel.TextSize = 13
        NameLabel.TextXAlignment = Enum.TextXAlignment.Left
        NameLabel.Parent = ItemFrame
        local SubLabel = Instance.new("TextLabel")
        SubLabel.Size = UDim2.new(1, -85, 0, 15)
        SubLabel.Position = UDim2.new(0, 10, 0, 32)
        SubLabel.BackgroundTransparency = 1
        SubLabel.Text = font.isChinese and "中文示例: 探索无限" or "En: The quick fox"
        SubLabel.TextColor3 = Color3.fromRGB(130, 130, 140)
        SubLabel.Font = Enum.Font.Gotham
        SubLabel.TextSize = 11
        SubLabel.TextXAlignment = Enum.TextXAlignment.Left
        SubLabel.Parent = ItemFrame
        local ApplyBtn = Instance.new("TextButton")
        ApplyBtn.Size = UDim2.new(0, 65, 0, 35)
        ApplyBtn.Position = UDim2.new(1, -75, 0.5, -17.5)
        ApplyBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
        ApplyBtn.Text = "应用"
        ApplyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ApplyBtn.Font = Enum.Font.GothamBold
        ApplyBtn.TextSize = 12
        ApplyBtn.Parent = ItemFrame
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 6)
        BtnCorner.Parent = ApplyBtn
        ApplyBtn.MouseButton1Click:Connect(function()
            ApplyBtn.Text = "..."
            task.spawn(function()
                local ttfUrl = font.url
                if font.source == "Google" and not ttfUrl then
                    local s, r = pcall(function() return game:HttpGet(GWFH_API_BASE .. "/" .. font.id) end)
                    if s then
                        local d = HttpService:JSONDecode(r)
                        for _, v in ipairs(d.variants) do if v.id == "regular" then ttfUrl = v.ttf break end end
                    end
                end
                if ttfUrl then
                    local id = DownloadAndMountFont(font.family, ttfUrl)
                    if id then ApplyGlobalFont(id) ApplyBtn.Text = "OK" end
                end
                task.wait(1) ApplyBtn.Text = "应用"
            end)
        end)
    end
end

local function ApplyFilter(t)
    t = string.lower(t or "")
    filteredFonts = {}
    for _, f in ipairs(allFontsData) do if t == "" or string.find(string.lower(f.family), t) then table.insert(filteredFonts, f) end end
    currentPage = 1 UpdatePagination()
end

PrevBtn.MouseButton1Click:Connect(function() if currentPage > 1 then currentPage -= 1 UpdatePagination() end end)
NextBtn.MouseButton1Click:Connect(function() if currentPage < math.ceil(#filteredFonts / itemsPerPage) then currentPage += 1 UpdatePagination() end end)
SearchBox:GetPropertyChangedSignal("Text"):Connect(function() ApplyFilter(SearchBox.Text) end)

task.spawn(function()
    for _, f in ipairs(PREMIUM_CUSTOM_FONTS) do table.insert(allFontsData, f) end
    local s, r = pcall(function() return game:HttpGet(GWFH_API_BASE) end)
    if s then
        local g = HttpService:JSONDecode(r)
        for _, f in ipairs(g) do
            local cn = false
            if f.subsets then for _, b in ipairs(f.subsets) do if b:find("chinese") then cn = true break end end end
            table.insert(allFontsData, { id = f.id, family = f.family, source = "Google", isChinese = cn })
        end
    end
    table.sort(allFontsData, function(a, b)
        if a.source ~= "Google" and b.source == "Google" then return true end
        if a.source == "Google" and b.source ~= "Google" then return false end
        if a.isChinese and not b.isChinese then return true end
        if not a.isChinese and b.isChinese then return false end
        return a.family < b.family
    end)
    ApplyFilter("")
end)
