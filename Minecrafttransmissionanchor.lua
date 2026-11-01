--============================================================
-- MC Waypoints V3 | Minecraft 厚边按钮风格
-- 16:9 横向窗口 / 左侧分类 Tab / 右侧锚点管理
-- 支持搜索、排序、颜色、创建、详情、复制、传送、删除、备份
-- 兼容旧存档：{ ["名称"] = { X=0, Y=0, Z=0 } }
-- 说明：文件/剪贴板功能取决于运行环境是否提供对应 API。
--============================================================

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId

local FolderName = "MC_Waypoints_Final"
local FileName = FolderName .. "/Waypoints_" .. tostring(PlaceId) .. ".json"

local MC_FONT = Enum.Font.GothamBlack
local THEMES = {
    Gray = {
        Main = Color3.fromRGB(72, 73, 78),
        High = Color3.fromRGB(105, 106, 112),
        Shadow = Color3.fromRGB(45, 45, 48),
        Outer = Color3.fromRGB(28, 28, 31),
    },
    Green = {
        Main = Color3.fromRGB(52, 114, 33),
        High = Color3.fromRGB(91, 177, 58),
        Shadow = Color3.fromRGB(38, 79, 24),
        Outer = Color3.fromRGB(24, 44, 13),
    },
    Red = {
        Main = Color3.fromRGB(125, 43, 38),
        High = Color3.fromRGB(170, 61, 53),
        Shadow = Color3.fromRGB(79, 26, 23),
        Outer = Color3.fromRGB(43, 17, 15),
    },
}
local COLOR_MAP = {
    gray = Color3.fromRGB(160, 160, 160),
    red = Color3.fromRGB(200, 60, 60),
    green = Color3.fromRGB(70, 170, 70),
    blue = Color3.fromRGB(70, 110, 200),
    yellow = Color3.fromRGB(220, 200, 60),
    purple = Color3.fromRGB(160, 90, 200),
}
local COLOR_ORDER = {"gray", "red", "green", "blue", "yellow", "purple"}
local COLOR_NAMES = {gray="灰", red="红", green="绿", blue="蓝", yellow="黄", purple="紫"}

-- 新数据结构：{ Categories = { {Name="默认", Waypoints={...}} }, ActiveCategory="默认" }
local Categories = {}
local ActiveCategory = "默认"
local State = {
    Page = 1,
    PageSize = 5,
    Search = "",
    Sort = "time",
    SelectedName = nil,
    ViewMode = "list",
}

local function EnsureFolder()
    if isfolder and makefolder then
        if not isfolder(FolderName) then pcall(makefolder, FolderName) end
    end
end

local function NormalizeEntry(raw)
    if type(raw) ~= "table" then return nil end
    return {
        X = tonumber(raw.X) or 0,
        Y = tonumber(raw.Y) or 0,
        Z = tonumber(raw.Z) or 0,
        CreatedAt = tonumber(raw.CreatedAt) or os.time(),
        Color = COLOR_MAP[tostring(raw.Color or "gray")] and tostring(raw.Color or "gray") or "gray",
    }
end

local function GetCategory(name)
    for _, category in ipairs(Categories) do
        if category.Name == name then return category end
    end
    return nil
end

local function GetActiveData()
    local category = GetCategory(ActiveCategory)
    if not category then
        category = {Name = ActiveCategory, Waypoints = {}}
        table.insert(Categories, category)
    end
    return category.Waypoints
end

local function SaveWaypoints()
    if not (writefile and isfolder) then return end
    EnsureFolder()
    local payload = {Version = 3, ActiveCategory = ActiveCategory, Categories = Categories}
    local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
    if ok then pcall(writefile, FileName, encoded) end
end

local function LoadWaypoints()
    Categories = {}
    ActiveCategory = "默认"
    if isfile and readfile and isfile(FileName) then
        local ok, content = pcall(readfile, FileName)
        if ok and content then
            local decOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
            if decOk and type(decoded) == "table" then
                if type(decoded.Categories) == "table" then
                    for _, rawCategory in ipairs(decoded.Categories) do
                        if type(rawCategory) == "table" and type(rawCategory.Name) == "string" then
                            local cat = {Name = rawCategory.Name, Waypoints = {}}
                            if type(rawCategory.Waypoints) == "table" then
                                for name, raw in pairs(rawCategory.Waypoints) do
                                    local entry = NormalizeEntry(raw)
                                    if entry then cat.Waypoints[tostring(name)] = entry end
                                end
                            end
                            if not GetCategory(cat.Name) then table.insert(Categories, cat) end
                        end
                    end
                    if type(decoded.ActiveCategory) == "string" then ActiveCategory = decoded.ActiveCategory end
                else
                    -- 旧版平铺存档自动迁移到“默认”分页
                    local migrated = {}
                    for name, raw in pairs(decoded) do
                        if type(name) == "string" then
                            local entry = NormalizeEntry(raw)
                            if entry then migrated[name] = entry end
                        end
                    end
                    table.insert(Categories, {Name = "默认", Waypoints = migrated})
                end
            end
        end
    end
    if #Categories == 0 then table.insert(Categories, {Name = "默认", Waypoints = {}}) end
    if not GetCategory(ActiveCategory) then ActiveCategory = Categories[1].Name end
end

local function TeleportTo(coords)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(coords.X, coords.Y + 3, coords.Z)
    end
end

local function createThickButton(parent, text, size, pos, theme)
    local container = Instance.new("Frame")
    container.Name = "ButtonContainer"
    container.Size, container.Position = size, pos
    container.BackgroundTransparency = 1
    container.Parent = parent

    local outer = Instance.new("Frame")
    outer.Size = UDim2.fromScale(1, 1)
    outer.BackgroundColor3 = theme.Outer
    outer.BorderSizePixel = 0
    outer.Parent = container

    local visual = Instance.new("Frame")
    visual.Size = UDim2.new(1, -2, 1, -4)
    visual.Position = UDim2.new(0, 1, 0, 1)
    visual.BackgroundColor3 = theme.Main
    visual.BorderSizePixel = 0
    visual.Parent = outer

    local highlight = Instance.new("Frame")
    highlight.Size = UDim2.new(1, -2, 1, -2)
    highlight.BackgroundColor3 = theme.High
    highlight.BorderSizePixel = 0
    highlight.Parent = visual

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, -2, 1, -2)
    fill.Position = UDim2.new(0, 2, 0, 2)
    fill.BackgroundColor3 = theme.Main
    fill.BorderSizePixel = 0
    fill.Parent = visual

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Text = text
    label.Font = MC_FONT
    label.TextSize = 12
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 5
    label.Parent = visual

    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.fromScale(1, 1)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 10
    hitbox.Parent = container

    hitbox.MouseButton1Down:Connect(function()
        visual.Position = UDim2.new(0, 1, 0, 3)
    end)
    local function release()
        if visual.Parent then visual.Position = UDim2.new(0, 1, 0, 1) end
    end
    hitbox.MouseButton1Up:Connect(release)
    hitbox.MouseLeave:Connect(release)
    return container, hitbox, label
end

local function addCornerlessStroke(obj, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = thickness or 1
    stroke.Parent = obj
    return stroke
end

local function InitUI()
    local old = CoreGui:FindFirstChild("MC_Waypoints_System")
    if old then old:Destroy() end

    LoadWaypoints()

    local gui = Instance.new("ScreenGui")
    gui.Name = "MC_Waypoints_System"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = CoreGui

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local winW = math.clamp(math.floor(viewport.X * 0.76), 520, 820)
    local winH = math.floor(winW * 9 / 16)
    if winH > viewport.Y * 0.82 then
        winH = math.floor(viewport.Y * 0.82)
        winW = math.floor(winH * 16 / 9)
    end
    winW = math.max(360, winW)
    winH = math.max(220, winH)

    local toggleContainer, toggleHitbox, toggleText =
        createThickButton(gui, "锚点\n菜单", UDim2.fromOffset(58, 58),
            UDim2.new(1, -72, 0.5, -29), THEMES.Gray)

    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.fromOffset(winW, winH)
    main.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BackgroundTransparency = 0.22
    main.BorderSizePixel = 0
    main.Visible = false
    main.Active = true
    main.Parent = gui
    addCornerlessStroke(main, Color3.fromRGB(65, 65, 65), 2)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 34)
    titleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    titleBar.BackgroundTransparency = 0.08
    titleBar.BorderSizePixel = 0
    titleBar.Parent = main

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -48, 1, 0)
    title.Position = UDim2.fromOffset(10, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = "MINE-WAYPOINTS V3"
    title.Font = MC_FONT
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(34, 34)
    close.Position = UDim2.new(1, -34, 0, 0)
    close.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    close.BorderSizePixel = 0
    close.Text = "X"
    close.Font = MC_FONT
    close.TextSize = 14
    close.TextColor3 = Color3.new(1, 1, 1)
    close.Parent = titleBar
    close.MouseButton1Click:Connect(function()
        main.Visible = false
        toggleText.Text = "锚点\n菜单"
    end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -44)
    content.Position = UDim2.fromOffset(8, 40)
    content.BackgroundTransparency = 1
    content.Parent = main

    -- 左侧分类栏：固定宽度，右侧内容自适应
    local sideW = math.clamp(math.floor(winW * 0.25), 112, 170)
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, sideW, 1, 0)
    sidebar.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    sidebar.BackgroundTransparency = 0.16
    sidebar.BorderSizePixel = 0
    sidebar.Parent = content
    addCornerlessStroke(sidebar, Color3.fromRGB(55, 55, 55), 1)

    local sideTitle = Instance.new("TextLabel")
    sideTitle.Size = UDim2.new(1, -12, 0, 25)
    sideTitle.Position = UDim2.fromOffset(6, 5)
    sideTitle.BackgroundTransparency = 1
    sideTitle.Text = "锚点分页"
    sideTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
    sideTitle.Font = MC_FONT
    sideTitle.TextSize = 13
    sideTitle.TextXAlignment = Enum.TextXAlignment.Left
    sideTitle.Parent = sidebar

    local tabScroll = Instance.new("ScrollingFrame")
    tabScroll.Size = UDim2.new(1, -10, 1, -82)
    tabScroll.Position = UDim2.fromOffset(5, 34)
    tabScroll.BackgroundTransparency = 1
    tabScroll.BorderSizePixel = 0
    tabScroll.ScrollBarThickness = 3
    tabScroll.CanvasSize = UDim2.new()
    tabScroll.Parent = sidebar
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Parent = tabScroll

    local addTabC, addTabH = createThickButton(sidebar, "+ 新建分页",
        UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 1, -38), THEMES.Green)

    -- 右侧工作区
    local right = Instance.new("Frame")
    right.Size = UDim2.new(1, -sideW - 8, 1, 0)
    right.Position = UDim2.new(0, sideW + 8, 0, 0)
    right.BackgroundTransparency = 1
    right.Parent = content

    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.Size = UDim2.new(1, -4, 0, 24)
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Text = "位置管理"
    sectionTitle.TextColor3 = Color3.new(1, 1, 1)
    sectionTitle.Font = MC_FONT
    sectionTitle.TextSize = 14
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.Parent = right

    local createRow = Instance.new("Frame")
    createRow.Size = UDim2.new(1, 0, 0, 34)
    createRow.Position = UDim2.fromOffset(0, 27)
    createRow.BackgroundTransparency = 1
    createRow.Parent = right

    local nameBg = Instance.new("Frame")
    nameBg.Size = UDim2.new(0.42, -4, 1, 0)
    nameBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    nameBg.BackgroundTransparency = 0.25
    nameBg.BorderSizePixel = 1
    nameBg.BorderColor3 = Color3.fromRGB(80, 80, 80)
    nameBg.Parent = createRow

    local nameInput = Instance.new("TextBox")
    nameInput.Size = UDim2.new(1, -10, 1, 0)
    nameInput.Position = UDim2.fromOffset(5, 0)
    nameInput.BackgroundTransparency = 1
    nameInput.TextColor3 = Color3.new(1, 1, 1)
    nameInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    nameInput.PlaceholderText = "位置名称..."
    nameInput.ClearTextOnFocus = false
    nameInput.Font = MC_FONT
    nameInput.TextSize = 12
    nameInput.TextXAlignment = Enum.TextXAlignment.Left
    nameInput.Parent = nameBg

    local colorIndex = 1
    local colorC, colorH, colorT = createThickButton(createRow, "颜色:灰",
        UDim2.new(0, 70, 1, 0), UDim2.new(0.42, 2, 0, 0), THEMES.Gray)
    colorH.MouseButton1Click:Connect(function()
        colorIndex = colorIndex % #COLOR_ORDER + 1
        colorT.Text = "颜色:" .. COLOR_NAMES[COLOR_ORDER[colorIndex]]
    end)

    local saveC, saveH = createThickButton(createRow, "＋ 建立锚点",
        UDim2.new(0.58, -76, 1, 0), UDim2.new(0.42, 76, 0, 0), THEMES.Green)

    local toolRow = Instance.new("Frame")
    toolRow.Size = UDim2.new(1, 0, 0, 30)
    toolRow.Position = UDim2.fromOffset(0, 67)
    toolRow.BackgroundTransparency = 1
    toolRow.Parent = right

    local searchBg = Instance.new("Frame")
    searchBg.Size = UDim2.new(0.52, -4, 1, 0)
    searchBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    searchBg.BackgroundTransparency = 0.25
    searchBg.BorderSizePixel = 1
    searchBg.BorderColor3 = Color3.fromRGB(80, 80, 80)
    searchBg.Parent = toolRow

    local searchInput = Instance.new("TextBox")
    searchInput.Size = UDim2.new(1, -10, 1, 0)
    searchInput.Position = UDim2.fromOffset(5, 0)
    searchInput.BackgroundTransparency = 1
    searchInput.TextColor3 = Color3.new(1, 1, 1)
    searchInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    searchInput.PlaceholderText = "搜索位置..."
    searchInput.ClearTextOnFocus = false
    searchInput.Font = MC_FONT
    searchInput.TextSize = 11
    searchInput.TextXAlignment = Enum.TextXAlignment.Left
    searchInput.Parent = searchBg

    local sortC, sortH, sortT = createThickButton(toolRow, "时间排序",
        UDim2.new(0.24, -3, 1, 0), UDim2.new(0.52, 2, 0, 0), THEMES.Gray)
    local backupC, backupH = createThickButton(toolRow, "备份",
        UDim2.new(0.24, -2, 1, 0), UDim2.new(0.76, 2, 0, 0), THEMES.Gray)

    local listTop, pagerH = 104, 28
    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 1, -(listTop + pagerH + 5))
    list.Position = UDim2.fromOffset(0, listTop)
    list.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    list.BackgroundTransparency = 0.62
    list.BorderSizePixel = 1
    list.BorderColor3 = Color3.fromRGB(45, 45, 45)
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.new()
    list.Parent = right

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = list

    local pager = Instance.new("Frame")
    pager.Size = UDim2.new(1, 0, 0, pagerH)
    pager.Position = UDim2.new(0, 0, 1, -pagerH)
    pager.BackgroundTransparency = 1
    pager.Parent = right

    local prevC, prevH = createThickButton(pager, "< 上一页",
        UDim2.new(0, 78, 1, 0), UDim2.new(0, 0, 0, 0), THEMES.Gray)
    local pageLabel = Instance.new("TextLabel")
    pageLabel.Size = UDim2.new(1, -166, 1, 0)
    pageLabel.Position = UDim2.fromOffset(83, 0)
    pageLabel.BackgroundTransparency = 1
    pageLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    pageLabel.Text = "1 / 1"
    pageLabel.Font = MC_FONT
    pageLabel.TextSize = 11
    pageLabel.Parent = pager
    local nextC, nextH = createThickButton(pager, "下一页 >",
        UDim2.new(0, 78, 1, 0), UDim2.new(1, -78, 0, 0), THEMES.Gray)

    -- 详情覆盖层
    local detail = Instance.new("Frame")
    detail.Size = list.Size
    detail.Position = list.Position
    detail.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    detail.BackgroundTransparency = 0.05
    detail.BorderSizePixel = 1
    detail.BorderColor3 = Color3.fromRGB(70, 70, 70)
    detail.Visible = false
    detail.ZIndex = 20
    detail.Parent = right

    local detailTitle = Instance.new("TextLabel")
    detailTitle.Size = UDim2.new(1, -16, 0, 26)
    detailTitle.Position = UDim2.fromOffset(8, 7)
    detailTitle.BackgroundTransparency = 1
    detailTitle.TextColor3 = Color3.new(1, 1, 1)
    detailTitle.Font = MC_FONT
    detailTitle.TextSize = 14
    detailTitle.TextXAlignment = Enum.TextXAlignment.Left
    detailTitle.ZIndex = 21
    detailTitle.Parent = detail

    local detailBody = Instance.new("TextLabel")
    detailBody.Size = UDim2.new(1, -16, 1, -58)
    detailBody.Position = UDim2.fromOffset(8, 36)
    detailBody.BackgroundTransparency = 1
    detailBody.TextColor3 = Color3.fromRGB(210, 210, 210)
    detailBody.Font = MC_FONT
    detailBody.TextSize = 12
    detailBody.TextXAlignment = Enum.TextXAlignment.Left
    detailBody.TextYAlignment = Enum.TextYAlignment.Top
    detailBody.TextWrapped = true
    detailBody.ZIndex = 21
    detailBody.Parent = detail

    local backC, backH = createThickButton(detail, "返回列表",
        UDim2.new(0, 100, 0, 28), UDim2.new(0, 8, 1, -34), THEMES.Gray)
    backC.ZIndex = 22
    local detailCopyC, detailCopyH = createThickButton(detail, "复制坐标",
        UDim2.new(0, 100, 0, 28), UDim2.new(0, 114, 1, -34), THEMES.Green)
    detailCopyC.ZIndex = 22

    local function FormatTime(ts)
        local ok, result = pcall(os.date, "%Y-%m-%d %H:%M", ts)
        return ok and result or tostring(ts)
    end

    local function GetSortedFiltered()
        local data = GetActiveData()
        local result = {}
        for name, entry in pairs(data) do
            if State.Search == "" or name:lower():find(State.Search:lower(), 1, true) then
                table.insert(result, {name = name, data = entry})
            end
        end
        if State.Sort == "name" then
            table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
        else
            table.sort(result, function(a, b)
                return (a.data.CreatedAt or 0) > (b.data.CreatedAt or 0)
            end)
        end
        return result
    end

    local function RefreshTabs()
        for _, child in ipairs(tabScroll:GetChildren()) do
            if child:IsA("Frame") and child.Name == "TabRow" then child:Destroy() end
        end
        for index, category in ipairs(Categories) do
            local selected = category.Name == ActiveCategory
            local row, hit, label = createThickButton(tabScroll, category.Name,
                UDim2.new(1, -2, 0, 32), UDim2.new(), selected and THEMES.Green or THEMES.Gray)
            row.Name = "TabRow"
            row.LayoutOrder = index
            label.TextSize = 11
            hit.MouseButton1Click:Connect(function()
                ActiveCategory = category.Name
                State.Page = 1
                State.SelectedName = nil
                detail.Visible = false
                RefreshTabs()
                RefreshList()
                SaveWaypoints()
            end)
            -- 右键分页可删除；至少保留一个分页
            hit.MouseButton2Click:Connect(function()
                if #Categories <= 1 then return end
                local idx
                for i, c in ipairs(Categories) do
                    if c.Name == category.Name then idx = i break end
                end
                if idx then table.remove(Categories, idx) end
                if ActiveCategory == category.Name then
                    ActiveCategory = Categories[1].Name
                end
                State.Page = 1
                detail.Visible = false
                RefreshTabs()
                RefreshList()
                SaveWaypoints()
            end)
        end
        tabScroll.CanvasSize = UDim2.new(0, 0, 0, tabLayout.AbsoluteContentSize.Y + 4)
    end

    function RefreshList()
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("Frame") and child.Name == "WaypointRow" then child:Destroy() end
        end

        local items = GetSortedFiltered()
        local totalPages = math.max(1, math.ceil(#items / State.PageSize))
        State.Page = math.clamp(State.Page, 1, totalPages)
        local first = (State.Page - 1) * State.PageSize + 1
        local last = math.min(first + State.PageSize - 1, #items)

        for i = first, last do
            local item = items[i]
            local row = Instance.new("Frame")
            row.Name = "WaypointRow"
            row.Size = UDim2.new(1, -6, 0, 45)
            row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            row.BackgroundTransparency = 0.91
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.Parent = list

            local bar = Instance.new("Frame")
            bar.Size = UDim2.new(0, 5, 1, -8)
            bar.Position = UDim2.fromOffset(4, 4)
            bar.BackgroundColor3 = COLOR_MAP[item.data.Color] or COLOR_MAP.gray
            bar.BorderSizePixel = 0
            bar.Parent = row

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.39, -8, 0, 19)
            nameLabel.Position = UDim2.fromOffset(14, 3)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
            nameLabel.Text = item.name
            nameLabel.Font = MC_FONT
            nameLabel.TextSize = 11
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = row

            local coordLabel = Instance.new("TextLabel")
            coordLabel.Size = UDim2.new(0.42, -8, 0, 14)
            coordLabel.Position = UDim2.fromOffset(14, 23)
            coordLabel.BackgroundTransparency = 1
            coordLabel.TextColor3 = Color3.fromRGB(175, 175, 175)
            coordLabel.Text = string.format("X:%d  Y:%d  Z:%d", item.data.X, item.data.Y, item.data.Z)
            coordLabel.Font = MC_FONT
            coordLabel.TextSize = 9
            coordLabel.TextXAlignment = Enum.TextXAlignment.Left
            coordLabel.TextTruncate = Enum.TextTruncate.AtEnd
            coordLabel.Parent = row

            local actionWidth = 30
            local gap = 3
            local totalAction = actionWidth * 4 + gap * 3
            local startX = -totalAction - 5
            local detailC, detailH = createThickButton(row, "详", UDim2.fromOffset(actionWidth, 25),
                UDim2.new(1, startX, 0, 10), THEMES.Gray)
            local copyC, copyH = createThickButton(row, "复", UDim2.fromOffset(actionWidth, 25),
                UDim2.new(1, startX + actionWidth + gap, 0, 10), THEMES.Gray)
            local tpC, tpH = createThickButton(row, "传", UDim2.fromOffset(actionWidth, 25),
                UDim2.new(1, startX + (actionWidth + gap) * 2, 0, 10), THEMES.Green)
            local delC, delH = createThickButton(row, "删", UDim2.fromOffset(actionWidth, 25),
                UDim2.new(1, startX + (actionWidth + gap) * 3, 0, 10), THEMES.Red)

            detailH.MouseButton1Click:Connect(function()
                State.SelectedName = item.name
                State.ViewMode = "detail"
                detailTitle.Text = item.name
                detailBody.Text = string.format(
                    "所在分页：%s\n\n坐标：X = %d    Y = %d    Z = %d\n\n颜色：%s\n创建时间：%s",
                    ActiveCategory, item.data.X, item.data.Y, item.data.Z,
                    item.data.Color or "gray", FormatTime(item.data.CreatedAt)
                )
                detail.Visible = true
            end)
            copyH.MouseButton1Click:Connect(function()
                local value = string.format("%d, %d, %d", item.data.X, item.data.Y, item.data.Z)
                if setclipboard then pcall(setclipboard, value) end
            end)
            tpH.MouseButton1Click:Connect(function() TeleportTo(item.data) end)
            delH.MouseButton1Click:Connect(function()
                GetActiveData()[item.name] = nil
                if State.SelectedName == item.name then
                    State.SelectedName = nil
                    detail.Visible = false
                end
                SaveWaypoints()
                RefreshList()
            end)
        end

        list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 4)
        pageLabel.Text = string.format("%d / %d   ·   %d 个位置", State.Page, totalPages, #items)
    end

    -- 新建分页：使用系统输入框，避免额外改变原版按钮风格
    addTabH.MouseButton1Click:Connect(function()
        local prompt = Instance.new("Frame")
        prompt.Size = UDim2.fromOffset(250, 112)
        prompt.Position = UDim2.new(0.5, -125, 0.5, -56)
        prompt.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        prompt.BorderSizePixel = 0
        prompt.ZIndex = 50
        prompt.Parent = main
        addCornerlessStroke(prompt, Color3.fromRGB(95, 95, 95), 2)

        local promptTitle = Instance.new("TextLabel")
        promptTitle.Size = UDim2.new(1, -12, 0, 25)
        promptTitle.Position = UDim2.fromOffset(6, 4)
        promptTitle.BackgroundTransparency = 1
        promptTitle.Text = "新建锚点分页"
        promptTitle.TextColor3 = Color3.new(1, 1, 1)
        promptTitle.Font = MC_FONT
        promptTitle.TextSize = 13
        promptTitle.ZIndex = 51
        promptTitle.Parent = prompt

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(1, -16, 0, 28)
        input.Position = UDim2.fromOffset(8, 33)
        input.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
        input.BorderColor3 = Color3.fromRGB(85, 85, 85)
        input.TextColor3 = Color3.new(1, 1, 1)
        input.PlaceholderText = "输入分页名称"
        input.Font = MC_FONT
        input.TextSize = 12
        input.ClearTextOnFocus = false
        input.ZIndex = 51
        input.Parent = prompt

        local cancelC, cancelH = createThickButton(prompt, "取消",
            UDim2.new(0.42, -5, 0, 27), UDim2.new(0, 8, 1, -34), THEMES.Gray)
        cancelC.ZIndex = 52
        local confirmC, confirmH = createThickButton(prompt, "创建",
            UDim2.new(0.42, -5, 0, 27), UDim2.new(1, -8, 1, -34), THEMES.Green)
        confirmC.AnchorPoint = Vector2.new(1, 0)
        confirmC.ZIndex = 52

        cancelH.MouseButton1Click:Connect(function() prompt:Destroy() end)
        confirmH.MouseButton1Click:Connect(function()
            local name = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" or #name > 24 or GetCategory(name) then
                promptTitle.Text = (name == "" and "请输入分页名称" or (#name > 24 and "名称最多 24 个字符" or "分页已存在"))
                return
            end
            table.insert(Categories, {Name = name, Waypoints = {}})
            ActiveCategory = name
            State.Page = 1
            State.Search = ""
            searchInput.Text = ""
            detail.Visible = false
            prompt:Destroy()
            RefreshTabs()
            RefreshList()
            SaveWaypoints()
        end)
        input:CaptureFocus()
    end)

    saveH.MouseButton1Click:Connect(function()
        local name = nameInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if name == "" or not hrp then return end
        local p = hrp.Position
        GetActiveData()[name] = {
            X = math.floor(p.X), Y = math.floor(p.Y), Z = math.floor(p.Z),
            CreatedAt = os.time(), Color = COLOR_ORDER[colorIndex],
        }
        nameInput.Text = ""
        State.Page = 1
        SaveWaypoints()
        RefreshList()
    end)

    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        State.Search = searchInput.Text
        State.Page = 1
        RefreshList()
    end)

    sortH.MouseButton1Click:Connect(function()
        State.Sort = State.Sort == "time" and "name" or "time"
        sortT.Text = State.Sort == "time" and "时间排序" or "名称排序"
        State.Page = 1
        RefreshList()
    end)

    backupH.MouseButton1Click:Connect(function()
        if not (writefile and isfolder) then return end
        EnsureFolder()
        local path = FolderName .. "/Backup_" .. tostring(PlaceId) .. "_" .. tostring(os.time()) .. ".json"
        local payload = {Version = 3, ActiveCategory = ActiveCategory, Categories = Categories}
        local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
        if ok then pcall(writefile, path, encoded) end
    end)

    prevH.MouseButton1Click:Connect(function()
        if State.Page > 1 then State.Page -= 1; RefreshList() end
    end)
    nextH.MouseButton1Click:Connect(function()
        local pages = math.max(1, math.ceil(#GetSortedFiltered() / State.PageSize))
        if State.Page < pages then State.Page += 1; RefreshList() end
    end)

    backH.MouseButton1Click:Connect(function()
        State.ViewMode = "list"
        State.SelectedName = nil
        detail.Visible = false
    end)
    detailCopyH.MouseButton1Click:Connect(function()
        local data = State.SelectedName and GetActiveData()[State.SelectedName]
        if data and setclipboard then
            pcall(setclipboard, string.format("%d, %d, %d", data.X, data.Y, data.Z))
        end
    end)

    toggleHitbox.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
        toggleText.Text = main.Visible and "关 闭" or "锚点\n菜单"
    end)

    -- 标题栏拖动（鼠标和触摸）
    local dragging, dragInput, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- 首次绘制
    RefreshTabs()
    RefreshList()
end

task.spawn(InitUI)
