local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local SoundService = game:GetService("SoundService")

local req = (syn and syn.request) or (http and http.request) or http_request or request
local getasset = getcustomasset or getsynasset

if not req or not getasset or not writefile then
    warn("环境缺失高级API！无法运行此脚本。") return
end

local ConfigFolder = "NeteaseData_Ultimate"
if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end

local Theme = {
    Bg = Color3.fromRGB(12, 12, 12),
    Panel = Color3.fromRGB(20, 20, 20),
    Accent = Color3.fromRGB(229, 57, 53),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(160, 160, 160),
    Stroke = Color3.fromRGB(40, 40, 40)
}

local State = {
    IsPlaying = false,
    CurrentSong = nil,
    Lyrics = {},
    Volume = 0.5,
    Source = "Netease",
    Sources = {"Netease", "QQ", "Kugou"},
    LoopMode = 1,
    IsMinimized = false,
    LastLrcText = "",
    MarqueeTween = nil,
    CurrentQuery = "",
    CurrentPage = 1,
    Limit = 30
}

local function MakeDraggable(ui)
    local dragging, dragStart, startPos
    ui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = ui.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            ui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "NeteaseUltimatePro_Marquee"
ScreenGui.ResetOnSpawn = false

local LyricWin = Instance.new("Frame", ScreenGui)
LyricWin.Size = UDim2.new(0, 600, 0, 80)
LyricWin.Position = UDim2.new(0.5, -300, 0.85, 0)
LyricWin.BackgroundTransparency = 1
LyricWin.ClipsDescendants = true
LyricWin.Active = true
MakeDraggable(LyricWin)

local LrcText = Instance.new("TextLabel", LyricWin)
LrcText.Size = UDim2.new(1, 0, 1, 0)
LrcText.Position = UDim2.new(0, 0, 0, 0)
LrcText.BackgroundTransparency = 1
LrcText.Text = "Netease Pro Max Ready"
LrcText.TextColor3 = Theme.Accent
LrcText.Font = Enum.Font.GothamBlack
LrcText.TextSize = 28
LrcText.TextStrokeTransparency = 0.5
LrcText.TextWrapped = false
LrcText.Parent = LyricWin

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 340, 0, 160)
Main.Position = UDim2.new(0.5, -170, 0.5, -80)
Main.BackgroundColor3 = Theme.Bg; Main.Active = true
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = Theme.Accent
MakeDraggable(Main)

local RestoreBall = Instance.new("TextButton", ScreenGui)
RestoreBall.Size = UDim2.new(0, 50, 0, 50); RestoreBall.Position = UDim2.new(0, 20, 0.5, -25)
RestoreBall.BackgroundColor3 = Theme.Bg; RestoreBall.Text = "🎵"; RestoreBall.TextColor3 = Theme.Accent
RestoreBall.TextSize = 24; RestoreBall.Visible = false; RestoreBall.Active = true
Instance.new("UICorner", RestoreBall).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", RestoreBall).Color = Theme.Accent
MakeDraggable(RestoreBall)

local TopBar = Instance.new("Frame", Main)
TopBar.Size = UDim2.new(1, 0, 0, 30); TopBar.BackgroundTransparency = 1
local MinBtn = Instance.new("TextButton", TopBar)
MinBtn.Size = UDim2.new(0, 30, 0, 30); MinBtn.Position = UDim2.new(1, -35, 0, 0)
MinBtn.Text = "—"; MinBtn.TextColor3 = Theme.SubText; MinBtn.BackgroundTransparency = 1; MinBtn.Font = Enum.Font.GothamBold

local Cover = Instance.new("ImageLabel", Main)
Cover.Size = UDim2.new(0, 80, 0, 80); Cover.Position = UDim2.new(0, 15, 0, 40)
Cover.BackgroundColor3 = Theme.Panel; Cover.Image = "rbxassetid://6031280882"; Instance.new("UICorner", Cover).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, -120, 0, 20); Title.Position = UDim2.new(0, 105, 0, 45); Title.BackgroundTransparency = 1; Title.Text = "网易云音乐 PRO"; Title.TextColor3 = Theme.Text; Title.Font = Enum.Font.GothamBold; Title.TextSize = 16; Title.TextXAlignment = 0

local Artist = Instance.new("TextLabel", Main)
Artist.Size = UDim2.new(1, -120, 0, 15); Artist.Position = UDim2.new(0, 105, 0, 65); Artist.BackgroundTransparency = 1; Artist.Text = "等待指令"; Artist.TextColor3 = Theme.SubText; Artist.Font = Enum.Font.Gotham; Artist.TextSize = 12; Artist.TextXAlignment = 0

local ProgBG = Instance.new("Frame", Main)
ProgBG.Size = UDim2.new(1, -30, 0, 4); ProgBG.Position = UDim2.new(0, 15, 0, 130); ProgBG.BackgroundColor3 = Theme.Stroke; ProgBG.BorderSizePixel = 0
local ProgBar = Instance.new("Frame", ProgBG)
ProgBar.Size = UDim2.new(0, 0, 1, 0); ProgBar.BackgroundColor3 = Theme.Accent; ProgBar.BorderSizePixel = 0

local PlayBtn = Instance.new("TextButton", Main)
PlayBtn.Size = UDim2.new(0, 35, 0, 35); PlayBtn.Position = UDim2.new(0, 105, 0, 88); PlayBtn.BackgroundColor3 = Theme.Panel; PlayBtn.Text = "▶"; PlayBtn.TextColor3 = Theme.Text; Instance.new("UICorner", PlayBtn).CornerRadius = UDim.new(1, 0)

local SearchToggle = Instance.new("TextButton", Main)
SearchToggle.Size = UDim2.new(0, 35, 0, 35); SearchToggle.Position = UDim2.new(0, 150, 0, 88); SearchToggle.BackgroundColor3 = Theme.Panel; SearchToggle.Text = "🔍"; SearchToggle.TextColor3 = Theme.Text; Instance.new("UICorner", SearchToggle).CornerRadius = UDim.new(1, 0)

local LoopBtn = Instance.new("TextButton", Main)
LoopBtn.Size = UDim2.new(0, 35, 0, 35); LoopBtn.Position = UDim2.new(0, 195, 0, 88); LoopBtn.BackgroundColor3 = Theme.Panel; LoopBtn.Text = "🔁"; LoopBtn.TextColor3 = Theme.SubText; Instance.new("UICorner", LoopBtn).CornerRadius = UDim.new(1, 0)

local SearchPanel = Instance.new("Frame", ScreenGui)
SearchPanel.Size = UDim2.new(0, 340, 0, 400); SearchPanel.Position = UDim2.new(0.5, -170, 0.5, -200); SearchPanel.BackgroundColor3 = Theme.Bg; SearchPanel.Visible = false; SearchPanel.Active = true; Instance.new("UICorner", SearchPanel); Instance.new("UIStroke", SearchPanel).Color = Theme.Accent; MakeDraggable(SearchPanel)

local SearchInput = Instance.new("TextBox", SearchPanel)
SearchInput.Size = UDim2.new(0.65, -15, 0, 35); SearchInput.Position = UDim2.new(0, 10, 0, 10); SearchInput.BackgroundColor3 = Theme.Panel; SearchInput.TextColor3 = Theme.Text; SearchInput.PlaceholderText = "输入歌名..."; Instance.new("UICorner", SearchInput)

local SourceBtn = Instance.new("TextButton", SearchPanel)
SourceBtn.Size = UDim2.new(0.35, -10, 0, 35); SourceBtn.Position = UDim2.new(0.65, 5, 0, 10); SourceBtn.BackgroundColor3 = Theme.Accent; SourceBtn.TextColor3 = Theme.Text; SourceBtn.Text = "源: Netease"; SourceBtn.Font = Enum.Font.GothamBold; SourceBtn.TextSize = 12; Instance.new("UICorner", SourceBtn)

local ScrollList = Instance.new("ScrollingFrame", SearchPanel)
ScrollList.Size = UDim2.new(1, -20, 1, -95); ScrollList.Position = UDim2.new(0, 10, 0, 55); ScrollList.BackgroundTransparency = 1; ScrollList.ScrollBarThickness = 2
local ListLayout = Instance.new("UIListLayout", ScrollList); ListLayout.Padding = UDim.new(0, 5)

local PaginationFrame = Instance.new("Frame", SearchPanel)
PaginationFrame.Size = UDim2.new(1, -20, 0, 30); PaginationFrame.Position = UDim2.new(0, 10, 1, -35); PaginationFrame.BackgroundTransparency = 1

local PrevBtn = Instance.new("TextButton", PaginationFrame)
PrevBtn.Size = UDim2.new(0, 60, 1, 0); PrevBtn.Position = UDim2.new(0, 0, 0, 0); PrevBtn.BackgroundColor3 = Theme.Panel; PrevBtn.Text = "上一页"; PrevBtn.TextColor3 = Theme.Text; PrevBtn.Font = Enum.Font.Gotham; PrevBtn.TextSize = 12; Instance.new("UICorner", PrevBtn)

local PageLbl = Instance.new("TextLabel", PaginationFrame)
PageLbl.Size = UDim2.new(1, -130, 1, 0); PageLbl.Position = UDim2.new(0, 65, 0, 0); PageLbl.BackgroundTransparency = 1; PageLbl.Text = "第 1 页"; PageLbl.TextColor3 = Theme.SubText; PageLbl.Font = Enum.Font.GothamBold; PageLbl.TextSize = 12

local NextBtn = Instance.new("TextButton", PaginationFrame)
NextBtn.Size = UDim2.new(0, 60, 1, 0); NextBtn.Position = UDim2.new(1, -60, 0, 0); NextBtn.BackgroundColor3 = Theme.Panel; NextBtn.Text = "下一页"; NextBtn.TextColor3 = Theme.Text; NextBtn.Font = Enum.Font.Gotham; NextBtn.TextSize = 12; Instance.new("UICorner", NextBtn)

local isTransitioning = false
local function UpdateLyricSilk(newText)
    if State.LastLrcText == newText or isTransitioning then return end
    State.LastLrcText = newText
    isTransitioning = true

    if State.MarqueeTween then
        State.MarqueeTween:Cancel()
        State.MarqueeTween = nil
    end

    local info = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

    local fadeOut = TweenService:Create(LrcText, info, {
        Position = UDim2.new(0, 0, 0, -25),
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })
    
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        LrcText.Text = newText
        LrcText.Position = UDim2.new(0, 0, 0, 25)
        
        local fadeIn = TweenService:Create(LrcText, info, {
            Position = UDim2.new(0, 0, 0, 0),
            TextTransparency = 0,
            TextStrokeTransparency = 0.5
        })
        
        fadeIn:Play()
        fadeIn.Completed:Connect(function()
            isTransitioning = false
            
            local textWidth = TextService:GetTextSize(newText, 28, Enum.Font.GothamBlack, Vector2.new(9999, 100)).X
            local containerWidth = LyricWin.AbsoluteSize.X
            
            if textWidth > containerWidth then
                local overflow = textWidth - containerWidth + 60
                local duration = overflow / 45
                
                task.delay(1, function()
                    if State.LastLrcText == newText then
                        State.MarqueeTween = TweenService:Create(LrcText, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                            Position = UDim2.new(0, -overflow, 0, 0)
                        })
                        State.MarqueeTween:Play()
                    end
                end)
            end
        end)
    end)
end

local Audio = Instance.new("Sound", game:GetService("SoundService"))

Audio.Ended:Connect(function()
    if State.LoopMode == 2 and State.IsPlaying then
        Audio.TimePosition = 0
        Audio:Play()
    end
end)

LoopBtn.MouseButton1Click:Connect(function()
    State.LoopMode = State.LoopMode == 1 and 2 or 1
    LoopBtn.Text = State.LoopMode == 2 and "🔂" or "🔁"
    LoopBtn.TextColor3 = State.LoopMode == 2 and Theme.Accent or Theme.SubText
end)

SourceBtn.MouseButton1Click:Connect(function()
    local idx = 1
    for i, v in ipairs(State.Sources) do if v == State.Source then idx = i break end end
    idx = (idx % #State.Sources) + 1
    State.Source = State.Sources[idx]
    SourceBtn.Text = "源: " .. State.Source
end)

local function ToggleMinimize(minimize)
    State.IsMinimized = minimize
    if minimize then
        Main.Visible = false; SearchPanel.Visible = false
        RestoreBall.Visible = true
    else
        Main.Visible = true; RestoreBall.Visible = false
    end
end

MinBtn.MouseButton1Click:Connect(function() ToggleMinimize(true) end)
RestoreBall.MouseButton1Click:Connect(function() ToggleMinimize(false) end)

function PlaySong(song)
    Audio:Stop()
    Audio.SoundId = "" 
    Title.Text = song.name; Artist.Text = "正在解析 [" .. State.Source .. "] 源..."
    UpdateLyricSilk("Loading API...")
    
    task.spawn(function()
        local s, e = pcall(function()
            local url = ""
            if State.Source == "QQ" or State.Source == "Kugou" then
                local sourceType = State.Source == "QQ" and "tencent" or "kugou"
                url = "https://api.injahow.cn/meting/?type="..sourceType.."&id="..song.id.."&server=netease"
            else
                url = "http://music.163.com/song/media/outer/url?id=" .. song.id .. ".mp3"
            end

            local res = req({Url = url, Method = "GET"})
            if #res.Body > 1000 then
                local fileName = ConfigFolder .. "/Track_" .. tostring(song.id) .. ".mp3"
                writefile(fileName, res.Body)
                Audio.SoundId = getasset(fileName)
                
                local lres = req({Url = "http://music.163.com/api/song/lyric?id="..song.id.."&lv=-1", Method="GET"})
                local ld = HttpService:JSONDecode(lres.Body)
                State.Lyrics = {}
                if ld.lrc then
                    for m, s, t in ld.lrc.lyric:gmatch("%[(%d+):(%d+%.?%d*)%]([^\r\n]*)") do
                        table.insert(State.Lyrics, {time = tonumber(m)*60+tonumber(s), text = t})
                    end
                end
                
                Audio:Play(); PlayBtn.Text = "⏸"; Artist.Text = song.artists[1].name
            else
                Artist.Text = "源解析失败，自动降级为网易云"
                State.Source = "Netease"
                SourceBtn.Text = "源: Netease"
                PlaySong(song)
            end
        end)
    end)
end

local function DoSearch(query, page)
    if query == "" then return end
    State.CurrentQuery = query
    State.CurrentPage = page
    PageLbl.Text = "加载中..."

    for _, v in pairs(ScrollList:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end

    task.spawn(function()
        local offset = (page - 1) * State.Limit
        local searchUrl = "http://music.163.com/api/search/get/web?s=" .. HttpService:UrlEncode(query) .. "&type=1&limit=" .. State.Limit .. "&offset=" .. offset
        local res = req({Url = searchUrl, Method = "GET"})
        local d = HttpService:JSONDecode(res.Body)

        PageLbl.Text = "第 " .. page .. " 页"

        if not d.result or not d.result.songs then return end

        for _, s in ipairs(d.result.songs) do
            local item = Instance.new("Frame", ScrollList)
            item.Size = UDim2.new(1, 0, 0, 40); item.BackgroundColor3 = Theme.Panel; Instance.new("UICorner", item)
            local txt = Instance.new("TextLabel", item)
            txt.Size = UDim2.new(1, -50, 1, 0); txt.Position = UDim2.new(0, 10, 0, 0); txt.BackgroundTransparency = 1
            txt.Text = s.name .. " - " .. s.artists[1].name; txt.TextColor3 = Theme.Text; txt.TextXAlignment = 0; txt.Font = Enum.Font.Gotham; txt.TextSize = 12
            local p = Instance.new("TextButton", item)
            p.Size = UDim2.new(0, 30, 0, 30); p.Position = UDim2.new(1, -35, 0.5, -15); p.Text = "▶"; p.BackgroundColor3 = Theme.Accent; Instance.new("UICorner", p)
            p.MouseButton1Click:Connect(function() PlaySong(s) end)
        end
        ScrollList.CanvasSize = UDim2.new(0, 0, 0, #d.result.songs * 45)
    end)
end

SearchInput.FocusLost:Connect(function(e)
    if not e or SearchInput.Text == "" then return end
    DoSearch(SearchInput.Text, 1)
end)

PrevBtn.MouseButton1Click:Connect(function()
    if State.CurrentPage > 1 then
        DoSearch(State.CurrentQuery, State.CurrentPage - 1)
    end
end)

NextBtn.MouseButton1Click:Connect(function()
    if State.CurrentQuery ~= "" then
        DoSearch(State.CurrentQuery, State.CurrentPage + 1)
    end
end)

SearchToggle.MouseButton1Click:Connect(function() SearchPanel.Visible = not SearchPanel.Visible end)
PlayBtn.MouseButton1Click:Connect(function()
    if Audio.IsPlaying then Audio:Pause(); PlayBtn.Text = "▶" else Audio:Resume(); PlayBtn.Text = "⏸" end
end)

RunService.RenderStepped:Connect(function()
    if Audio.IsPlaying and Audio.TimeLength > 0 then
        ProgBar.Size = UDim2.new(Audio.TimePosition / Audio.TimeLength, 0, 1, 0)
        local cur = Audio.TimePosition
        for i = #State.Lyrics, 1, -1 do
            if cur >= State.Lyrics[i].time then
                UpdateLyricSilk(State.Lyrics[i].text)
                break
            end
        end
    end
end)
