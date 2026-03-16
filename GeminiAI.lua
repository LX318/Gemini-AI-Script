--[[
    Project: Gemini Auto-Detect Hub
    UI Library: https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua
    Features: 自动游戏识别、ScriptBlox API 深度集成、谷歌双向翻译、全局 UI 汉化
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- ==========================================
-- 1. 核心翻译引擎
-- ==========================================
local function Translate(text, targetLang, sourceLang)
    if not text or text == "" or tonumber(text) then return text end
    sourceLang = sourceLang or "auto"
    targetLang = targetLang or "zh-CN"
    local success, result = pcall(function()
        local encodedText = HttpService:UrlEncode(text)
        local url = string.format("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s", sourceLang, targetLang, encodedText)
        local response = game:HttpGet(url)
        local decoded = HttpService:JSONDecode(response)
        local translatedText = ""
        for _, v in ipairs(decoded[1]) do translatedText = translatedText .. (v[1] or "") end
        return translatedText
    end)
    return success and result or text
end

-- ==========================================
-- 2. 初始化 WindUI (使用你指定的路径)
-- ==========================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local gameInfo = MarketplaceService:GetProductInfo(game.PlaceId)
local gameName = gameInfo.Name

local Window = WindUI:CreateWindow({
    Title = "Gemini Cloud Hub",
    SubTitle = "自动识别模式 | " .. gameName,
    Icon = "rbxassetid://10723456637",
    Theme = "Dark",
    Size = UDim2.fromOffset(580, 460),
    Transparent = true,
    Blur = true
})

local HomeTab = Window:Tab({ Title = "当前游戏推荐", Icon = "home" })
local SearchTab = Window:Tab({ Title = "手动搜索", Icon = "search" })
local TranslateTab = Window:Tab({ Title = "强制汉化", Icon = "languages" })
local ToolTab = Window:Tab({ Title = "通用工具", Icon = "wrench" })

-- ==========================================
-- 3. 自动匹配逻辑 (核心)
-- ==========================================
local function GetScripts(query, targetTab)
    targetTab:Section({ Title = "正在匹配: " .. query })
    
    local encoded = HttpService:UrlEncode(query)
    local url = "https://scriptblox.com/api/script/search?q=" .. encoded .. "&mode=free&page=1"
    
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success then
        local data = HttpService:JSONDecode(response)
        if data.result and data.result.scripts then
            for i, s in ipairs(data.result.scripts) do
                if i > 10 then break end -- 限制数量保证速度
                task.spawn(function()
                    local cnTitle = Translate(s.title, "zh-CN", "en")
                    targetTab:Button({
                        Title = cnTitle .. (s.verified and " [✅认证]" or ""),
                        Desc = "游戏: " .. s.game.name .. " | 原名: " .. s.title,
                        Callback = function()
                            local rawRes = game:HttpGet("https://scriptblox.com/api/script/" .. s.slug)
                            local rawData = HttpService:JSONDecode(rawRes)
                            loadstring(rawData.script.script)()
                        end
                    })
                end)
            end
        else
            targetTab:Label({ Title = "该游戏暂无推荐脚本。" })
        end
    end
end

-- 启动时自动运行一次匹配
task.spawn(function()
    GetScripts(gameName, HomeTab)
end)

-- ==========================================
-- 4. 强制汉化逻辑 (汉化其他脚本)
-- ==========================================
local translateCache = {}
TranslateTab:Section({ Title = "全局 UI 汉化引擎" })
TranslateTab:Button({
    Title = "🌐 扫描并汉化屏幕上的 UI",
    Desc = "开启其他英文脚本后，点击此按钮进行翻译",
    Callback = function()
        WindUI:Notify({Title = "正在翻译", Content = "请稍等，正在处理界面文本..."})
        for _, obj in pairs(CoreGui:GetDescendants()) do
            if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and obj.Visible then
                local txt = obj.Text
                if #txt > 2 and not translateCache[txt] then
                    task.spawn(function()
                        local translated = Translate(txt, "zh-CN", "en")
                        translateCache[txt] = translated
                        obj.Text = translated
                    end)
                elseif translateCache[txt] then
                    obj.Text = translateCache[txt]
                end
            end
        end
    end
})

-- ==========================================
-- 5. 手动搜索与通用工具
-- ==========================================
SearchTab:Input({
    Title = "手动搜索 (支持中文)",
    Placeholder = "输入游戏名...",
    Callback = function(t) if t ~= "" then GetScripts(t, SearchTab) end end
})

ToolTab:Section({ Title = "全游戏万能脚本" })
local universal = {
    {"Infinite Yield (管理员指令)", "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"},
    {"Dex Explorer (查看代码)", "https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"},
    {"Unnamed ESP (万能透视)", "https://raw.githubusercontent.com/ic3w0lf22/Unnamed-ESP/master/UnnamedESP.lua"}
}
for _, v in ipairs(universal) do
    ToolTab:Button({ Title = v[1], Callback = function() loadstring(game:HttpGet(v[2]))() end })
end

WindUI:Notify({
    Title = "Gemini Hub 已就绪",
    Content = "当前检测到游戏: " .. gameName,
    Type = "Success"
})
