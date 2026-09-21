--[[
=========================================================================================
  OrionLib · Refined                                                              v2.0.0
  ---------------------------------------------------------------------------------------
  对原版 OrionLib (ori.lua) 的完整重构版本，保留全部原有 API，同时：

    · 视觉重构  —— 设计令牌(Design Token)驱动的配色 / 间距 / 圆角 / 描边 / 投影体系
    · 动画升级  —— 统一缓动曲线、弹性反馈、点击涟漪、页面转场、错峰入场、序列开场
    · 组件优化  —— Toggle / Slider / Dropdown / Bind / Textbox / Colorpicker 全部重写
    · 新增接口  —— 分隔线 / 占位块 / 图片 / 多选下拉 / 下拉搜索 / 十六进制取色 /
                   状态栏 / 主题系统 / 强调色运行时切换 / 配置 JSON 导入导出 / 中英文切换
    · 缺陷修复  —— table.foreach 在 Luau 已移除、滑块连接泄漏、Shift 提示不一致、
                   未开启保存却写文件、通知 TweenPosition 已弃用 等
  ---------------------------------------------------------------------------------------
  用法：
    local OrionLib = loadstring(game:HttpGet("你的链接"))()
    local Window = OrionLib:MakeWindow({ Name = "我的脚本", IntroText = "正在加载" })
    local Tab = Window:MakeTab({ Name = "主页", Icon = "home" })
    Tab:AddToggle({ Name = "自动攻击", Flag = "autoAttack", Callback = function(v) end })
=========================================================================================
--]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------------
-- [ 0 ] 运行环境兼容层 ( 执行器差异 / 新旧 Roblox API 差异 )
------------------------------------------------------------------------------

local TaskSpawn = (type(task) == "table" and task.spawn) or spawn
local TaskWait = (type(task) == "table" and task.wait) or wait
local TaskDelay = (type(task) == "table" and task.delay) or delay

local function SafeCall(Function, ...)
	if type(Function) ~= "function" then return end
	local Results = table.pack(pcall(Function, ...))
	if not Results[1] then
		warn("[OrionLib] 回调执行出错: " .. tostring(Results[2]))
	end
	return table.unpack(Results, 2, Results.n)
end

local function HttpGet(Url)
	local Ok, Response = pcall(function() return game:HttpGet(Url) end)
	if not Ok then
		Ok, Response = pcall(function() return game:HttpGetAsync(Url) end)
	end
	if Ok and type(Response) == "string" then
		return Response
	end
	return nil
end

local function ExecutorCall(Name, ...)
	local Fn = rawget(getfenv(), Name)
	if type(Fn) == "function" then
		return SafeCall(Fn, ...)
	end
	return nil
end

local function GetGuiParent()
	local Parent
	if type(gethui) == "function" then
		local Ok, Result = pcall(gethui)
		if Ok and Result then Parent = Result end
	end
	if not Parent and type(syn) == "table" and type(syn.protect_gui) == "function" then
		Parent = game:GetService("CoreGui")
	end
	if not Parent then
		local Ok, Result = pcall(function() return game:GetService("CoreGui") end)
		if Ok then Parent = Result end
	end
	if not Parent then
		Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	return Parent
end

------------------------------------------------------------------------------
-- [ 1 ] 文案表 ( 中 / 英 )
------------------------------------------------------------------------------

local Lang = {
	zh = {
		Hidden          = "界面已隐藏",
		ToggleHint      = "按下 %s 重新打开界面",
		Search          = "搜索功能…",
		NoResult        = "没有匹配的功能",
		Locked          = "此页面已锁定",
		LockedDesc      = "该分页需要更高权限才能解锁访问。",
		Placeholder     = "请输入…",
		None            = "未绑定",
		Listening       = "请按按键…",
		Selected        = "已选择",
		MultiSelected   = "已选 %d 项",
		Unselected      = "未选择",
		All             = "全部",
		Confirm         = "确定",
		Cancel          = "取消",
		Copy            = "已复制到剪贴板",
		Loading         = "正在初始化",
		Ready           = "就绪",
		Page            = "分页",
		Total           = "共 %d 项",
	},
	en = {
		Hidden          = "Interface hidden",
		ToggleHint      = "Press %s to reopen the interface",
		Search          = "Search features…",
		NoResult        = "No matching feature",
		Locked          = "This page is locked",
		LockedDesc      = "This page requires higher privileges to access.",
		Placeholder     = "Type here…",
		None            = "None",
		Listening       = "Press a key…",
		Selected        = "Selected",
		MultiSelected   = "%d selected",
		Unselected      = "Nothing selected",
		All             = "All",
		Confirm         = "Confirm",
		Cancel          = "Cancel",
		Copy            = "Copied to clipboard",
		Loading         = "Initializing",
		Ready           = "Ready",
		Page            = "Page",
		Total           = "%d items",
	},
}

local SelectedLanguage = "zh"

local function L(Key, ...)
	local Pack = Lang[SelectedLanguage] or Lang.zh
	local Text = Pack[Key] or (Lang.zh[Key] or Key)
	if select("#", ...) > 0 then
		local Ok, Formatted = pcall(string.format, Text, ...)
		if Ok then return Formatted end
	end
	return Text
end

------------------------------------------------------------------------------
-- [ 2 ] 通用工具
------------------------------------------------------------------------------

local function Create(ClassName, Properties, Children)
	local Object = Instance.new(ClassName)
	for Property, Value in pairs(Properties or {}) do
		Object[Property] = Value
	end
	for _, Child in ipairs(Children or {}) do
		Child.Parent = Object
	end
	return Object
end

local function SetProps(Element, Properties)
	for Property, Value in pairs(Properties or {}) do
		Element[Property] = Value
	end
	return Element
end

local function SetChildren(Element, Children)
	for _, Child in ipairs(Children or {}) do
		Child.Parent = Element
	end
	return Element
end

local function Round(Number, Factor)
	if not Factor or Factor <= 0 then return Number end
	local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function Clamp01(Value)
	if Value < 0 then return 0 elseif Value > 1 then return 1 end
	return Value
end

local function LerpColor(From, To, Alpha)
	return Color3.new(
		From.R + (To.R - From.R) * Alpha,
		From.G + (To.G - From.G) * Alpha,
		From.B + (To.B - From.B) * Alpha
	)
end

local function ShadeColor(Color, Amount)
	if Amount >= 0 then
		return LerpColor(Color, Color3.new(1, 1, 1), Amount)
	end
	return LerpColor(Color, Color3.new(0, 0, 0), -Amount)
end

local function HexToColor3(Hex)
	if type(Hex) ~= "string" then return nil end
	Hex = Hex:gsub("#", ""):gsub("%s", "")
	if #Hex == 3 then
		Hex = Hex:sub(1, 1):rep(2) .. Hex:sub(2, 2):rep(2) .. Hex:sub(3, 3):rep(2)
	end
	if #Hex ~= 6 or Hex:match("%X") then return nil end
	local R = tonumber(Hex:sub(1, 2), 16)
	local G = tonumber(Hex:sub(3, 4), 16)
	local B = tonumber(Hex:sub(5, 6), 16)
	if not R or not G or not B then return nil end
	return Color3.fromRGB(R, G, B)
end

local function Color3ToHex(Color)
	return string.format("#%02X%02X%02X",
		math.floor(Clamp01(Color.R) * 255 + 0.5),
		math.floor(Clamp01(Color.G) * 255 + 0.5),
		math.floor(Clamp01(Color.B) * 255 + 0.5)
	)
end

local function PackColor(Color)
	return { R = math.floor(Clamp01(Color.R) * 255 + 0.5), G = math.floor(Clamp01(Color.G) * 255 + 0.5), B = math.floor(Clamp01(Color.B) * 255 + 0.5) }
end

local function UnpackColor(Color)
	if type(Color) ~= "table" then return nil end
	return Color3.fromRGB(Color.R or 255, Color.G or 255, Color.B or 255)
end

local function FormatNumber(Value, Decimals)
	if Decimals and Decimals > 0 then
		return string.format("%." .. Decimals .. "f", Value)
	end
	return tostring(math.floor(Value + 0.5) == Value and math.floor(Value) or Value)
end

local function TruncateText(Text, MaxLength)
	Text = tostring(Text or "")
	if #Text <= MaxLength then return Text end
	return Text:sub(1, MaxLength - 1) .. "…"
end

------------------------------------------------------------------------------
-- [ 3 ] 动画引擎 ( 统一大厂级缓动 )
------------------------------------------------------------------------------

local TI = {
	Instant   = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fast      = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal    = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Smooth    = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow      = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring    = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Press     = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fade      = TweenInfo.new(0.22, Enum.EasingStyle.Linear),
}

local function Tween(Object, Info, Properties)
	if not Object then return nil end
	local Animation = TweenService:Create(Object, Info or TI.Normal, Properties)
	Animation:Play()
	return Animation
end

local function EnsureScale(Object, Scale)
	local Existing = Object:FindFirstChild("UIScale")
	if Existing and Existing:IsA("UIScale") then return Existing end
	return Create("UIScale", {
		Name = "UIScale",
		Scale = Scale or 1,
		Parent = Object,
	})
end

local function Spring(Object, Properties, Info)
	return Tween(Object, Info or TI.Spring, Properties)
end

------------------------------------------------------------------------------
-- [ 4 ] 轻量信号
------------------------------------------------------------------------------

local function Signal()
	local Handlers = {}
	local Connection = {}
	Connection.Connect = function(_, Callback)
		if type(Callback) ~= "function" then return end
		local Handler = { Callback = Callback }
		table.insert(Handlers, Handler)
		return {
			Disconnect = function()
				local Index = table.find(Handlers, Handler)
				if Index then table.remove(Handlers, Index) end
			end,
		}
	end
	Connection.Fire = function(_, ...)
		for _, Handler in ipairs(Handlers) do
			SafeCall(Handler.Callback, ...)
		end
	end
	return Connection
end

------------------------------------------------------------------------------
-- [ 5 ] 图标基元 ( 全部由 Frame 绘制, 不依赖任何素材, 断网也不会缺失 )
------------------------------------------------------------------------------

local function MakeBar(Parent, Properties)
	local Bar = Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
	for Property, Value in pairs(Properties or {}) do
		Bar[Property] = Value
	end
	Bar.Parent = Parent
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = Bar })
	return Bar
end

local IconKit = {}

function IconKit.Close(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconClose",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local Length = Size * 0.56
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Length, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Color,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Length, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Rotation = -45,
		BackgroundColor3 = Color,
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Minimize(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconMinimize",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Size * 0.56, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		BackgroundColor3 = Color,
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Chevron(Parent, Size, Color, Thickness, Direction)
	local Holder = Create("Frame", {
		Name = "IconChevron",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Rotation = (Direction == "left" and 90) or (Direction == "right" and -90) or (Direction == "up" and 180) or 0,
	})
	local Length = Size * 0.42
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Length, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.27, Size * 0.63),
		Rotation = 45,
		BackgroundColor3 = Color,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Length, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.73, Size * 0.63),
		Rotation = -45,
		BackgroundColor3 = Color,
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Check(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconCheck",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Size * 0.36, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.28, Size * 0.53),
		Rotation = -45,
		BackgroundColor3 = Color,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Size * 0.62, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.63, Size * 0.42),
		Rotation = 42,
		BackgroundColor3 = Color,
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Search(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconSearch",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	Create("Frame", {
		Name = "Lens",
		Size = UDim2.fromOffset(Size * 0.62, Size * 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.44, Size * 0.44),
		BackgroundTransparency = 1,
		Parent = Holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Color, Thickness = Thickness, Transparency = 0 }),
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Size * 0.34, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Size * 0.78, Size * 0.78),
		Rotation = 45,
		BackgroundColor3 = Color,
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Lock(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconLock",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	Create("Frame", {
		Size = UDim2.fromOffset(Size * 0.62, Size * 0.5),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Color,
		Parent = Holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 3) }),
	})
	Create("Frame", {
		Size = UDim2.fromOffset(Size * 0.42, Size * 0.42),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(Size * 0.5, Size * 0.46),
		BackgroundTransparency = 1,
		Parent = Holder,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Create("UIStroke", { Color = Color, Thickness = Thickness, Transparency = 0 }),
	})
	Holder.Parent = Parent
	return Holder
end

function IconKit.Dot(Parent, Size, Color)
	local Dot = Create("Frame", {
		Name = "IconDot",
		Size = UDim2.fromOffset(Size, Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color,
		BorderSizePixel = 0,
		Parent = Parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	return Dot
end

-- 递归给矢量图标换色 ( Frame 本体 / UIStroke / 字形文本 )
local function SetIconColor(IconHolder, Color, Transparency)
	if not IconHolder then return end
	for _, Object in ipairs(IconHolder:GetDescendants()) do
		if Object:IsA("Frame") then
			Object.BackgroundColor3 = Color
			if Transparency then Object.BackgroundTransparency = Transparency end
		elseif Object:IsA("UIStroke") then
			Object.Color = Color
			if Transparency then Object.Transparency = Transparency end
		elseif Object:IsA("TextLabel") then
			Object.TextColor3 = Color
		end
	end
	if IconHolder:IsA("Frame") then
		IconHolder.BackgroundColor3 = Color
	end
	return IconHolder
end

function IconKit.Plus(Parent, Size, Color, Thickness)
	local Holder = Create("Frame", {
		Name = "IconPlus",
		Size = UDim2.fromOffset(Size, Size),
		BackgroundTransparency = 1,
		Parent = Parent,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Size * 0.7, Thickness),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color,
	})
	MakeBar(Holder, {
		Size = UDim2.fromOffset(Thickness, Size * 0.7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color,
	})
	return Holder
end

------------------------------------------------------------------------------
-- [ 6 ] 图标系统 ( 支持 Feather/lucide 名称 / 图片 ID / 单字符字形 )
------------------------------------------------------------------------------

local IconPack = {
	Loaded = false,
	Icons = {},
	Sources = {
		"https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json",
		"https://cdn.jsdelivr.net/gh/evoincorp/lucideblox@master/src/modules/util/icons.json",
	},
}

local function FetchIconPack()
	for _, Url in ipairs(IconPack.Sources) do
		local Body = HttpGet(Url)
		if Body then
			local Ok, Decoded = pcall(function() return HttpService:JSONDecode(Body) end)
			if Ok and type(Decoded) == "table" and type(Decoded.icons) == "table" then
				IconPack.Icons = Decoded.icons
				IconPack.Loaded = true
				return true
			end
		end
	end
	return false
end

TaskSpawn(function()
	local Ok, Err = pcall(FetchIconPack)
	if not Ok then
		warn("[OrionLib] 图标包加载失败, 将使用内置图标方案: " .. tostring(Err))
	end
end)

local function GetIcon(IconName)
	if type(IconName) ~= "string" then return nil end
	local Icon = IconPack.Icons[IconName]
	if type(Icon) == "string" then return Icon end
	if IconPack.Icons[IconName:lower()] then return IconPack.Icons[IconName:lower()] end
	return nil
end

-- 返回 nil | {Kind = "image"|"glyph", Value = ...}
local function ResolveIcon(IconName)
	if type(IconName) ~= "string" or IconName == "" then return nil end
	if IconName:match("^rbxasset") or IconName:match("^http") then
		return { Kind = "image", Value = IconName }
	end
	local Mapped = GetIcon(IconName)
	if Mapped then
		return { Kind = "image", Value = Mapped }
	end
	if #IconName <= 3 then
		return { Kind = "glyph", Value = IconName }
	end
	return nil
end

local function BuildIcon(Parent, IconName, Size, Color, Properties)
	local Resolved = ResolveIcon(IconName)
	if not Resolved then return nil end
	local Object
	if Resolved.Kind == "image" then
		Object = Create("ImageLabel", {
			Name = "Icon",
			Image = Resolved.Value,
			ImageColor3 = Color or Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(Size, Size),
		})
	else
		Object = Create("TextLabel", {
			Name = "Icon",
			Text = Resolved.Value,
			TextColor3 = Color or Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = Size,
			Size = UDim2.fromOffset(Size, Size),
		})
	end
	for Property, Value in pairs(Properties or {}) do
		Object[Property] = Value
	end
	Object.Parent = Parent
	return Object
end

------------------------------------------------------------------------------
-- [ 7 ] 主题令牌
------------------------------------------------------------------------------

local DefaultThemes = {
	Dark = {
		Main = Color3.fromRGB(16, 16, 20), Second = Color3.fromRGB(22, 22, 28),
		Card = Color3.fromRGB(28, 28, 36), CardHover = Color3.fromRGB(36, 36, 46),
		Stroke = Color3.fromRGB(54, 54, 68), Divider = Color3.fromRGB(40, 40, 50),
		Text = Color3.fromRGB(240, 241, 245), TextDark = Color3.fromRGB(150, 152, 166),
		Accent = Color3.fromRGB(88, 132, 255), Accent2 = Color3.fromRGB(158, 110, 255),
	},
	Midnight = {
		Main = Color3.fromRGB(9, 11, 20), Second = Color3.fromRGB(14, 17, 30),
		Card = Color3.fromRGB(20, 24, 42), CardHover = Color3.fromRGB(28, 33, 56),
		Stroke = Color3.fromRGB(44, 52, 82), Divider = Color3.fromRGB(28, 34, 56),
		Text = Color3.fromRGB(234, 240, 255), TextDark = Color3.fromRGB(138, 150, 182),
		Accent = Color3.fromRGB(94, 118, 255), Accent2 = Color3.fromRGB(58, 190, 255),
	},
	Ocean = {
		Main = Color3.fromRGB(11, 19, 25), Second = Color3.fromRGB(16, 27, 35),
		Card = Color3.fromRGB(22, 36, 46), CardHover = Color3.fromRGB(30, 48, 60),
		Stroke = Color3.fromRGB(46, 70, 84), Divider = Color3.fromRGB(30, 48, 60),
		Text = Color3.fromRGB(236, 246, 250), TextDark = Color3.fromRGB(140, 168, 180),
		Accent = Color3.fromRGB(46, 196, 182), Accent2 = Color3.fromRGB(60, 140, 255),
	},
	Forest = {
		Main = Color3.fromRGB(13, 19, 15), Second = Color3.fromRGB(19, 27, 21),
		Card = Color3.fromRGB(26, 36, 28), CardHover = Color3.fromRGB(34, 47, 37),
		Stroke = Color3.fromRGB(52, 70, 56), Divider = Color3.fromRGB(36, 48, 38),
		Text = Color3.fromRGB(240, 248, 240), TextDark = Color3.fromRGB(150, 175, 152),
		Accent = Color3.fromRGB(74, 200, 120), Accent2 = Color3.fromRGB(150, 220, 90),
	},
	Rose = {
		Main = Color3.fromRGB(21, 13, 19), Second = Color3.fromRGB(29, 19, 27),
		Card = Color3.fromRGB(38, 26, 35), CardHover = Color3.fromRGB(48, 33, 44),
		Stroke = Color3.fromRGB(72, 48, 64), Divider = Color3.fromRGB(50, 34, 45),
		Text = Color3.fromRGB(250, 240, 246), TextDark = Color3.fromRGB(180, 150, 168),
		Accent = Color3.fromRGB(255, 110, 170), Accent2 = Color3.fromRGB(190, 120, 255),
	},
	Light = {
		Main = Color3.fromRGB(243, 245, 250), Second = Color3.fromRGB(252, 252, 254),
		Card = Color3.fromRGB(255, 255, 255), CardHover = Color3.fromRGB(240, 243, 250),
		Stroke = Color3.fromRGB(214, 218, 228), Divider = Color3.fromRGB(232, 235, 242),
		Text = Color3.fromRGB(26, 28, 36), TextDark = Color3.fromRGB(118, 124, 140),
		Accent = Color3.fromRGB(70, 110, 240), Accent2 = Color3.fromRGB(140, 90, 240),
	},
	Mono = {
		Main = Color3.fromRGB(17, 17, 17), Second = Color3.fromRGB(23, 23, 23),
		Card = Color3.fromRGB(30, 30, 30), CardHover = Color3.fromRGB(38, 38, 38),
		Stroke = Color3.fromRGB(60, 60, 60), Divider = Color3.fromRGB(44, 44, 44),
		Text = Color3.fromRGB(240, 240, 240), TextDark = Color3.fromRGB(150, 150, 150),
		Accent = Color3.fromRGB(225, 225, 225), Accent2 = Color3.fromRGB(160, 160, 160),
	},
}

local StatusColors = {
	Success = Color3.fromRGB(58, 190, 118),
	Warning = Color3.fromRGB(245, 178, 60),
	Danger = Color3.fromRGB(244, 92, 96),
	Info = Color3.fromRGB(88, 132, 255),
}

------------------------------------------------------------------------------
-- [ 8 ] 库主体
------------------------------------------------------------------------------

local OrionLib = {
	Version = "2.0.0",
	Elements = {},
	ThemeObjects = {},
	AccentObjects = {},
	Interactions = {},
	HoverState = {},
	Connections = {},
	Flags = {},
	Themes = DefaultThemes,
	RefreshHandlers = {},
	LangHandlers = {},
	SelectedTheme = "Dark",
	Folder = nil,
	SaveCfg = false,
	AutoSave = false,
	Language = "zh",
	FlagChanged = Signal(),
	Window = nil,
}

OrionLib.StatusColors = StatusColors

------------------------------------------------------------------------------
-- [ 9 ] ScreenGui 创建
------------------------------------------------------------------------------

local Orion = Create("ScreenGui", {
	Name = "Orion",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 9999,
})

local function ProtectGui(Gui)
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		SafeCall(syn.protect_gui, Gui)
	end
end

ProtectGui(Orion)

do
	local Parent = GetGuiParent()
	local Ok = pcall(function() Orion.Parent = Parent end)
	if not Ok and Parent ~= game:GetService("CoreGui") then
		pcall(function() Orion.Parent = game:GetService("CoreGui") end)
	end
	if not Orion.Parent then
		pcall(function() Orion.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
	end
	local Container = Orion.Parent
	if Container then
		pcall(function()
			for _, Interface in ipairs(Container:GetChildren()) do
				if Interface ~= Orion and Interface.Name == Orion.Name and Interface:IsA("ScreenGui") then
					Interface:Destroy()
				end
			end
		end)
	end
end

function OrionLib:IsRunning()
	if type(gethui) == "function" then
		local Ok, Result = pcall(gethui)
		if Ok and Result then return Orion.Parent == Result end
	end
	return Orion.Parent ~= nil
end

local function AddConnection(Signal_, Function)
	if not OrionLib:IsRunning() then return nil end
	local Connection = Signal_:Connect(Function)
	table.insert(OrionLib.Connections, Connection)
	return Connection
end

TaskSpawn(function()
	while OrionLib:IsRunning() do
		TaskWait(0.5)
	end
	for _, Connection in ipairs(OrionLib.Connections) do
		pcall(function() Connection:Disconnect() end)
	end
	table.clear(OrionLib.Connections)
end)

------------------------------------------------------------------------------
-- [ 10 ] 主题 API
------------------------------------------------------------------------------

local ThemeProperty = {
	Main = "BackgroundColor3", Second = "BackgroundColor3", Card = "BackgroundColor3",
	CardHover = "BackgroundColor3", Stroke = "Color", Divider = "BackgroundColor3",
	Text = "TextColor3", TextDark = "TextColor3", Accent = "BackgroundColor3",
	Success = "BackgroundColor3", Warning = "BackgroundColor3", Danger = "BackgroundColor3",
}

local function CurrentTheme()
	return OrionLib.Themes[OrionLib.SelectedTheme] or OrionLib.Themes.Dark
end

function OrionLib:ThemeColor(Token)
	local Theme = CurrentTheme()
	return Theme[Token] or Color3.new(1, 1, 1)
end

local function InferProperty(Object, Token)
	if Object:IsA("UIStroke") then return "Color" end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then return "TextColor3" end
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return "ImageColor3" end
	if Object:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
	return ThemeProperty[Token] or "BackgroundColor3"
end

local function AddThemeObject(Object, Token, Property)
	if not Token then return Object end
	OrionLib.ThemeObjects[Token] = OrionLib.ThemeObjects[Token] or {}
	local Entry = {
		Object = Object,
		Property = Property or InferProperty(Object, Token),
		Token = Token,
	}
	table.insert(OrionLib.ThemeObjects[Token], Entry)
	local Color = CurrentTheme()[Token]
	if Color then
		pcall(function() Object[Entry.Property] = Color end)
	end
	return Object
end

local function AddAccentObject(Object, Property, Mode)
	table.insert(OrionLib.AccentObjects, {
		Object = Object,
		Property = Property,
		Mode = Mode or "color",
	})
	local Theme = CurrentTheme()
	if Mode == "gradient" then
		pcall(function()
			Object.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
		end)
	else
		pcall(function() Object[Property] = Theme.Accent end)
	end
	return Object
end

-- 强调色渐变 ( 左 → 右 )
local function AccentGradient(Object, Rotation)
	return Create("UIGradient", {
		Rotation = Rotation or 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, CurrentTheme().Accent),
			ColorSequenceKeypoint.new(1, CurrentTheme().Accent2),
		}),
		Parent = Object,
	})
end

local function RegisterInteraction(Object, BaseToken, HoverToken)
	OrionLib.Interactions[Object] = { Base = BaseToken, Hover = HoverToken }
	return Object
end

function OrionLib:ApplyTheme()
	local Theme = CurrentTheme()
	for Token, Entries in pairs(OrionLib.ThemeObjects) do
		local Color = Theme[Token]
		if Color then
			for _, Entry in ipairs(Entries) do
				if Entry.Object then
					local HoverEntry = OrionLib.Interactions[Entry.Object]
					local Target = Color
					if HoverEntry and OrionLib.HoverState[Entry.Object] and Theme[HoverEntry.Hover] then
						Target = Theme[HoverEntry.Hover]
					end
					if Entry.Object.Parent then
						pcall(function() Entry.Object[Entry.Property] = Target end)
					end
				end
			end
		end
	end
	for _, Entry in ipairs(OrionLib.AccentObjects) do
		if Entry.Object and Entry.Object.Parent then
			if Entry.Mode == "gradient" then
				pcall(function()
					Entry.Object.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
				end)
			else
				pcall(function() Entry.Object[Entry.Property] = Theme.Accent end)
			end
		end
	end
	-- 让有状态的组件 ( 开关 / 下拉选中项 等 ) 重新渲染自身配色
	for _, Handler in ipairs(OrionLib.RefreshHandlers) do
		SafeCall(Handler)
	end
	SafeCall(OrionLib.ThemeChangedCallback)
end

local function OnThemeRefresh(Handler)
	table.insert(OrionLib.RefreshHandlers, Handler)
	return Handler
end

function OrionLib:AddTheme(Name, Theme)
	if type(Name) ~= "string" or type(Theme) ~= "table" then return false end
	local Base = {}
	for Key, Value in pairs(DefaultThemes.Dark) do Base[Key] = Value end
	for Key, Value in pairs(Theme) do Base[Key] = Value end
	OrionLib.Themes[Name] = Base
	return true
end

function OrionLib:GetThemes()
	local Names = {}
	for Name in pairs(OrionLib.Themes) do
		table.insert(Names, Name)
	end
	table.sort(Names)
	return Names
end

function OrionLib:SetTheme(NameOrTheme, Accent)
	if type(NameOrTheme) == "table" then
		OrionLib:AddTheme("Custom", NameOrTheme)
		OrionLib.SelectedTheme = "Custom"
	elseif type(NameOrTheme) == "string" then
		if not OrionLib.Themes[NameOrTheme] then
			warn("[OrionLib] 未知主题: " .. NameOrTheme)
			return false
		end
		OrionLib.SelectedTheme = NameOrTheme
	end
	if Accent then
		local Theme = CurrentTheme()
		Theme.Accent = Accent
		Theme.Accent2 = ShadeColor(Accent, 0.22)
	end
	OrionLib:ApplyTheme()
	return true
end

function OrionLib:SetAccent(Color)
	if typeof(Color) ~= "Color3" then return false end
	local Theme = CurrentTheme()
	Theme.Accent = Color
	Theme.Accent2 = ShadeColor(Color, 0.22)
	OrionLib:ApplyTheme()
	return true
end

function OrionLib:GetAccent()
	return CurrentTheme().Accent
end

function OrionLib:SetLanguage(Language)
	if Lang[Language] then
		SelectedLanguage = Language
		OrionLib.Language = Language
		for _, Handler in ipairs(OrionLib.LangHandlers) do
			SafeCall(Handler)
		end
		return true
	end
	return false
end

local function OnLanguageRefresh(Handler)
	table.insert(OrionLib.LangHandlers, Handler)
	return Handler
end

------------------------------------------------------------------------------
-- [ 11 ] 组件工厂 ( 兼容原版 OrionLib.Elements.* )
------------------------------------------------------------------------------

local function CreateElement(ElementName, ElementFunction)
	OrionLib.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	return OrionLib.Elements[ElementName](...)
end

CreateElement("Corner", function(Scale, Offset)
	return Create("UICorner", { CornerRadius = UDim.new(Scale or 0, Offset or 10) })
end)

CreateElement("Stroke", function(Color, Thickness)
	return Create("UIStroke", {
		Color = Color or Color3.new(1, 1, 1),
		Thickness = Thickness or 1,
	})
end)

CreateElement("List", function(Scale, Offset)
	return Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(Scale or 0, Offset or 0),
	})
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	return Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft = UDim.new(0, Left or 4),
		PaddingRight = UDim.new(0, Right or 4),
		PaddingTop = UDim.new(0, Top or 4),
	})
end)

CreateElement("TFrame", function()
	return Create("Frame", { BackgroundTransparency = 1 })
end)

CreateElement("Frame", function(Color)
	return Create("Frame", {
		BackgroundColor3 = Color or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	})
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	return Create("Frame", {
		BackgroundColor3 = Color or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(Scale or 0, Offset or 10) }),
	})
end)

CreateElement("Button", function()
	return Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	})
end)

CreateElement("ScrollFrame", function(Color, Width)
	return Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarImageColor3 = Color or Color3.new(1, 1, 1),
		ScrollBarThickness = Width or 3,
		ScrollBarImageTransparency = 0.4,
		MidImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
end)

CreateElement("Image", function(ImageID)
	local Image = Create("ImageLabel", {
		Image = ImageID,
		BackgroundTransparency = 1,
	})
	local Mapped = GetIcon(ImageID)
	if Mapped then Image.Image = Mapped end
	return Image
end)

CreateElement("ImageButton", function(ImageID)
	return Create("ImageButton", {
		Image = ImageID,
		BackgroundTransparency = 1,
	})
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	return Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 15,
		Font = Enum.Font.Gotham,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end)

-- 中文字体更清晰的字重回退
local function Font(Name)
	local Fonts = Enum.Font
	local Order = {
		Black = { "GothamBlack", "GothamBold", "GothamSemibold", "SourceSansBold", "SourceSansSemibold" },
		Bold = { "GothamBold", "GothamSemibold", "SourceSansBold", "SourceSansSemibold" },
		SemiBold = { "GothamSemibold", "GothamMedium", "SourceSansSemibold", "SourceSansSemiBold" },
		Medium = { "GothamMedium", "Gotham", "SourceSansRegular" },
		Regular = { "Gotham", "SourceSansRegular", "SourceSansLight" },
	}
	local Candidates = Order[Name] or Order.Regular
	for _, Candidate in ipairs(Candidates) do
		local Value = Fonts[Candidate]
		if Value then return Value end
	end
	return Fonts.Gotham
end

local Fonts = {
	Black = Font("Black"),
	Bold = Font("Bold"),
	SemiBold = Font("SemiBold"),
	Medium = Font("Medium"),
	Regular = Font("Regular"),
}

OrionLib.Fonts = Fonts

------------------------------------------------------------------------------
-- [ 12 ] 拖拽管理器 ( 全局单连接, 替代原版每个组件一条 RenderStepped 的做法 )
------------------------------------------------------------------------------

local DragState = nil

AddConnection(UserInputService.InputChanged, function(Input)
	if not DragState then return end
	local InputType = Input.UserInputType
	if InputType == Enum.UserInputType.MouseMovement or InputType == Enum.UserInputType.Touch then
		if DragState.Update then
			SafeCall(DragState.Update, Input.Position, Input)
		end
	end
end)

AddConnection(UserInputService.InputEnded, function(Input)
	if not DragState then return end
	local InputType = Input.UserInputType
	if InputType == Enum.UserInputType.MouseButton1 or InputType == Enum.UserInputType.Touch then
		local State = DragState
		DragState = nil
		if State.Finish then
			SafeCall(State.Finish, Input.Position, Input)
		end
	end
end)

local function BindDrag(Area, OnUpdate, OnFinish)
	AddConnection(Area.InputBegan, function(Input)
		local InputType = Input.UserInputType
		if InputType == Enum.UserInputType.MouseButton1 or InputType == Enum.UserInputType.Touch then
			DragState = { Update = OnUpdate, Finish = OnFinish }
			if OnUpdate then SafeCall(OnUpdate, Input.Position, Input) end
		end
	end)
	AddConnection(Area.InputEnded, function(Input)
		local InputType = Input.UserInputType
		if DragState and (InputType == Enum.UserInputType.MouseButton1 or InputType == Enum.UserInputType.Touch) then
			local State = DragState
			DragState = nil
			if State.Finish then SafeCall(State.Finish, Input.Position, Input) end
		end
	end)
end

------------------------------------------------------------------------------
-- [ 13 ] 涟漪 / 悬停 / 按压反馈
------------------------------------------------------------------------------

local function Ripple(Parent, Position, Color)
	if not Parent then return end
	local Diameter = math.max(Parent.AbsoluteSize.X, Parent.AbsoluteSize.Y) * 1.7
	local Origin = Position or Vector2.new(Parent.AbsoluteSize.X / 2, Parent.AbsoluteSize.Y / 2)
	local Dot = Create("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(Origin.X, Origin.Y),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color or Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = Parent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	Tween(Dot, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(Diameter, Diameter),
		BackgroundTransparency = 1,
	})
	TaskDelay(0.6, function()
		if Dot and Dot.Parent then Dot:Destroy() end
	end)
end

-- 给卡片类组件挂上 悬停 / 按压 / 涟漪 三件套
local function MakeInteractive(Button, Card, Config)
	Config = Config or {}
	local Scale = EnsureScale(Card, 1)
	local HoverToken = Config.HoverToken or "CardHover"
	local BaseToken = Config.BaseToken or "Card"
	local Accent = Config.RippleColor or CurrentTheme().Accent

	RegisterInteraction(Card, BaseToken, HoverToken)

	local function SetHover(State)
		OrionLib.HoverState[Card] = State
		local Theme = CurrentTheme()
		local Target = State and (Theme[HoverToken] or Theme[BaseToken]) or Theme[BaseToken]
		if not Config.KeepColor then
			Tween(Card, TI.Fast, { BackgroundColor3 = Target })
		end
		if Card:FindFirstChildOfClass("UIStroke") and not Config.KeepStroke then
			Tween(Card:FindFirstChildOfClass("UIStroke"), TI.Fast, { Transparency = State and 0.25 or 0.5 })
		end
		if Config.OnHover then SafeCall(Config.OnHover, State) end
	end

	AddConnection(Button.MouseEnter, function() SetHover(true) end)
	AddConnection(Button.MouseLeave, function()
		SetHover(false)
		Tween(Scale, TI.Fast, { Scale = 1 })
	end)

	AddConnection(Button.InputBegan, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Tween(Scale, TI.Press, { Scale = 0.985 })
			if Config.Ripple ~= false then
				Ripple(Card, Vector2.new(Input.Position.X - Card.AbsolutePosition.X, Input.Position.Y - Card.AbsolutePosition.Y), Accent)
			end
		end
	end)

	AddConnection(Button.InputEnded, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Tween(Scale, TI.Spring, { Scale = 1 })
		end
	end)

	return Scale
end

------------------------------------------------------------------------------
-- [ 14 ] 页面转场容器 ( CanvasGroup 优先, 不支持时自动降级 )
------------------------------------------------------------------------------

local HasCanvasGroup = pcall(function()
	local Test = Instance.new("CanvasGroup")
	Test:Destroy()
end)

local function CreateGroup(Properties)
	if HasCanvasGroup then
		local Group = Create("CanvasGroup", Properties)
		if not Properties or Properties.GroupTransparency == nil then
			Group.GroupTransparency = 0
		end
		return Group
	end
	return Create("Frame", Properties)
end

local function FadeGroup(Group, Info, Transparency)
	if not Group then return end
	if HasCanvasGroup and Group:IsA("CanvasGroup") then
		Tween(Group, Info, { GroupTransparency = Transparency })
	end
end

------------------------------------------------------------------------------
-- [ 15 ] 分隔线 / 投影
------------------------------------------------------------------------------

local function FadeDivider(Parent, Properties)
	local Line = Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
	})
	for Property, Value in pairs(Properties or {}) do
		Line[Property] = Value
	end
	Create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0),
			NumberSequenceKeypoint.new(0.88, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = Line,
	})
	Line.Parent = Parent
	AddThemeObject(Line, "Divider", "BackgroundColor3")
	return Line
end

------------------------------------------------------------------------------
-- [ 16 ] 通知系统 ( 序列入场 / 类型化 / 悬停暂停 / 进度条 / 按钮 / 手动关闭 )
------------------------------------------------------------------------------

local NotificationHolder = Create("Frame", {
	Name = "NotificationHolder",
	Parent = Orion,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -22, 1, -22),
	Size = UDim2.new(0, 344, 1, -40),
	BackgroundTransparency = 1,
}, {
	Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 8),
	}),
})

local NotificationIndex = 0
local ActiveNotifications = {}

local NotificationTypeMeta = {
	info    = { Token = "Info",    Title = { zh = "提示", en = "Info" } },
	success = { Token = "Success", Title = { zh = "成功", en = "Success" } },
	warning = { Token = "Warning", Title = { zh = "警告", en = "Warning" } },
	error   = { Token = "Danger",  Title = { zh = "错误", en = "Error" } },
}

local function TypeColor(Token)
	local Theme = CurrentTheme()
	return Theme[Token] or StatusColors[Token] or CurrentTheme().Accent
end

local function BuildTypeIcon(Chip, TypeName, Color)
	if TypeName == "success" then
		IconKit.Check(Chip, 16, Color, 2)
	elseif TypeName == "error" then
		IconKit.Close(Chip, 16, Color, 2)
	elseif TypeName == "warning" then
		Create("TextLabel", {
			Name = "Icon",
			Text = "!",
			TextColor3 = Color,
			TextSize = 15,
			Font = Fonts.Black,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = Chip,
		})
	else
		Create("TextLabel", {
			Name = "Icon",
			Text = "i",
			TextColor3 = Color,
			TextSize = 14,
			Font = Fonts.Black,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = Chip,
		})
	end
end

local function CreateNotification(Config)
	Config = Config or {}
	local TypeName = tostring(Config.Type or "info"):lower()
	local Meta = NotificationTypeMeta[TypeName] or NotificationTypeMeta.info
	local Accent = Config.Color or TypeColor(Meta.Token)
	local Duration = tonumber(Config.Time) or 10
	if Duration <= 0 then Duration = math.huge end

	NotificationIndex = NotificationIndex + 1

	local Root = Create("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = NotificationIndex,
		Parent = NotificationHolder,
	})

	local Card = CreateGroup({
		Name = "Card",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 46, 0, 0),
		BackgroundColor3 = CurrentTheme().Card,
		ClipsDescendants = true,
		Parent = Root,
	})
	if HasCanvasGroup then Card.GroupTransparency = 1 end
	Create("UICorner", { CornerRadius = UDim.new(0, 13), Parent = Card })
	AddThemeObject(Card, "Card", "BackgroundColor3")
	local CardStroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = 0.35,
		Parent = Card,
	})
	AddThemeObject(CardStroke, "Stroke", "Color")

	-- 内层容器承担 UIListLayout, 让 Card 自身可以自由放置涟漪等装饰
	local Inner = Create("Frame", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = Card,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 13),
			PaddingBottom = UDim.new(0, 11),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	-- 顶部标题行
	local Header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = Inner,
	})

	local Chip = Create("Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Accent,
		BackgroundTransparency = 0.86,
		Parent = Header,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})
	Create("UIStroke", {
		Color = Accent,
		Thickness = 1,
		Transparency = 0.6,
		Parent = Chip,
	})

	local IconImage = Config.Icon or Config.Image
	if IconImage then
		local Icon = BuildIcon(Chip, IconImage, 15, Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		if not Icon then
			BuildTypeIcon(Chip, TypeName, Accent)
		end
	else
		BuildTypeIcon(Chip, TypeName, Accent)
	end

	local Title = Create("TextLabel", {
		Name = "Title",
		Text = tostring(Config.Name or Config.Title or (Meta.Title[SelectedLanguage] or Meta.Title.zh)),
		TextColor3 = CurrentTheme().Text,
		TextSize = 13.5,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Parent = Header,
	})
	AddThemeObject(Title, "Text", "TextColor3")

	local CloseButton = Create("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -22, 0, 1),
		Parent = Header,
	})
	local CloseIcon = IconKit.Close(CloseButton, 12, CurrentTheme().TextDark, 1.6)
	CloseButton.MouseEnter:Connect(function()
		SetIconColor(CloseIcon, CurrentTheme().Text)
		Tween(CloseButton, TI.Fast, { BackgroundTransparency = 0.88, BackgroundColor3 = CurrentTheme().CardHover })
	end)
	CloseButton.MouseLeave:Connect(function()
		SetIconColor(CloseIcon, CurrentTheme().TextDark)
		Tween(CloseButton, TI.Fast, { BackgroundTransparency = 1 })
	end)

	local Content = Create("TextLabel", {
		Name = "Content",
		Text = tostring(Config.Content or Config.Description or ""),
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 12.5,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = Inner,
	})
	AddThemeObject(Content, "TextDark", "TextColor3")

	-- 按钮行 ( 可选 )
	local ButtonsHolder
	if type(Config.Buttons) == "table" and #Config.Buttons > 0 then
		ButtonsHolder = Create("Frame", {
			Name = "Buttons",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = Inner,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		})
	end

	-- 底部进度条
	local Track = Create("Frame", {
		Name = "Progress",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = CurrentTheme().Divider,
		BackgroundTransparency = 0.35,
		LayoutOrder = 4,
		Parent = Inner,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	AddThemeObject(Track, "Divider", "BackgroundColor3")
	local Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Accent,
		BorderSizePixel = 0,
		Parent = Track,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	local Notification = {
		Type = TypeName,
		Destroyed = false,
		Config = Config,
	}

	local Hovering = false

	local function Close(withAnimation)
		if Notification.Destroyed then return end
		Notification.Destroyed = true
		local Index = table.find(ActiveNotifications, Notification)
		if Index then table.remove(ActiveNotifications, Index) end
		if withAnimation == false then
			Root:Destroy()
			return
		end
		Tween(Card, TI.Smooth, {
			Position = UDim2.new(0, 60, 0, 0),
		})
		FadeGroup(Card, TI.Smooth, 1)
		Tween(CardStroke, TI.Smooth, { Transparency = 1 })
		Tween(Track, TI.Smooth, { BackgroundTransparency = 1 })
		-- 关掉自动尺寸后再收起高度, 让下方通知平滑上移
		Card.AutomaticSize = Enum.AutomaticSize.None
		Card.Size = UDim2.new(1, 0, 0, Card.AbsoluteSize.Y)
		Tween(Card, TI.Smooth, { Size = UDim2.new(1, 0, 0, 0) })
		TaskDelay(0.42, function()
			if Root and Root.Parent then Root:Destroy() end
		end)
	end

	function Notification:Close()
		Close(true)
	end

	function Notification:SetContent(Text)
		Content.Text = tostring(Text or "")
	end

	function Notification:SetTitle(Text)
		Title.Text = tostring(Text or "")
	end

	if ButtonsHolder then
		for Index, ButtonConfig in ipairs(Config.Buttons) do
			local ButtonColor = CurrentTheme().CardHover
			local Button = Create("TextButton", {
				Name = "Button" .. Index,
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = ButtonColor,
				Size = UDim2.fromOffset(80, 26),
				LayoutOrder = Index,
				Parent = ButtonsHolder,
			}, {
				Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
			local ButtonLabel = Create("TextLabel", {
				Text = tostring(ButtonConfig.Name or L("Confirm")),
				TextColor3 = CurrentTheme().Text,
				TextSize = 12,
				Font = Fonts.SemiBold,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Parent = Button,
			})
			AddThemeObject(ButtonLabel, "Text", "TextColor3")
			Button.Size = UDim2.fromOffset(ButtonLabel.TextBounds.X + 24, 26)
			Button.MouseEnter:Connect(function()
				Tween(Button, TI.Fast, { BackgroundColor3 = CurrentTheme().Stroke })
			end)
			Button.MouseLeave:Connect(function()
				Tween(Button, TI.Fast, { BackgroundColor3 = CurrentTheme().CardHover })
			end)
			Button.MouseButton1Click:Connect(function()
				SafeCall(ButtonConfig.Callback)
				if ButtonConfig.Close ~= false then Close(true) end
			end)
		end
	end

	Card.MouseEnter:Connect(function() Hovering = true end)
	Card.MouseLeave:Connect(function() Hovering = false end)
	CloseButton.MouseButton1Click:Connect(function() Close(true) end)
	Card.InputBegan:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Ripple(Card, Vector2.new(Input.Position.X - Card.AbsolutePosition.X, Input.Position.Y - Card.AbsolutePosition.Y), Accent)
		end
	end)

	-- 入场动画
	Tween(Card, TI.Spring, { Position = UDim2.new(0, 0, 0, 0) })
	FadeGroup(Card, TI.Smooth, 0)

	table.insert(ActiveNotifications, Notification)

	TaskSpawn(function()
		local Elapsed = 0
		local Interval = 0.05
		while not Notification.Destroyed and Elapsed < Duration do
			TaskWait(Interval)
			if not Root.Parent then break end
			if not Hovering then
				Elapsed = Elapsed + Interval
				if Duration ~= math.huge then
					Fill.Size = UDim2.fromScale(math.max(0, 1 - Elapsed / Duration), 1)
				end
			end
		end
		if not Notification.Destroyed then
			Close(true)
		end
	end)

	return Notification
end

function OrionLib:MakeNotification(Config)
	local Ok, Result = pcall(CreateNotification, Config)
	if not Ok then
		warn("[OrionLib] 通知创建失败: " .. tostring(Result))
		return nil
	end
	return Result
end

OrionLib.Notify = OrionLib.MakeNotification

function OrionLib:ClearNotifications()
	local Snapshot = {}
	for _, Notification in ipairs(ActiveNotifications) do
		table.insert(Snapshot, Notification)
	end
	for _, Notification in ipairs(Snapshot) do
		SafeCall(Notification.Close, Notification, false)
	end
	table.clear(ActiveNotifications)
	for _, Child in ipairs(NotificationHolder:GetChildren()) do
		if Child:IsA("Frame") then Child:Destroy() end
	end
end

------------------------------------------------------------------------------
-- [ 17 ] 窗口外壳
------------------------------------------------------------------------------

-- 前向声明: 组件工厂在文件后段定义, 由 MakeTab / AddSection 调用
local BuildElements
local BuildSection

local ViewportSize
do
	local Camera = workspace.CurrentCamera
	ViewportSize = Camera and Camera.ViewportSize or Vector2.new(1920, 1080)
end

local function GetViewport()
	local Camera = workspace.CurrentCamera
	if Camera then return Camera.ViewportSize end
	return ViewportSize
end

-- 锁定分页返回的占位元件: 调用任何方法都不会报错, 只是什么都不做
local LockedElementMethods = {
	"Set", "SetValue", "Select", "Deselect", "SetValues", "Clear", "Open", "Close", "Refresh",
	"SetValueName", "SetRange", "SetName", "SetTitle", "SetIcon", "Focus", "Destroy", "Toggle",
	"SetCollapsed", "SetColor", "SetCaption", "SetLoading",
}
local LockedElementNames = {
	"AddLabel", "AddParagraph", "AddButton", "AddToggle", "AddSlider", "AddDropdown", "AddBind",
	"AddKeybind", "AddTextbox", "AddInput", "AddColorpicker", "AddDivider", "AddSpace",
	"AddImage", "AddSection",
}

local function MakeLockedElement()
	local Dummy
	local function Return() return Dummy end
	Dummy = {
		Type = "Locked",
		Value = nil,
		Flag = nil,
		Save = false,
		Get = function() return nil end,
		GetSelected = function() return {} end,
		IsCollapsed = function() return false end,
		IsSelected = function() return false end,
	}
	for _, Method in ipairs(LockedElementMethods) do
		if Dummy[Method] == nil then
			Dummy[Method] = Return
		end
	end
	return Dummy
end

local function MakeLockedElements()
	local Functions = {}
	for _, Name in ipairs(LockedElementNames) do
		Functions[Name] = function() return MakeLockedElement() end
	end
	return Functions
end

function OrionLib:MakeWindow(WindowConfig)
	WindowConfig = WindowConfig or {}

	local Config = {
		Name = WindowConfig.Name or "Orion Library",
		Subtitle = WindowConfig.Subtitle or "",
		Icon = WindowConfig.Icon,
		ShowIcon = WindowConfig.ShowIcon ~= false and WindowConfig.Icon ~= nil,
		Size = WindowConfig.Size or UDim2.fromOffset(640, 430),
		Position = WindowConfig.Position,
		Accent = WindowConfig.Accent,
		Theme = WindowConfig.Theme,
		ToggleKey = WindowConfig.ToggleKey or Enum.KeyCode.RightShift,
		Draggable = WindowConfig.Draggable ~= false,
		IntroEnabled = WindowConfig.IntroEnabled ~= false,
		IntroText = WindowConfig.IntroText or WindowConfig.Name or "Orion Library",
		IntroIcon = WindowConfig.IntroIcon or WindowConfig.Icon,
		IntroDuration = tonumber(WindowConfig.IntroDuration) or 1.5,
		ConfigFolder = WindowConfig.ConfigFolder or WindowConfig.Name or "Orion",
		SaveConfig = WindowConfig.SaveConfig == true,
		AutoSave = WindowConfig.AutoSave ~= false,
		HidePremium = WindowConfig.HidePremium or false,
		ShowCloseNotification = WindowConfig.ShowCloseNotification ~= false,
		CloseCallback = WindowConfig.CloseCallback or function() end,
		Search = WindowConfig.Search == true,
		CloseOnEscape = WindowConfig.CloseOnEscape == true,
		Footer = WindowConfig.Footer or "",
	}

	if type(Config.ToggleKey) == "string" then
		local Key = Enum.KeyCode[Config.ToggleKey]
		Config.ToggleKey = Key or Enum.KeyCode.RightShift
	end

	if Config.Theme then OrionLib:SetTheme(Config.Theme) end
	if Config.Accent then OrionLib:SetAccent(Config.Accent) end

	OrionLib.Folder = Config.ConfigFolder
	OrionLib.SaveCfg = Config.SaveConfig
	OrionLib.AutoSave = Config.SaveConfig and Config.AutoSave

	if Config.SaveConfig and type(makefolder) == "function" and type(isfolder) == "function" then
		SafeCall(function()
			if not isfolder(Config.ConfigFolder) then
				makefolder(Config.ConfigFolder)
			end
		end)
	end

	local Tabs = {}
	local TabByName = {}
	local SelectedTab = nil
	local Minimized = false
	local UIHidden = false
	local ToggleKeyName = Config.ToggleKey.Name
	local Window = { Tabs = {}, Config = Config, Name = "OrionWindow" }
	local IntroPlayed = false

	--------------------------------------------------------------------------
	-- 窗口骨架
	--------------------------------------------------------------------------

	-- WindowRoot: 外层容器 ( 不裁剪, 用来承载投影 + 缩放 )
	-- MainWindow: 内层 CanvasGroup, 负责整窗淡入淡出 ( CanvasGroup 会裁剪子对象, 所以投影必须放在外层 )
	local WindowRoot = Create("Frame", {
		Name = "WindowRoot",
		Parent = Orion,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Size = Config.Size,
	})

	local MainWindow = CreateGroup({
		Name = "MainWindow",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 2,
		Parent = WindowRoot,
	})

	local ShadowOuter = Create("Frame", {
		Name = "ShadowOuter",
		Size = UDim2.new(1, 26, 1, 30),
		Position = UDim2.fromOffset(-13, -11),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = WindowRoot,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 26) }) })

	local ShadowInner = Create("Frame", {
		Name = "ShadowInner",
		Size = UDim2.new(1, 14, 1, 18),
		Position = UDim2.fromOffset(-7, -5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.74,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = WindowRoot,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 20) }) })

	local WindowScale = EnsureScale(WindowRoot, 1)

	local Body = Create("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CurrentTheme().Main,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = MainWindow,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 14) }) })
	AddThemeObject(Body, "Main", "BackgroundColor3")

	local BodyStroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = 0.4,
		Parent = Body,
	})
	AddThemeObject(BodyStroke, "Stroke", "Color")

	-- 顶部强调色光晕
	local TopGlow = Create("Frame", {
		Name = "TopGlow",
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = CurrentTheme().Accent,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = Body,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.86),
				NumberSequenceKeypoint.new(0.55, 0.96),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	AddAccentObject(TopGlow, "BackgroundColor3", "color")

	-- 顶部强调色细线
	local AccentLine = Create("Frame", {
		Name = "AccentLine",
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = CurrentTheme().Accent,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = Body,
	}, { AccentGradient(nil, 0) })
	AddAccentObject(AccentLine:FindFirstChildOfClass("UIGradient"), "Color", "gradient")

	local TopBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		ZIndex = 4,
		Parent = Body,
	})

	local TopDivider = Create("Frame", {
		Name = "TopDivider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
		Parent = TopBar,
	})
	AddThemeObject(TopDivider, "Divider", "BackgroundColor3")

	-- 可拖动区域 ( 避开右侧窗口按钮 )
	local DragPoint = Create("Frame", {
		Name = "DragPoint",
		Size = UDim2.new(1, -140, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = TopBar,
	})

	local IconOffset = 16
	local WindowIcon
	if Config.ShowIcon then
		WindowIcon = BuildIcon(TopBar, Config.Icon, 18, CurrentTheme().Text, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, Config.Subtitle ~= "" and -8 or 0),
		})
	end
	if WindowIcon then IconOffset = 42 end

	local Title = Create("TextLabel", {
		Name = "Title",
		Text = Config.Name,
		TextColor3 = CurrentTheme().Text,
		TextSize = 14.5,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, IconOffset, 0.5, Config.Subtitle ~= "" and -8 or 0),
		Size = UDim2.new(0.6, -IconOffset, 0, 18),
		Parent = TopBar,
	})
	AddThemeObject(Title, "Text", "TextColor3")

	local Subtitle = Create("TextLabel", {
		Name = "Subtitle",
		Text = Config.Subtitle,
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 11,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, IconOffset, 0.5, 9),
		Size = UDim2.new(0.6, -IconOffset, 0, 14),
		Visible = Config.Subtitle ~= "",
		Parent = TopBar,
	})
	AddThemeObject(Subtitle, "TextDark", "TextColor3")

	-- 窗口按钮: 最小化 / 关闭
	local MinimizeButton = Create("TextButton", {
		Name = "Minimize",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -78, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = TopBar,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local MinimizeIcon = IconKit.Minimize(MinimizeButton, 15, CurrentTheme().TextDark, 1.6)

	local CloseButton = Create("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -44, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = TopBar,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	local CloseIcon = IconKit.Close(CloseButton, 14, CurrentTheme().TextDark, 1.6)

	AddConnection(MinimizeButton.MouseEnter, function()
		SetIconColor(MinimizeIcon, CurrentTheme().Text)
		Tween(MinimizeButton, TI.Fast, { BackgroundColor3 = CurrentTheme().CardHover, BackgroundTransparency = 0 })
	end)
	AddConnection(MinimizeButton.MouseLeave, function()
		SetIconColor(MinimizeIcon, CurrentTheme().TextDark)
		Tween(MinimizeButton, TI.Fast, { BackgroundTransparency = 1 })
	end)
	AddConnection(CloseButton.MouseEnter, function()
		SetIconColor(CloseIcon, StatusColors.Danger)
		Tween(CloseButton, TI.Fast, { BackgroundColor3 = StatusColors.Danger, BackgroundTransparency = 0.86 })
	end)
	AddConnection(CloseButton.MouseLeave, function()
		SetIconColor(CloseIcon, CurrentTheme().TextDark)
		Tween(CloseButton, TI.Fast, { BackgroundTransparency = 1 })
	end)

	--------------------------------------------------------------------------
	-- 侧栏
	--------------------------------------------------------------------------

	local Sidebar = Create("Frame", {
		Name = "Sidebar",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(0, 172, 1, -90),
		BackgroundColor3 = CurrentTheme().Second,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Body,
	})
	AddThemeObject(Sidebar, "Second", "BackgroundColor3")

	local SidebarLine = Create("Frame", {
		Name = "SidebarDivider",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
		Parent = Sidebar,
	})
	AddThemeObject(SidebarLine, "Divider", "BackgroundColor3")

	local SearchBox
	local TabHolderTop = 10
	if Config.Search then
		local SearchFrame = Create("Frame", {
			Name = "TabSearch",
			Position = UDim2.new(0, 10, 0, 10),
			Size = UDim2.new(1, -20, 0, 30),
			BackgroundColor3 = CurrentTheme().Card,
			Parent = Sidebar,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
		AddThemeObject(SearchFrame, "Card", "BackgroundColor3")
		Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.6, Parent = SearchFrame })
		IconKit.Search(SearchFrame, 13, CurrentTheme().TextDark, 1.4).Position = UDim2.new(0, 15, 0.5, 0)
		SearchBox = Create("TextBox", {
			Name = "Input",
			Text = "",
			PlaceholderText = L("Search"),
			PlaceholderColor3 = CurrentTheme().TextDark,
			TextColor3 = CurrentTheme().Text,
			TextSize = 12,
			Font = Fonts.Medium,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Position = UDim2.fromOffset(27, 0),
			Size = UDim2.new(1, -34, 1, 0),
			Parent = SearchFrame,
		})
		AddThemeObject(SearchBox, "Text", "TextColor3")
		TabHolderTop = 48
	end

	local TabHolder = Create("ScrollingFrame", {
		Name = "TabHolder",
		Position = UDim2.new(0, 0, 0, TabHolderTop),
		Size = UDim2.new(1, 0, 1, -(TabHolderTop + 6)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = CurrentTheme().Stroke,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = Sidebar,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 9),
			PaddingRight = UDim.new(0, 9),
		}),
	})

	local NoResult = Create("TextLabel", {
		Name = "NoResult",
		Text = L("NoResult"),
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 12,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextWrapped = true,
		Position = UDim2.new(0, 14, 0, TabHolderTop + 10),
		Size = UDim2.new(1, -28, 0, 30),
		Visible = false,
		Parent = Sidebar,
	})
	AddThemeObject(NoResult, "TextDark", "TextColor3")

	local IndicatorClip = Create("Frame", {
		Name = "IndicatorClip",
		Position = UDim2.new(0, 0, 0, TabHolderTop),
		Size = UDim2.new(0, 10, 1, -(TabHolderTop + 6)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = Sidebar,
	})

	local TabIndicator = Create("Frame", {
		Name = "TabIndicator",
		Size = UDim2.new(0, 3, 0, 18),
		Position = UDim2.new(0, 1, 0, 8),
		BackgroundColor3 = CurrentTheme().Accent,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = IndicatorClip,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	AddAccentObject(TabIndicator, "BackgroundColor3", "color")

	--------------------------------------------------------------------------
	-- 内容区
	--------------------------------------------------------------------------

	local ContentArea = Create("Frame", {
		Name = "ContentArea",
		Position = UDim2.new(0, 172, 0, 48),
		Size = UDim2.new(1, -172, 1, -90),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = Body,
	})

	--------------------------------------------------------------------------
	-- 底栏
	--------------------------------------------------------------------------

	local Footer = Create("Frame", {
		Name = "Footer",
		Position = UDim2.new(0, 0, 1, -42),
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = CurrentTheme().Second,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Body,
	})
	AddThemeObject(Footer, "Second", "BackgroundColor3")

	local FooterLine = Create("Frame", {
		Name = "FooterDivider",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
		Parent = Footer,
	})
	AddThemeObject(FooterLine, "Divider", "BackgroundColor3")

	local AvatarFrame = Create("Frame", {
		Name = "Avatar",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = CurrentTheme().Card,
		Parent = Footer,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	AddThemeObject(AvatarFrame, "Card", "BackgroundColor3")

	local Avatar = Create("ImageLabel", {
		Name = "Image",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(LocalPlayer.UserId) .. "&width=420&height=420&format=png",
		Parent = AvatarFrame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })

	TaskSpawn(function()
		local Ok, Thumbnail = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if Ok and Thumbnail and Avatar.Parent then
			Avatar.Image = Thumbnail
		end
	end)

	local DisplayName = Create("TextLabel", {
		Name = "DisplayName",
		Text = LocalPlayer.DisplayName,
		TextColor3 = CurrentTheme().Text,
		TextSize = 12,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 48, 0, 8),
		Size = UDim2.new(0.45, -48, 0, 14),
		Parent = Footer,
	})
	AddThemeObject(DisplayName, "Text", "TextColor3")

	local UserTag = Create("TextLabel", {
		Name = "UserTag",
		Text = "@" .. LocalPlayer.Name .. (Config.HidePremium and "" or "  ·  Premium"),
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 10.5,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 48, 0, 22),
		Size = UDim2.new(0.45, -48, 0, 12),
		Parent = Footer,
	})
	AddThemeObject(UserTag, "TextDark", "TextColor3")

	local StatusDot = Create("Frame", {
		Name = "StatusDot",
		Size = UDim2.fromOffset(7, 7),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -108, 0.5, 0),
		BackgroundColor3 = StatusColors.Success,
		BorderSizePixel = 0,
		Parent = Footer,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local StatusLabel = Create("TextLabel", {
		Name = "Status",
		Text = Config.Footer ~= "" and Config.Footer or L("Ready"),
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 11,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.new(0.45, -32, 1, 0),
		Parent = Footer,
	})
	AddThemeObject(StatusLabel, "TextDark", "TextColor3")

	local VersionLabel = Create("TextLabel", {
		Name = "Version",
		Text = "v" .. OrionLib.Version,
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 10.5,
		Font = Fonts.SemiBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, -11),
		Size = UDim2.new(0, 90, 0, 12),
		Parent = Footer,
	})
	AddThemeObject(VersionLabel, "TextDark", "TextColor3")

	--------------------------------------------------------------------------
	-- 位置
	--------------------------------------------------------------------------

	if Config.Position then
		WindowRoot.Position = Config.Position
	else
		local SizeX = Config.Size.X.Offset
		local SizeY = Config.Size.Y.Offset
		WindowRoot.Position = UDim2.new(0.5, -SizeX / 2, 0.5, -SizeY / 2)
	end

	function Window:Center()
		local CurrentSize = WindowRoot.AbsoluteSize
		WindowRoot.Position = UDim2.new(0.5, -CurrentSize.X / 2, 0.5, -CurrentSize.Y / 2)
		return Window
	end

	function Window:SetSize(Size)
		Config.Size = Size
		Tween(WindowRoot, TI.Smooth, { Size = Size })
		return Window
	end

	function Window:SetPosition(Position)
		WindowRoot.Position = Position
		return Window
	end

	--------------------------------------------------------------------------
	-- 拖动
	--------------------------------------------------------------------------

	if Config.Draggable then
		local DragOrigin, WindowOrigin
		local LastClick = 0
		AddConnection(DragPoint.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				DragOrigin = Vector2.new(Input.Position.X, Input.Position.Y)
				WindowOrigin = WindowRoot.Position
				Tween(WindowScale, TI.Normal, { Scale = 1.012 })
				Tween(ShadowOuter, TI.Normal, { BackgroundTransparency = 0.82 })
				local Now = os.clock()
				if Now - LastClick < 0.32 then
					LastClick = 0
					Window:Minimize()
				else
					LastClick = Now
				end
			end
		end)
		AddConnection(UserInputService.InputChanged, function(Input)
			if not DragOrigin then return end
			local InputType = Input.UserInputType
			if InputType ~= Enum.UserInputType.MouseMovement and InputType ~= Enum.UserInputType.Touch then return end
			local Position = Vector2.new(Input.Position.X, Input.Position.Y)
			local Delta = Position - DragOrigin
			local Viewport = GetViewport()
			local Size = WindowRoot.AbsoluteSize
			local AbsX = Viewport.X * WindowOrigin.X.Scale + WindowOrigin.X.Offset + Delta.X
			local AbsY = Viewport.Y * WindowOrigin.Y.Scale + WindowOrigin.Y.Offset + Delta.Y
			if AbsX < -Size.X + 100 then AbsX = -Size.X + 100 end
			if AbsX > Viewport.X - 100 then AbsX = Viewport.X - 100 end
			if AbsY < 0 then AbsY = 0 end
			if AbsY > Viewport.Y - 46 then AbsY = Viewport.Y - 46 end
			WindowRoot.Position = UDim2.new(
				WindowOrigin.X.Scale, AbsX - Viewport.X * WindowOrigin.X.Scale,
				WindowOrigin.Y.Scale, AbsY - Viewport.Y * WindowOrigin.Y.Scale
			)
		end)
		AddConnection(UserInputService.InputEnded, function(Input)
			if not DragOrigin then return end
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				DragOrigin = nil
				Tween(WindowScale, TI.Spring, { Scale = 1 })
				Tween(ShadowOuter, TI.Smooth, { BackgroundTransparency = 0.88 })
			end
		end)
	end

	--------------------------------------------------------------------------
	-- 显示 / 隐藏 / 最小化
	--------------------------------------------------------------------------

	local function SetVisible(State)
		if UIHidden == not State then return end
		UIHidden = not State
		if State then
			WindowRoot.Visible = true
			if HasCanvasGroup then MainWindow.GroupTransparency = 1 end
			Tween(ShadowOuter, TI.Smooth, { BackgroundTransparency = 0.88 })
			Tween(ShadowInner, TI.Smooth, { BackgroundTransparency = 0.74 })
			FadeGroup(MainWindow, TI.Smooth, 0)
			Tween(WindowScale, TI.Spring, { Scale = 1 })
		else
			FadeGroup(MainWindow, TI.Fast, 1)
			Tween(ShadowOuter, TI.Fast, { BackgroundTransparency = 1 })
			Tween(ShadowInner, TI.Fast, { BackgroundTransparency = 1 })
			Tween(WindowScale, TI.Fast, { Scale = 0.95 })
			TaskDelay(0.2, function()
				if UIHidden then WindowRoot.Visible = false end
			end)
		end
	end

	local function SetMinimized(State)
		Minimized = State
		SetIconColor(MinimizeIcon, CurrentTheme().TextDark)
		if State then
			Tween(WindowScale, TI.Smooth, { Scale = 0.99 })
			Tween(Sidebar, TI.Fast, { BackgroundTransparency = 1 })
			Tween(SidebarLine, TI.Fast, { BackgroundTransparency = 1 })
			Tween(Footer, TI.Fast, { BackgroundTransparency = 1 })
			local ActiveGroup = SelectedTab and SelectedTab.Group or nil
			FadeGroup(ActiveGroup, TI.Fast, 1)
			local TargetWidth = math.max(226, Title.TextBounds.X + (IconOffset == 42 and 148 or 122))
			Tween(WindowRoot, TI.Smooth, { Size = UDim2.fromOffset(TargetWidth, 48) })
			Tween(ShadowOuter, TI.Smooth, { Size = UDim2.new(1, 20, 1, 20), Position = UDim2.fromOffset(-10, -4) })
			Tween(ShadowInner, TI.Smooth, { Size = UDim2.new(1, 10, 1, 12), Position = UDim2.fromOffset(-5, -2) })
			TaskDelay(0.08, function()
				if Minimized then
					Sidebar.Visible = false
					ContentArea.Visible = false
					Footer.Visible = false
					BodyStroke.Transparency = 0.4
				end
			end)
			Tween(BodyStroke, TI.Slow, { Transparency = 0.2 })
		else
			Sidebar.Visible = true
			ContentArea.Visible = true
			Footer.Visible = true
			Tween(Sidebar, TI.Smooth, { BackgroundTransparency = 0 })
			Tween(SidebarLine, TI.Smooth, { BackgroundTransparency = 0 })
			Tween(Footer, TI.Smooth, { BackgroundTransparency = 0 })
			local ActiveGroup = SelectedTab and SelectedTab.Group or nil
			FadeGroup(ActiveGroup, TI.Smooth, 0)
			Tween(WindowRoot, TI.Smooth, { Size = Config.Size })
			Tween(ShadowOuter, TI.Smooth, { Size = UDim2.new(1, 26, 1, 30), Position = UDim2.fromOffset(-13, -11) })
			Tween(ShadowInner, TI.Smooth, { Size = UDim2.new(1, 14, 1, 18), Position = UDim2.fromOffset(-7, -5) })
			Tween(BodyStroke, TI.Slow, { Transparency = 0.4 })
			Tween(WindowScale, TI.Spring, { Scale = 1 })
		end
	end

	--------------------------------------------------------------------------
	-- 标签页
	--------------------------------------------------------------------------

	local function UpdateIndicator()
		if not SelectedTab or not SelectedTab.Button or not SelectedTab.Button.Parent then return end
		local Button = SelectedTab.Button
		local Y = Button.AbsolutePosition.Y - IndicatorClip.AbsolutePosition.Y
		Tween(TabIndicator, TI.Smooth, {
			Position = UDim2.new(0, 1, 0, Y + 6),
			Size = UDim2.new(0, 3, 0, math.max(12, Button.AbsoluteSize.Y - 12)),
		})
	end

	local function UpdateTabVisual(Tab, Active)
		local Theme = CurrentTheme()
		if Active then
			Tween(Tab.Button, TI.Normal, { BackgroundTransparency = 0.86, BackgroundColor3 = Theme.Accent })
			Tween(Tab.Stroke, TI.Normal, { Transparency = 0.72, Color = Theme.Accent })
			Tween(Tab.Title, TI.Normal, { TextColor3 = Theme.Text, TextTransparency = 0 })
			if Tab.Icon then
				if Tab.Icon:IsA("ImageLabel") then
					Tween(Tab.Icon, TI.Normal, { ImageColor3 = Theme.Accent, ImageTransparency = 0 })
				else
					Tween(Tab.Icon, TI.Normal, { TextColor3 = Theme.Accent, TextTransparency = 0 })
				end
			end
		else
			Tween(Tab.Button, TI.Normal, { BackgroundTransparency = 1 })
			Tween(Tab.Stroke, TI.Normal, { Transparency = 1 })
			Tween(Tab.Title, TI.Normal, { TextColor3 = Theme.TextDark, TextTransparency = 0 })
			if Tab.Icon then
				if Tab.Icon:IsA("ImageLabel") then
					Tween(Tab.Icon, TI.Normal, { ImageColor3 = Theme.TextDark, ImageTransparency = 0.1 })
				else
					Tween(Tab.Icon, TI.Normal, { TextColor3 = Theme.TextDark, TextTransparency = 0.1 })
				end
			end
		end
	end

	local function StaggerElements(Tab)
		local Scroller = Tab.Scroller
		if not Scroller then return end
		local Index = 0
		for _, Child in ipairs(Scroller:GetChildren()) do
			if Child:IsA("GuiObject") and Child.Visible then
				Index = Index + 1
				if Index > 14 then break end
				local Scale = EnsureScale(Child, 1)
				Scale.Scale = 0.965
				Tween(Scale, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, Index * 0.025), { Scale = 1 })
			end
		end
	end

	local function SelectTab(Tab, Silent)
		if not Tab or SelectedTab == Tab then return end
		local Previous = SelectedTab
		SelectedTab = Tab
		Window.SelectedTab = Tab

		for _, Other in ipairs(Tabs) do
			UpdateTabVisual(Other, Other == Tab)
		end
		UpdateIndicator()
		-- 首帧 AbsolutePosition 可能还没生效, 布局稳定后再校正一次
		TaskDelay(0.15, function()
			if SelectedTab == Tab then UpdateIndicator() end
		end)

		if Previous then
			FadeGroup(Previous.Group, TI.Fast, 1)
			Tween(Previous.Group, TI.Fast, { Position = UDim2.fromOffset(0, -10) })
			TaskDelay(0.14, function()
				if Previous.Group and Previous ~= SelectedTab then
					Previous.Group.Visible = false
				end
			end)
		end

		TaskDelay(Previous and 0.1 or 0.02, function()
			if not Tab.Group then return end
			Tab.Group.Visible = true
			Tab.Group.Position = UDim2.fromOffset(0, 14)
			if HasCanvasGroup then Tab.Group.GroupTransparency = 1 end
			FadeGroup(Tab.Group, TI.Smooth, 0)
			Tween(Tab.Group, TI.Smooth, { Position = UDim2.fromOffset(0, 0) })
			if not Silent then StaggerElements(Tab) end
		end)
	end

	AddConnection(TabHolder:GetPropertyChangedSignal("CanvasPosition"), UpdateIndicator)
	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 14)
		UpdateIndicator()
	end)

	local function ApplySearch(Query)
		Query = tostring(Query or ""):lower()
		local VisibleCount = 0
		for _, Tab in ipairs(Tabs) do
			local Match = Query == "" or Tab.Name:lower():find(Query, 1, true) ~= nil
			Tab.Button.Visible = Match
			if Match then VisibleCount = VisibleCount + 1 end
		end
		NoResult.Visible = VisibleCount == 0
		TaskWait()
		TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 14)
		UpdateIndicator()
	end

	if SearchBox then
		AddConnection(SearchBox:GetPropertyChangedSignal("Text"), function()
			ApplySearch(SearchBox.Text)
		end)
		OnLanguageRefresh(function()
			if SearchBox.Parent then
				SearchBox.PlaceholderText = L("Search")
			end
		end)
	end
	OnLanguageRefresh(function()
		if NoResult.Parent then
			NoResult.Text = L("NoResult")
		end
	end)

	function Window:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		local TabName = TabConfig.Name or ("Tab " .. (#Tabs + 1))
		local TabIcon = TabConfig.Icon
		local Locked = TabConfig.Locked or TabConfig.PremiumOnly or false

		local Tab = {
			Name = TabName,
			Icon = TabIcon,
			Locked = Locked,
			Buttons = {},
		}

		local TabButton = Create("TextButton", {
			Name = "Tab_" .. TabName,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CurrentTheme().Accent,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = #Tabs + 1,
			Parent = TabHolder,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		local TabStroke = Create("UIStroke", {
			Color = CurrentTheme().Accent,
			Thickness = 1,
			Transparency = 1,
			Parent = TabButton,
		})

		local HasIcon = TabIcon ~= nil
		local TabIconObject = BuildIcon(TabButton, TabIcon, 16, CurrentTheme().TextDark, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 11, 0.5, 0),
		})

		local TabLabel = Create("TextLabel", {
			Name = "Title",
			Text = TabName,
			TextColor3 = CurrentTheme().TextDark,
			TextSize = 13,
			Font = Fonts.SemiBold,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, TabIconObject and 35 or 12, 0, 0),
			Size = UDim2.new(1, TabIconObject and -46 or -24, 1, 0),
			Parent = TabButton,
		})

		local TabGroup = CreateGroup({
			Name = "Page_" .. TabName,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = ContentArea,
		})

		local Scroller = Create("ScrollingFrame", {
			Name = "ItemContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = CurrentTheme().Stroke,
			ScrollBarImageTransparency = 0.35,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
			Parent = TabGroup,
		}, {
			Create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),
			Create("UIPadding", {
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 22),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			}),
		})
		local ScrollerList = Scroller.UIListLayout

		Tab.Button = TabButton
		Tab.Stroke = TabStroke
		Tab.Title = TabLabel
		Tab.Icon = TabIconObject
		Tab.Group = TabGroup
		Tab.Scroller = Scroller
		Tab.List = ScrollerList

		AddConnection(ScrollerList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			Scroller.CanvasSize = UDim2.new(0, 0, 0, ScrollerList.AbsoluteContentSize.Y + 40)
		end)

		AddConnection(TabButton.MouseEnter, function()
			if SelectedTab ~= Tab then
				Tween(TabButton, TI.Fast, { BackgroundColor3 = CurrentTheme().Card, BackgroundTransparency = 0 })
				Tween(TabStroke, TI.Fast, { Transparency = 0.75 })
			end
		end)
		AddConnection(TabButton.MouseLeave, function()
			if SelectedTab ~= Tab then
				Tween(TabButton, TI.Fast, { BackgroundTransparency = 1 })
				Tween(TabStroke, TI.Fast, { Transparency = 1 })
			end
		end)
		AddConnection(TabButton.MouseButton1Click, function()
			SelectTab(Tab)
		end)

		if Locked then
			local LockCover = Create("Frame", {
				Name = "Locked",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = CurrentTheme().Main,
				BackgroundTransparency = 0.35,
				Parent = TabGroup,
			})
			AddThemeObject(LockCover, "Main", "BackgroundColor3")
			local LockBox = Create("Frame", {
				Size = UDim2.fromOffset(320, 132),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				BackgroundColor3 = CurrentTheme().Card,
				Parent = LockCover,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 16) }) })
			AddThemeObject(LockBox, "Card", "BackgroundColor3")
			Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = LockBox })
			local LockChip = Create("Frame", {
				Size = UDim2.fromOffset(40, 40),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 18),
				BackgroundColor3 = CurrentTheme().Accent,
				BackgroundTransparency = 0.88,
				Parent = LockBox,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 12) }) })
			AddAccentObject(LockChip, "BackgroundColor3", "color")
			IconKit.Lock(LockChip, 18, CurrentTheme().Accent, 1.6)
			Create("TextLabel", {
				Text = TabConfig.LockText or L("Locked"),
				TextColor3 = CurrentTheme().Text,
				TextSize = 14,
				Font = Fonts.Bold,
				BackgroundTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 16, 0, 68),
				Size = UDim2.new(1, -32, 0, 18),
				Parent = LockBox,
			})
			Create("TextLabel", {
				Text = TabConfig.LockDescription or L("LockedDesc"),
				TextColor3 = CurrentTheme().TextDark,
				TextSize = 11.5,
				Font = Fonts.Medium,
				BackgroundTransparency = 1,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 16, 0, 90),
				Size = UDim2.new(1, -32, 0, 32),
				Parent = LockBox,
			})
			AddConnection(TabButton.MouseButton1Click, function()
				if not Tab.Notified and Tab.Locked then
					Tab.Notified = true
					OrionLib:MakeNotification({
						Name = L("Locked"),
						Content = TabConfig.LockDescription or L("LockedDesc"),
						Type = "warning",
						Time = 4,
					})
				end
			end)
			Tab.Elements = MakeLockedElements()
			Tab.SetLocked = function(self, State)
				if State == true then
					self.Locked = true
					self.Notified = false
					LockCover.Visible = true
					return self
				end
				if not self.Unlocked then
					self.Unlocked = true
					self.Elements = BuildElements(Scroller, self)
					for Key, Function in pairs(self.Elements) do
						self[Key] = Function
					end
				end
				self.Locked = false
				LockCover.Visible = false
				return self
			end
			Tab.IsLocked = function(self)
				return self.Locked == true
			end
		else
			Tab.Elements = BuildElements(Scroller, Tab)
			Tab.SetLocked = function(self, State)
				self.Locked = State == true
				return self
			end
			Tab.IsLocked = function(self)
				return false
			end
		end

		-- 组件挂载到 Tab 对象上
		for Key, Function in pairs(Tab.Elements) do
			Tab[Key] = Function
		end

		Tab.Select = function(self)
			SelectTab(self)
			return self
		end
		Tab.IsSelected = function(self)
			return SelectedTab == self
		end
		Tab.SetName = function(self, NewName)
			self.Name = NewName
			TabLabel.Text = NewName
			return self
		end
		Tab.SetIcon = function(self, NewIcon)
			if TabIconObject then TabIconObject:Destroy() end
			TabIconObject = BuildIcon(TabButton, NewIcon, 16, CurrentTheme().TextDark, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 11, 0.5, 0),
			})
			self.Icon = TabIconObject
			local Offset = TabIconObject and 35 or 12
			TabLabel.Position = UDim2.new(0, Offset, 0, 0)
			TabLabel.Size = UDim2.new(1, TabIconObject and -46 or -24, 1, 0)
			return self
		end
		Tab.SetBadge = function(self, Text, Color)
			if self.Badge then self.Badge:Destroy() self.Badge = nil end
			if Text == nil then return self end
			local Badge = Create("Frame", {
				Name = "Badge",
				Size = UDim2.fromOffset(24, 16),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				BackgroundColor3 = Color or CurrentTheme().Accent,
				Parent = TabButton,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local BadgeLabel = Create("TextLabel", {
				Name = "Text",
				Text = tostring(Text),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 10,
				Font = Fonts.Bold,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = Badge,
			})
			Badge.Size = UDim2.fromOffset(BadgeLabel.TextBounds.X + 12, 16)
			self.Badge = Badge
			return self
		end
		Tab.Destroy = function(self)
			local Index = table.find(Tabs, self)
			if Index then table.remove(Tabs, Index) end
			if SelectedTab == self then
				SelectedTab = nil
				if Tabs[1] then SelectTab(Tabs[1], true) end
			end
			TabButton:Destroy()
			TabGroup:Destroy()
			TabByName[self.Name] = nil
			return true
		end

		table.insert(Tabs, Tab)
		TabByName[TabName] = Tab
		Window.Tabs = Tabs

		if #Tabs == 1 then
			TaskDelay(0.02, function()
				SelectTab(Tab, true)
			end)
		end

		return Tab
	end

	function Window:GetTabs()
		return Tabs
	end

	function Window:SelectTab(NameOrIndex)
		local Target
		if type(NameOrIndex) == "number" then
			Target = Tabs[NameOrIndex]
		elseif type(NameOrIndex) == "string" then
			Target = TabByName[NameOrIndex]
			if not Target then
				for _, Tab in ipairs(Tabs) do
					if Tab.Name:lower() == NameOrIndex:lower() then
						Target = Tab
						break
					end
				end
			end
		elseif type(NameOrIndex) == "table" then
			Target = NameOrIndex
		end
		if Target then
			SelectTab(Target)
			return true
		end
		return false
	end

	function Window:GetSelectedTab()
		return SelectedTab
	end

	--------------------------------------------------------------------------
	-- 窗口方法
	--------------------------------------------------------------------------

	function Window:SetTitle(Text)
		Config.Name = Text
		Title.Text = Text
		return Window
	end

	function Window:SetSubtitle(Text)
		Config.Subtitle = Text or ""
		Subtitle.Text = Config.Subtitle
		Subtitle.Visible = Config.Subtitle ~= ""
		local Shift = Config.Subtitle ~= "" and -8 or 0
		Tween(Title, TI.Fast, { Position = UDim2.new(0, IconOffset, 0.5, Shift) })
		if WindowIcon then
			Tween(WindowIcon, TI.Fast, { Position = UDim2.new(0, 16, 0.5, Shift) })
		end
		return Window
	end

	function Window:SetIcon(Icon)
		Config.Icon = Icon
		if WindowIcon then WindowIcon:Destroy() end
		WindowIcon = BuildIcon(TopBar, Icon, 18, CurrentTheme().Text, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, Config.Subtitle ~= "" and -8 or 0),
		})
		IconOffset = WindowIcon and 42 or 16
		Title.Position = UDim2.new(0, IconOffset, 0.5, Config.Subtitle ~= "" and -8 or 0)
		Title.Size = UDim2.new(0.6, -IconOffset, 0, 18)
		Subtitle.Position = UDim2.new(0, IconOffset, 0.5, 9)
		Subtitle.Size = UDim2.new(0.6, -IconOffset, 0, 14)
		return Window
	end

	function Window:SetFooter(Text)
		Config.Footer = Text or ""
		StatusLabel.Text = Config.Footer
		return Window
	end

	function Window:SetStatus(Text, Color)
		StatusLabel.Text = tostring(Text or "")
		StatusDot.BackgroundColor3 = Color or StatusColors.Success
		Tween(StatusDot, TI.Fast, { BackgroundTransparency = 0 })
		return Window
	end

	function Window:SetTheme(Theme)
		OrionLib:SetTheme(Theme)
		UpdateIndicator()
		if SelectedTab then UpdateTabVisual(SelectedTab, true) end
		return Window
	end

	function Window:SetAccent(Color)
		OrionLib:SetAccent(Color)
		UpdateIndicator()
		if SelectedTab then UpdateTabVisual(SelectedTab, true) end
		return Window
	end

	function Window:SetToggleKey(Key)
		if type(Key) == "string" then
			local EnumKey = Enum.KeyCode[Key]
			if EnumKey then
				Config.ToggleKey = EnumKey
				ToggleKeyName = EnumKey.Name
			end
		elseif typeof(Key) == "EnumItem" then
			Config.ToggleKey = Key
			ToggleKeyName = Key.Name
		end
		return Window
	end

	function Window:GetToggleKey()
		return ToggleKeyName
	end

	function Window:Minimize(State)
		if State == nil then State = not Minimized end
		if State ~= Minimized then
			SetMinimized(State)
			if State then
				Tween(WindowScale, TI.Fast, { Scale = 0.98 })
			else
				Tween(WindowScale, TI.Spring, { Scale = 1 })
			end
		end
		return Window
	end

	function Window:ToggleMinimize()
		return Window:Minimize()
	end

	function Window:IsMinimized()
		return Minimized
	end

	function Window:Show()
		SetVisible(true)
		return Window
	end

	function Window:Hide()
		SetVisible(false)
		return Window
	end

	function Window:Toggle()
		SetVisible(UIHidden)
		return Window
	end

	function Window:IsVisible()
		return not UIHidden
	end

	function Window:Notify(Config)
		return OrionLib:MakeNotification(Config)
	end

	function Window:Destroy()
		if WindowRoot then WindowRoot:Destroy() end
		Window.Destroyed = true
		return true
	end

	Window.Root = MainWindow
	Window.WindowRoot = WindowRoot
	Window.Body = Body
	Window.Sidebar = Sidebar
	Window.Footer = Footer
	Window.Tabs = Tabs
	OrionLib.Window = Window

	AddConnection(CloseButton.MouseButton1Click, function()
		SetVisible(false)
		if Config.ShowCloseNotification then
			OrionLib:MakeNotification({
				Name = L("Hidden"),
				Content = L("ToggleHint", ToggleKeyName),
				Type = "info",
				Time = 5,
			})
		end
		SafeCall(Config.CloseCallback)
	end)

	AddConnection(MinimizeButton.MouseButton1Click, function()
		Window:Minimize()
	end)

	AddConnection(UserInputService.InputBegan, function(Input, Processed)
		if Processed then return end
		if UserInputService:GetFocusedTextBox() then return end
		if Input.KeyCode == Config.ToggleKey then
			SetVisible(UIHidden)
		elseif Config.CloseOnEscape and Input.KeyCode == Enum.KeyCode.Escape and not UIHidden then
			if not Minimized then
				SetVisible(false)
			end
		end
	end)

	--------------------------------------------------------------------------
	-- 开场序列
	--------------------------------------------------------------------------

	local function PlayIntro()
		if IntroPlayed then return end
		IntroPlayed = true
		WindowRoot.Visible = false

		local Overlay = Create("Frame", {
			Name = "IntroOverlay",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 40,
			Parent = Orion,
		})

		local IntroCard = CreateGroup({
			Name = "IntroCard",
			Size = UDim2.fromOffset(272, 138),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = CurrentTheme().Main,
			Parent = Overlay,
		})
		if HasCanvasGroup then IntroCard.GroupTransparency = 1 end
		Create("UICorner", { CornerRadius = UDim.new(0, 18), Parent = IntroCard })
		Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.4, Parent = IntroCard })
		AddThemeObject(IntroCard, "Main", "BackgroundColor3")

		local IntroScale = EnsureScale(IntroCard, 0.94)

		local LogoHolder = Create("Frame", {
			Name = "Logo",
			Size = UDim2.fromOffset(38, 38),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 22),
			BackgroundColor3 = CurrentTheme().Accent,
			BackgroundTransparency = 0.88,
			Parent = IntroCard,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 12) }) })
		AddAccentObject(LogoHolder, "BackgroundColor3", "color")
		Create("UIStroke", { Color = CurrentTheme().Accent, Thickness = 1, Transparency = 0.6, Parent = LogoHolder })
		local IntroIcon = BuildIcon(LogoHolder, Config.IntroIcon or "logo", 20, CurrentTheme().Accent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		if not IntroIcon then
			IconKit.Dot(LogoHolder, 12, CurrentTheme().Accent)
		else
			AddAccentObject(IntroIcon, IntroIcon:IsA("ImageLabel") and "ImageColor3" or "TextColor3", "color")
		end

		local IntroTitle = Create("TextLabel", {
			Name = "IntroText",
			Text = Config.IntroText,
			TextColor3 = CurrentTheme().Text,
			TextSize = 15,
			Font = Fonts.Bold,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 14, 0, 70),
			Size = UDim2.new(1, -28, 0, 18),
			Parent = IntroCard,
		})
		AddThemeObject(IntroTitle, "Text", "TextColor3")

		local ProgressTrack = Create("Frame", {
			Name = "Progress",
			Size = UDim2.new(1, -60, 0, 3),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -22),
			BackgroundColor3 = CurrentTheme().Divider,
			BackgroundTransparency = 0.3,
			Parent = IntroCard,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		AddThemeObject(ProgressTrack, "Divider", "BackgroundColor3")
		local ProgressFill = Create("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = CurrentTheme().Accent,
			BorderSizePixel = 0,
			Parent = ProgressTrack,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		local ProgressGradient = AccentGradient(ProgressFill, 0)
		AddAccentObject(ProgressGradient, "Color", "gradient")

		local Finished = false
		local function FinishIntro()
			if Finished then return end
			Finished = true
			FadeGroup(IntroCard, TI.Smooth, 1)
			Tween(IntroScale, TI.Smooth, { Scale = 0.96 })
			Tween(Overlay, TI.Smooth, { BackgroundTransparency = 1 })
			TaskDelay(0.3, function()
				Overlay:Destroy()
				WindowRoot.Visible = true
				if HasCanvasGroup then MainWindow.GroupTransparency = 1 end
				WindowScale.Scale = 0.96
				FadeGroup(MainWindow, TI.Smooth, 0)
				Tween(WindowScale, TI.Spring, { Scale = 1 })
				if SelectedTab then StaggerElements(SelectedTab) end
			end)
		end

		Tween(Overlay, TI.Slow, { BackgroundTransparency = 0.42 })
		FadeGroup(IntroCard, TI.Smooth, 0)
		Tween(IntroScale, TI.Spring, { Scale = 1 })
		Tween(ProgressFill, TweenInfo.new(math.max(0.4, Config.IntroDuration * 0.85), Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
		TaskDelay(Config.IntroDuration, FinishIntro)

		local ClickCatcher = Create("TextButton", {
			Name = "Skip",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 41,
			Parent = Overlay,
		})
		ClickCatcher.MouseButton1Click:Connect(FinishIntro)
	end

	if Config.IntroEnabled then
		PlayIntro()
	else
		WindowRoot.Visible = true
	end

	Window.PlayIntro = PlayIntro
	Window.SetVisible = SetVisible

	return Window
end

------------------------------------------------------------------------------
-- [ 18 ] 组件通用构建器
------------------------------------------------------------------------------

local function NextLayoutOrder(Parent)
	local Count = 0
	for _, Child in ipairs(Parent:GetChildren()) do
		if Child:IsA("GuiObject") then
			Count = Count + 1
		end
	end
	return Count + 1
end

local function CreateRow(ItemParent, Height, Config)
	Config = Config or {}
	local Card = Create("Frame", {
		Name = Config.Name or "Row",
		Size = UDim2.new(1, 0, 0, Height),
		BackgroundColor3 = CurrentTheme().Card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Config.Radius or 11) }) })
	AddThemeObject(Card, "Card", "BackgroundColor3")

	local Stroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = Config.StrokeTransparency or 0.5,
		Parent = Card,
	})
	AddThemeObject(Stroke, "Stroke", "Color")

	local TitleLeft = Config.TitleLeft or 14
	local Title = Create("TextLabel", {
		Name = "Content",
		Text = Config.Text or "",
		TextColor3 = CurrentTheme().Text,
		TextSize = Config.TextSize or 13,
		Font = Config.Font or Fonts.SemiBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, TitleLeft, 0, 0),
		Size = UDim2.new(1, -(Config.TitleRight or 14) - TitleLeft, 1, 0),
		Parent = Card,
	})
	AddThemeObject(Title, "Text", "TextColor3")

	local Click = Create("TextButton", {
		Name = "Click",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = Card,
	})

	local Scale = EnsureScale(Card, 1)

	return {
		Frame = Card,
		Title = Title,
		Click = Click,
		Stroke = Stroke,
		Scale = Scale,
	}
end

-- 配置保存防抖: 高频滑动时不会把文件系统写爆
local SaveQueued = false
local function QueueSave()
	if not OrionLib.AutoSave or not OrionLib.Folder then return end
	if SaveQueued then return end
	SaveQueued = true
	TaskDelay(0.6, function()
		SaveQueued = false
		if OrionLib.SaveConfig then
			SafeCall(OrionLib.SaveConfig, OrionLib, game.GameId)
		end
	end)
end

local function RegisterFlag(Element, Config, TypeName, Save)
	Element.Type = TypeName
	Element.Save = Save == true
	Element.Flag = Config.Flag
	if Config.Flag then
		OrionLib.Flags[Config.Flag] = Element
	end
	return Element
end

local function FireFlag(Element)
	if Element.Flag then
		OrionLib.FlagChanged:Fire(Element.Flag, Element.Value, Element)
	end
	QueueSave()
end

------------------------------------------------------------------------------
-- [ 19 ] 文本类组件: 标签 / 段落
------------------------------------------------------------------------------

local function AddLabel(ItemParent, Tab, Text, Config)
	if type(Text) == "table" then
		Config = Text
		Text = Config.Text or Config.Name or ""
	end
	Config = Config or {}
	local Height = Config.Height or 34
	local Row = CreateRow(ItemParent, Height, {
		Name = "Label",
		Text = tostring(Text or ""),
		TextSize = Config.TextSize or 13,
		Font = Fonts.SemiBold,
	})
	Row.Title.TextYAlignment = Enum.TextYAlignment.Center
	if Config.Color then
		Row.Title.TextColor3 = Config.Color
	end
	if Config.Wrapped then
		Row.Title.TextWrapped = true
		Row.Title.TextTruncate = Enum.TextTruncate.None
		Row.Frame.Size = UDim2.new(1, 0, 0, Config.Height or 46)
	end

	local Element = { Type = "Label", Value = Text }
	function Element:Set(NewText)
		self.Value = NewText
		Row.Title.Text = tostring(NewText or "")
	end
	function Element:Get()
		return Row.Title.Text
	end
	function Element:SetColor(Color)
		Row.Title.TextColor3 = Color
	end
	function Element:Destroy()
		Row.Frame:Destroy()
	end
	return Element
end

local function AddParagraph(ItemParent, Tab, Title, Content, Config)
	if type(Title) == "table" then
		Config = Title
		Title = Config.Title or Config.Name
		Content = Config.Content or Config.Description
	end
	Config = Config or {}

	local Card = Create("Frame", {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CurrentTheme().Card,
		BorderSizePixel = 0,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 11) }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	})
	AddThemeObject(Card, "Card", "BackgroundColor3")
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = Card })
	EnsureScale(Card, 1)

	local TitleLabel = Create("TextLabel", {
		Name = "Title",
		Text = tostring(Title or "文本"),
		TextColor3 = CurrentTheme().Text,
		TextSize = 13,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		Parent = Card,
	})
	AddThemeObject(TitleLabel, "Text", "TextColor3")

	local ContentLabel = Create("TextLabel", {
		Name = "Body",
		Text = tostring(Content or ""),
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 12,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		RichText = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = Card,
	})
	AddThemeObject(ContentLabel, "TextDark", "TextColor3")

	local Element = { Type = "Paragraph" }
	function Element:Set(NewContent)
		ContentLabel.Text = tostring(NewContent or "")
	end
	function Element:SetTitle(NewTitle)
		TitleLabel.Text = tostring(NewTitle or "")
	end
	function Element:Get()
		return ContentLabel.Text
	end
	function Element:Destroy()
		Card:Destroy()
	end
	return Element
end

------------------------------------------------------------------------------
-- [ 20 ] 按钮
------------------------------------------------------------------------------

local function AddButton(ItemParent, Tab, ButtonConfig)
	ButtonConfig = ButtonConfig or {}
	local Name = ButtonConfig.Name or "按钮"
	local Icon = ButtonConfig.Icon
	local DoubleClick = ButtonConfig.DoubleClick

	local LeftOffset = Icon and 40 or 14
	local Row = CreateRow(ItemParent, ButtonConfig.Height or 42, {
		Name = "Button",
		Text = Name,
		TitleLeft = LeftOffset,
		TitleRight = 34,
	})

	if Icon then
		local IconObject = BuildIcon(Row.Frame, Icon, 16, CurrentTheme().TextDark, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
		})
		if IconObject then
			AddThemeObject(IconObject, "TextDark")
		end
	end

	local Chevron = IconKit.Chevron(Row.Frame, 14, CurrentTheme().TextDark, 1.5, "right")
	Chevron.Position = UDim2.new(1, -17, 0.5, 0)
	Chevron.AnchorPoint = Vector2.new(0.5, 0.5)

	local Scale = MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		OnHover = function(State)
			Tween(Chevron, TI.Fast, { Position = UDim2.new(1, State and -21 or -17, 0.5, 0) })
			SetIconColor(Chevron, State and CurrentTheme().Accent or CurrentTheme().TextDark)
		end,
	})

	local Element = { Type = "Button", Value = Name, Pending = false }
	local Clicks = 0
	-- DoubleClick 支持两种写法:
	--   DoubleClick = function() end  单机 -> Callback, 双击 -> DoubleClick
	--   DoubleClick = true            必须连点两次才触发 Callback
	local DoubleClickFunction = type(DoubleClick) == "function" and DoubleClick or nil
	local RequireDouble = DoubleClick == true

	local function RunCallback()
		if DoubleClickFunction then
			Clicks = Clicks + 1
			if Clicks >= 2 then
				Clicks = 0
				SafeCall(DoubleClickFunction)
				return
			end
			TaskDelay(0.3, function()
				if Clicks == 1 then
					Clicks = 0
					SafeCall(ButtonConfig.Callback)
				end
			end)
		elseif RequireDouble then
			Clicks = Clicks + 1
			if Clicks >= 2 then
				Clicks = 0
				SafeCall(ButtonConfig.Callback)
			else
				TaskDelay(0.36, function()
					Clicks = 0
				end)
			end
		else
			SafeCall(ButtonConfig.Callback)
		end
	end

	AddConnection(Row.Click.MouseButton1Click, RunCallback)

	local Loading = false
	function Element:Set(NewText)
		self.Value = NewText
		Row.Title.Text = tostring(NewText or "")
	end
	function Element:Get()
		return Row.Title.Text
	end
	function Element:SetIcon(NewIcon)
		local Existing = Row.Frame:FindFirstChild("Icon")
		if Existing then Existing:Destroy() end
		if NewIcon then
			BuildIcon(Row.Frame, NewIcon, 16, CurrentTheme().TextDark, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 14, 0.5, 0),
			})
			Row.Title.Position = UDim2.new(0, 40, 0, 0)
			Row.Title.Size = UDim2.new(1, -74, 1, 0)
		else
			Row.Title.Position = UDim2.new(0, 14, 0, 0)
			Row.Title.Size = UDim2.new(1, -48, 1, 0)
		end
	end
	function Element:SetLoading(State)
		Loading = State == true
		Row.Title.TextTransparency = Loading and 0.45 or 0
		Row.Click.AutoButtonColor = false
	end
	function Element:Destroy()
		Row.Frame:Destroy()
	end
	return Element
end

------------------------------------------------------------------------------
-- [ 21 ] 开关
------------------------------------------------------------------------------

local function AddToggle(ItemParent, Tab, ToggleConfig)
	ToggleConfig = ToggleConfig or {}
	local Name = ToggleConfig.Name or "开关"
	local Callback = ToggleConfig.Callback
	local Default = ToggleConfig.Default == true
	local AccentColor = ToggleConfig.Color

	local Row = CreateRow(ItemParent, ToggleConfig.Height or 42, {
		Name = "Toggle",
		Text = Name,
		TitleRight = 74,
	})

	local Track = Create("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(44, 23),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = Row.Frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	AddThemeObject(Track, "Divider", "BackgroundColor3")

	local TrackStroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = 0.5,
		Parent = Track,
	})

	local TrackGradient = Create("UIGradient", {
		Rotation = 0,
		Enabled = false,
		Color = ColorSequence.new(CurrentTheme().Accent, CurrentTheme().Accent2),
		Parent = Track,
	})
	AddAccentObject(TrackGradient, "Color", "gradient")

	local Knob = Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(17, 17),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = Track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local KnobScale = EnsureScale(Knob, 1)

	MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		RippleColor = AccentColor or CurrentTheme().Accent,
	})

	local Element = { Type = "Toggle", Value = Default }

	local function Render(Animate)
		local Info = Animate and TI.Spring or TI.Instant
		local On = Element.Value == true
		local Color = AccentColor or CurrentTheme().Accent
		Tween(Track, Info, {
			BackgroundColor3 = On and Color or CurrentTheme().Divider,
			BackgroundTransparency = On and 0 or 0,
		})
		Tween(TrackStroke, TI.Normal, {
			Transparency = On and 0.4 or 0.5,
			Color = On and Color or CurrentTheme().Stroke,
		})
		TrackGradient.Enabled = On and AccentColor == nil
		if AccentColor then
			TrackGradient.Color = ColorSequence.new(AccentColor, ShadeColor(AccentColor, 0.25))
		end
		Tween(Knob, Info, {
			Position = On and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = On and Color3.new(1, 1, 1) or CurrentTheme().Text,
		})
		Tween(KnobScale, TI.Fast, { Scale = 1 })
	end

	function Element:Set(Value, Silent)
		local NewValue = Value == true
		local Changed = NewValue ~= self.Value
		self.Value = NewValue
		Render(true)
		if Changed and not Silent then
			SafeCall(Callback, NewValue)
			FireFlag(self)
		end
	end
	Element.SetValue = Element.Set
	function Element:Get()
		return self.Value
	end
	function Element:Destroy()
		Row.Frame:Destroy()
	end

	AddConnection(Row.Click.MouseButton1Click, function()
		Element:Set(not Element.Value)
	end)

	AddConnection(Row.Click.MouseEnter, function()
		Tween(KnobScale, TI.Fast, { Scale = 1.08 })
	end)
	AddConnection(Row.Click.MouseLeave, function()
		Tween(KnobScale, TI.Fast, { Scale = 1 })
	end)

	RegisterFlag(Element, ToggleConfig, "Toggle", ToggleConfig.Save)
	OnThemeRefresh(function()
		if Row.Frame.Parent then Render(false) end
	end)
	Render(false)
	if Default then
		SafeCall(Callback, Default)
	end

	return Element
end

------------------------------------------------------------------------------
-- [ 22 ] 滑块
------------------------------------------------------------------------------

local function AddSlider(ItemParent, Tab, SliderConfig)
	SliderConfig = SliderConfig or {}
	local Name = SliderConfig.Name or "滑块"
	local Min = tonumber(SliderConfig.Min) or 0
	local Max = tonumber(SliderConfig.Max) or 100
	local Increment = tonumber(SliderConfig.Increment) or 1
	local Decimals = tonumber(SliderConfig.Decimals) or 0
	local Default = tonumber(SliderConfig.Default) or Min
	local Suffix = SliderConfig.Suffix or SliderConfig.ValueName or ""
	local Callback = SliderConfig.Callback
	local AccentColor = SliderConfig.Color or CurrentTheme().Accent

	local Row = CreateRow(ItemParent, SliderConfig.Height or 64, {
		Name = "Slider",
		Text = Name,
		TitleRight = 120,
		TitleLeft = 14,
	})
	Row.Title.Position = UDim2.new(0, 14, 0, 11)
	Row.Title.Size = UDim2.new(1, -134, 0, 14)

	local ValueLabel = Create("TextLabel", {
		Name = "Value",
		Text = "",
		TextColor3 = AccentColor,
		TextSize = 12.5,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -128, 0, 10),
		Size = UDim2.new(0, 114, 0, 16),
		ZIndex = 3,
		Parent = Row.Frame,
	})

	local Track = Create("Frame", {
		Name = "Track",
		Position = UDim2.new(0, 14, 0, 38),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = CurrentTheme().Divider,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Row.Frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	AddThemeObject(Track, "Divider", "BackgroundColor3")

	local Fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = AccentColor,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = Track,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local FillGradient = Create("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(AccentColor, ShadeColor(AccentColor, 0.2)),
		Parent = Fill,
	})
	if not SliderConfig.Color then
		AddAccentObject(FillGradient, "Color", "gradient")
		AddAccentObject(ValueLabel, "TextColor3", "color")
	end

	local Knob = Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = Fill,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Create("UIStroke", { Color = AccentColor, Thickness = 2, Parent = Knob })
	local KnobScale = EnsureScale(Knob, 1)

	-- 拖拽热区 ( 覆盖整张卡片, 点击任意位置都能定位数值 )
	local HitArea = Create("TextButton", {
		Name = "HitArea",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = Row.Frame,
	})

	local Element = { Type = "Slider", Value = Default }
	local Dragging = false

	local function Render(Animate)
		local Alpha = 0
		if Max ~= Min then
			Alpha = Clamp01((Element.Value - Min) / (Max - Min))
		end
		local Info = Animate and TI.Fast or TI.Instant
		Tween(Fill, Info, { Size = UDim2.fromScale(Alpha, 1) })
		ValueLabel.Text = FormatNumber(Element.Value, Decimals) .. (Suffix ~= "" and (" " .. Suffix) or "")
	end

	local function SetFromPosition(PositionX)
		local Relative = Clamp01((PositionX - Track.AbsolutePosition.X) / math.max(1, Track.AbsoluteSize.X))
		local Raw = Min + (Max - Min) * Relative
		if Increment > 0 then
			Raw = Round(Raw, Increment)
		end
		Element:Set(math.clamp(Raw, Min, Max))
	end

	BindDrag(HitArea, function(Position)
		Dragging = true
		Tween(KnobScale, TI.Fast, { Scale = 1.25 })
		SetFromPosition(Position.X)
	end, function()
		Dragging = false
		Tween(KnobScale, TI.Spring, { Scale = 1 })
	end)

	AddConnection(HitArea.MouseEnter, function()
		if not Dragging then Tween(KnobScale, TI.Fast, { Scale = 1.15 }) end
	end)
	AddConnection(HitArea.MouseLeave, function()
		if not Dragging then Tween(KnobScale, TI.Fast, { Scale = 1 }) end
	end)

	MakeInteractive(HitArea, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		Ripple = false,
	})

	function Element:Set(Value, Silent)
		local NewValue = tonumber(Value) or Min
		if Increment > 0 then
			NewValue = Round(NewValue, Increment)
		end
		NewValue = math.clamp(NewValue, Min, Max)
		local Changed = NewValue ~= self.Value
		self.Value = NewValue
		Render(true)
		if Changed and not Silent then
			SafeCall(Callback, NewValue)
			FireFlag(self)
		end
	end
	Element.SetValue = Element.Set
	function Element:Get()
		return self.Value
	end
	function Element:SetRange(NewMin, NewMax)
		Min = tonumber(NewMin) or Min
		Max = tonumber(NewMax) or Max
		self:Set(self.Value)
	end
	function Element:SetValueName(NewName)
		Suffix = tostring(NewName or "")
		Render(false)
	end
	function Element:Destroy()
		Row.Frame:Destroy()
	end

	RegisterFlag(Element, SliderConfig, "Slider", SliderConfig.Save)
	Render(false)

	return Element
end

------------------------------------------------------------------------------
-- [ 23 ] 下拉框 ( 支持多选 / 搜索 / 动态刷新 )
------------------------------------------------------------------------------

local DefaultPresets = {
	Color3.fromRGB(255, 90, 95), Color3.fromRGB(255, 149, 0),
	Color3.fromRGB(255, 204, 0), Color3.fromRGB(52, 199, 89),
	Color3.fromRGB(48, 209, 209), Color3.fromRGB(0, 122, 255),
	Color3.fromRGB(175, 82, 222), Color3.fromRGB(255, 255, 255),
}

local function AddDropdown(ItemParent, Tab, DropdownConfig)
	DropdownConfig = DropdownConfig or {}
	local Name = DropdownConfig.Name or "下拉框"
	local Multi = DropdownConfig.Multi == true
	local Callback = DropdownConfig.Callback
	local SearchEnabled = DropdownConfig.Search == true
	local MaxVisible = tonumber(DropdownConfig.MaxVisible) or 4
	local OptionHeight = 30
	local OptionPadding = 4

	local Row = CreateRow(ItemParent, 42, {
		Name = "Dropdown",
		Text = Name,
		TitleRight = 116,
	})

	local SelectedLabel = Create("TextLabel", {
		Name = "Selected",
		Text = "",
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 12,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(1, -136, 0, 0),
		Size = UDim2.new(0, 96, 1, 0),
		ZIndex = 1,
		Parent = Row.Frame,
	})
	AddThemeObject(SelectedLabel, "TextDark", "TextColor3")

	local Chevron = IconKit.Chevron(Row.Frame, 14, CurrentTheme().TextDark, 1.5, "down")
	Chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	Chevron.Position = UDim2.new(1, -17, 0, 21)

	local OptionsList = Create("ScrollingFrame", {
		Name = "Options",
		Position = UDim2.new(0, 0, 0, SearchEnabled and 44 or 42),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = CurrentTheme().Stroke,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = Row.Frame,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, OptionPadding),
		}),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	local OptionsListLayout = OptionsList.UIListLayout

	local SearchFrame
	local SearchBox
	if SearchEnabled then
		SearchFrame = Create("Frame", {
			Name = "SearchBox",
			Position = UDim2.new(0, 10, 0, 46),
			Size = UDim2.new(1, -20, 0, 28),
			BackgroundColor3 = CurrentTheme().Main,
			ZIndex = 3,
			Parent = Row.Frame,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		AddThemeObject(SearchFrame, "Main", "BackgroundColor3")
		Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.55, Parent = SearchFrame })
		SearchBox = Create("TextBox", {
			Name = "Input",
			Text = "",
			PlaceholderText = DropdownConfig.SearchPlaceholder or L("Search"),
			PlaceholderColor3 = CurrentTheme().TextDark,
			TextColor3 = CurrentTheme().Text,
			TextSize = 11.5,
			Font = Fonts.Medium,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Parent = SearchFrame,
		})
		AddThemeObject(SearchBox, "Text", "TextColor3")
	end

	MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		Ripple = false,
	})

	local Element = {
		Type = "Dropdown",
		Options = {},
		Buttons = {},
		Toggled = false,
		Multi = Multi,
		Value = Multi and {} or "...",
	}

	local function OptionHeightTotal()
		-- 只统计当前可见 ( 未被搜索过滤掉 ) 的选项, 展开高度才不会留白
		local Visible = 0
		for _, OptionName in ipairs(Element.Options) do
			local Option = Element.Buttons[OptionName]
			if Option and Option.Visible then
				Visible = Visible + 1
			end
		end
		local Count = math.min(Visible, MaxVisible)
		if Count < 1 then Count = 1 end
		return (Count * OptionHeight) + ((Count - 1) * OptionPadding) + 16
	end

	local function IsSelected(OptionName)
		if Multi then
			return table.find(Element.Value, OptionName) ~= nil
		end
		return Element.Value == OptionName
	end

	local function RenderOptions()
		local Theme = CurrentTheme()
		for OptionName, Option in pairs(Element.Buttons) do
			if Option.Parent then
				local Selected = IsSelected(OptionName)
				local Hovered = OrionLib.HoverState[Option]
				if Selected then
					Tween(Option, TI.Fast, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.86 })
					Tween(Option.Stroke, TI.Fast, { Transparency = 0.72, Color = Theme.Accent })
					Tween(Option.Title, TI.Fast, { TextColor3 = Theme.Text, TextTransparency = 0 })
					if Option.Mark then
						SetIconColor(Option.Mark, Theme.Accent)
						Option.Mark.Visible = true
					end
					if Option.Checkbox then
						Tween(Option.Checkbox, TI.Fast, { BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0 })
						if Option.CheckboxMark then Option.CheckboxMark.Visible = true end
					end
				else
					Tween(Option, TI.Fast, { BackgroundColor3 = Hovered and Theme.CardHover or Theme.Card, BackgroundTransparency = 1 })
					Tween(Option.Stroke, TI.Fast, { Transparency = 1 })
					Tween(Option.Title, TI.Fast, { TextColor3 = Theme.TextDark, TextTransparency = 0 })
					if Option.Mark then Option.Mark.Visible = false end
					if Option.Checkbox then
						Tween(Option.Checkbox, TI.Fast, { BackgroundColor3 = Theme.Main, BackgroundTransparency = 0 })
						if Option.CheckboxMark then Option.CheckboxMark.Visible = false end
					end
				end
			end
		end
	end

	local function UpdateSelectedLabel()
		local Theme = CurrentTheme()
		if Multi then
			local Count = #Element.Value
			if Count == 0 then
				SelectedLabel.Text = L("Unselected")
				SelectedLabel.TextColor3 = Theme.TextDark
			elseif Count == 1 then
				SelectedLabel.Text = TruncateText(Element.Value[1], 14)
				SelectedLabel.TextColor3 = Theme.Accent
			else
				SelectedLabel.Text = string.format(L("MultiSelected"), Count)
				SelectedLabel.TextColor3 = Theme.Accent
			end
		else
			if Element.Value == "..." then
				SelectedLabel.Text = L("Unselected")
				SelectedLabel.TextColor3 = Theme.TextDark
			else
				SelectedLabel.Text = TruncateText(Element.Value, 14)
				SelectedLabel.TextColor3 = Theme.Accent
			end
		end
	end

	local function SetExpanded(State, Animate)
		Element.Toggled = State
		local Info = Animate == false and TI.Instant or TI.Smooth
		Tween(Chevron, Info, { Rotation = State and 180 or 0 })
		local Target = 0
		if State then
			Target = OptionHeightTotal()
		end
		Tween(OptionsList, Info, { Size = UDim2.new(1, 0, 0, Target) })
		Tween(Row.Frame, Info, { Size = UDim2.new(1, 0, 0, 42 + Target + (SearchEnabled and 40 or 0)) })
		if SearchFrame then
			SearchFrame.Visible = State
		end
	end

	local function AddOption(OptionName)
		local Option = Create("TextButton", {
			Name = "Option_" .. tostring(OptionName),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = CurrentTheme().Card,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, OptionHeight),
			LayoutOrder = #Element.Options,
			Parent = OptionsList,
		}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
		local OptionStroke = Create("UIStroke", {
			Color = CurrentTheme().Accent,
			Thickness = 1,
			Transparency = 1,
			Parent = Option,
		})
		local OptionTitle = Create("TextLabel", {
			Name = "Title",
			Text = tostring(OptionName),
			TextColor3 = CurrentTheme().TextDark,
			TextSize = 12,
			Font = Fonts.Medium,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Parent = Option,
		})

		Option.Stroke = OptionStroke
		Option.Title = OptionTitle

		if Multi then
			local Checkbox = Create("Frame", {
				Name = "Checkbox",
				Size = UDim2.fromOffset(16, 16),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				BackgroundColor3 = CurrentTheme().Main,
				Parent = Option,
			}, { Create("UICorner", { CornerRadius = UDim.new(0, 5) }) })
			Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.4, Parent = Checkbox })
			local Mark = IconKit.Check(Checkbox, 12, Color3.new(1, 1, 1), 1.8)
			Mark.Visible = false
			Option.Checkbox = Checkbox
			Option.CheckboxMark = Mark
		else
			local Mark = IconKit.Check(Option, 12, CurrentTheme().Accent, 1.8)
			Mark.AnchorPoint = Vector2.new(1, 0.5)
			Mark.Position = UDim2.new(1, -14, 0.5, 0)
			Mark.Visible = false
			Option.Mark = Mark
		end

		AddConnection(Option.MouseEnter, function()
			OrionLib.HoverState[Option] = true
			if not IsSelected(OptionName) then
				Tween(Option, TI.Fast, { BackgroundTransparency = 0, BackgroundColor3 = CurrentTheme().CardHover })
			end
		end)
		AddConnection(Option.MouseLeave, function()
			OrionLib.HoverState[Option] = false
			if not IsSelected(OptionName) then
				Tween(Option, TI.Fast, { BackgroundTransparency = 1 })
			end
		end)
		AddConnection(Option.MouseButton1Click, function()
			if Multi then
				local Index = table.find(Element.Value, OptionName)
				if Index then
					table.remove(Element.Value, Index)
				else
					table.insert(Element.Value, OptionName)
				end
				RenderOptions()
				UpdateSelectedLabel()
				SafeCall(Callback, Element.Value)
				FireFlag(Element)
			else
				Element:Set(OptionName)
				SetExpanded(false)
			end
		end)

		Element.Buttons[OptionName] = Option
	end

	function Element:Refresh(NewOptions, Delete)
		NewOptions = NewOptions or {}
		if Delete then
			for _, Option in pairs(Element.Buttons) do
				Option:Destroy()
			end
			table.clear(Element.Buttons)
			Element.Options = {}
			OptionsList.CanvasSize = UDim2.new(0, 0, 0, 0)
		end
		for _, OptionName in ipairs(NewOptions) do
			if not table.find(Element.Options, OptionName) then
				table.insert(Element.Options, OptionName)
				AddOption(OptionName)
			end
		end
		RenderOptions()
		TaskWait()
		OptionsList.CanvasSize = UDim2.new(0, 0, 0, OptionsListLayout.AbsoluteContentSize.Y + 16)
		if Element.Toggled then SetExpanded(true) end
		return Element
	end

	function Element:Set(Value, Silent)
		if Multi then
			if type(Value) == "table" then
				Element.Value = {}
				for _, Item in ipairs(Value) do
					if table.find(Element.Options, Item) then
						table.insert(Element.Value, Item)
					end
				end
			end
		else
			if not table.find(Element.Options, Value) then
				Element.Value = "..."
			else
				Element.Value = Value
			end
		end
		RenderOptions()
		UpdateSelectedLabel()
		if not Silent then
			SafeCall(Callback, Element.Value)
			FireFlag(Element)
		end
		return Element
	end

	function Element:Get()
		return Element.Value
	end

	function Element:GetSelected()
		if Multi then
			local Copy = {}
			for _, Item in ipairs(Element.Value) do table.insert(Copy, Item) end
			return Copy
		end
		return Element.Value
	end

	function Element:Select(Value)
		if Multi then
			if not table.find(Element.Value, Value) and table.find(Element.Options, Value) then
				table.insert(Element.Value, Value)
				Element:Set(Element.Value)
			end
		else
			Element:Set(Value)
		end
		return Element
	end

	function Element:Deselect(Value)
		if Multi then
			local Index = table.find(Element.Value, Value)
			if Index then
				table.remove(Element.Value, Index)
				Element:Set(Element.Value)
			end
		elseif Element.Value == Value then
			Element:Set("...")
		end
		return Element
	end

	function Element:SetValues(Values)
		if Multi then
			Element:Set(type(Values) == "table" and Values or { Values })
		else
			Element:Set(type(Values) == "table" and Values[1] or Values)
		end
		return Element
	end

	function Element:Clear()
		if Multi then
			Element.Value = {}
			Element:Set(Element.Value)
		else
			Element:Set("...")
		end
		return Element
	end

	function Element:Open()
		if not Element.Toggled then
			SetExpanded(true)
		end
		return Element
	end

	function Element:Close()
		if Element.Toggled then
			SetExpanded(false)
		end
		return Element
	end

	function Element:Destroy()
		Row.Frame:Destroy()
		return true
	end

	AddConnection(Row.Click.MouseButton1Click, function()
		SetExpanded(not Element.Toggled)
	end)

	if SearchBox then
		AddConnection(SearchBox:GetPropertyChangedSignal("Text"), function()
			local Query = SearchBox.Text:lower()
			for _, OptionName in ipairs(Element.Options) do
				local Option = Element.Buttons[OptionName]
				if Option then
					local Match = Query == "" or tostring(OptionName):lower():find(Query, 1, true) ~= nil
					Option.Visible = Match
				end
			end
			TaskWait()
			OptionsList.CanvasSize = UDim2.new(0, 0, 0, OptionsListLayout.AbsoluteContentSize.Y + 16)
			if Element.Toggled then SetExpanded(true) end
		end)
	end

	AddConnection(OptionsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		OptionsList.CanvasSize = UDim2.new(0, 0, 0, OptionsListLayout.AbsoluteContentSize.Y + 16)
		if Element.Toggled then SetExpanded(true, false) end
	end)

	if Multi then
		Element.Value = {}
		if type(DropdownConfig.Default) == "table" then
			for _, Item in ipairs(DropdownConfig.Default) do
				if table.find(DropdownConfig.Options or {}, Item) then
					table.insert(Element.Value, Item)
				end
			end
		end
	elseif DropdownConfig.Default ~= nil and table.find(DropdownConfig.Options or {}, DropdownConfig.Default) then
		Element.Value = DropdownConfig.Default
	end

	Element:Refresh(DropdownConfig.Options or {}, false)
	RegisterFlag(Element, DropdownConfig, "Dropdown", DropdownConfig.Save)
	OnThemeRefresh(function()
		if Row.Frame.Parent then
			RenderOptions()
			UpdateSelectedLabel()
		end
	end)
	OnLanguageRefresh(function()
		if Row.Frame.Parent then
			UpdateSelectedLabel()
		end
	end)
	UpdateSelectedLabel()

	return Element
end

------------------------------------------------------------------------------
-- [ 24 ] 按键绑定
------------------------------------------------------------------------------

local WhitelistedMouse = {
	Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3,
}
local BlacklistedKeys = {
	Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right,
	Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape,
	Enum.KeyCode.Return, Enum.KeyCode.Space,
}

local function CheckKey(List, Key)
	for _, Value in ipairs(List) do
		if Value == Key then return true end
	end
	return false
end

local function AddBind(ItemParent, Tab, BindConfig)
	BindConfig = BindConfig or {}
	local Name = BindConfig.Name or "按键绑定"
	local Hold = BindConfig.Hold == true
	local Callback = BindConfig.Callback

	local Row = CreateRow(ItemParent, 42, {
		Name = "Bind",
		Text = Name,
		TitleRight = 120,
	})

	local Chip = Create("Frame", {
		Name = "Chip",
		Size = UDim2.fromOffset(78, 26),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		BackgroundColor3 = CurrentTheme().Main,
		ZIndex = 3,
		Parent = Row.Frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	AddThemeObject(Chip, "Main", "BackgroundColor3")

	local ChipStroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = 0.4,
		Parent = Chip,
	})

	local ChipLabel = Create("TextLabel", {
		Name = "Value",
		Text = L("None"),
		TextColor3 = CurrentTheme().Text,
		TextSize = 11.5,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = Chip,
	})
	AddThemeObject(ChipLabel, "Text", "TextColor3")

	MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		Ripple = false,
	})

	local Element = { Type = "Bind", Value = nil, Binding = false }
	local Holding = false
	local PulseToken = 0

	local function RenderChip()
		local Binding = Element.Binding
		local Bound = Element.Value ~= nil
		ChipLabel.Text = Binding and L("Listening") or (Bound and Element.Value or L("None"))
		ChipLabel.TextColor3 = Binding and CurrentTheme().Accent or (Bound and CurrentTheme().Text or CurrentTheme().TextDark)
		Chip.Size = UDim2.fromOffset(math.max(78, ChipLabel.TextBounds.X + 24), 26)
		if not Binding then
			Tween(ChipStroke, TI.Normal, { Transparency = 0.4, Color = CurrentTheme().Stroke })
		end
	end

	local function StartPulse()
		PulseToken = PulseToken + 1
		local MyToken = PulseToken
		TaskSpawn(function()
			local Flip = false
			while Element.Binding and PulseToken == MyToken do
				Flip = not Flip
				Tween(ChipStroke, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = Flip and 0.05 or 0.65,
					Color = CurrentTheme().Accent,
				})
				TaskWait(0.5)
			end
		end)
	end

	function Element:Set(Key, Silent)
		if Key == nil then
			Element.Value = nil
		else
			Element.Value = (typeof(Key) == "EnumItem") and Key.Name or tostring(Key)
		end
		Element.Binding = false
		RenderChip()
		if not Silent then
			FireFlag(Element)
		end
		return Element
	end

	function Element:Get()
		return Element.Value
	end

	function Element:Clear()
		return Element:Set(nil)
	end

	function Element:Destroy()
		Row.Frame:Destroy()
		return true
	end

	AddConnection(Row.Click.MouseButton1Click, function()
		if Element.Binding then
			Element.Binding = false
			RenderChip()
			return
		end
		Element.Binding = true
		RenderChip()
		StartPulse()
	end)

	AddConnection(Row.Click.MouseButton2Click, function()
		Element:Clear()
	end)

	AddConnection(UserInputService.InputBegan, function(Input)
		if Element.Binding then
			-- 点到本行本身视为取消监听, 而不是绑定鼠标左键
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				local Position = Vector2.new(Input.Position.X, Input.Position.Y)
				local Origin = Row.Frame.AbsolutePosition
				local Size = Row.Frame.AbsoluteSize
				if Position.X >= Origin.X and Position.X <= Origin.X + Size.X
					and Position.Y >= Origin.Y and Position.Y <= Origin.Y + Size.Y then
					Element.Binding = false
					RenderChip()
					return
				end
			end
			local Key
			if Input.UserInputType == Enum.UserInputType.Keyboard then
				if not CheckKey(BlacklistedKeys, Input.KeyCode) then
					Key = Input.KeyCode
				elseif Input.KeyCode == Enum.KeyCode.Backspace then
					Element:Set(nil)
					return
				end
			elseif CheckKey(WhitelistedMouse, Input.UserInputType) then
				Key = Input.UserInputType
			end
			if Key then
				Element:Set(Key)
			end
			return
		end
		if UserInputService:GetFocusedTextBox() then return end
		if Element.Value == nil then return end
		local Matches = (Input.KeyCode.Name == Element.Value) or (Input.UserInputType.Name == Element.Value)
		if Matches then
			if Hold then
				Holding = true
				SafeCall(Callback, true)
			else
				SafeCall(Callback)
			end
		end
	end)

	AddConnection(UserInputService.InputEnded, function(Input)
		if not Hold or not Holding then return end
		local Matches = (Input.KeyCode.Name == Element.Value) or (Input.UserInputType.Name == Element.Value)
		if Matches then
			Holding = false
			SafeCall(Callback, false)
		end
	end)

	Element:Set(BindConfig.Default ~= nil and BindConfig.Default or nil, true)
	RegisterFlag(Element, BindConfig, "Bind", BindConfig.Save)
	OnThemeRefresh(function()
		if Row.Frame.Parent then RenderChip() end
	end)
	OnLanguageRefresh(function()
		if Row.Frame.Parent then RenderChip() end
	end)

	return Element
end

------------------------------------------------------------------------------
-- [ 25 ] 输入框
------------------------------------------------------------------------------

local function AddTextbox(ItemParent, Tab, TextboxConfig)
	TextboxConfig = TextboxConfig or {}
	local Name = TextboxConfig.Name or "输入框"
	local Callback = TextboxConfig.Callback

	local Row = CreateRow(ItemParent, 42, {
		Name = "Textbox",
		Text = Name,
		TitleRight = 220,
	})

	local Box = Create("Frame", {
		Name = "Input",
		Size = UDim2.new(0, 198, 0, 28),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		BackgroundColor3 = CurrentTheme().Main,
		ZIndex = 3,
		Parent = Row.Frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 9) }) })
	AddThemeObject(Box, "Main", "BackgroundColor3")

	local BoxStroke = Create("UIStroke", {
		Color = CurrentTheme().Stroke,
		Thickness = 1,
		Transparency = 0.45,
		Parent = Box,
	})

	local Input = Create("TextBox", {
		Name = "Value",
		Text = tostring(TextboxConfig.Default or ""),
		PlaceholderText = TextboxConfig.Placeholder or L("Placeholder"),
		PlaceholderColor3 = CurrentTheme().TextDark,
		TextColor3 = CurrentTheme().Text,
		TextSize = 12,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = TextboxConfig.ClearOnFocus == true,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Parent = Box,
	})
	AddThemeObject(Input, "Text", "TextColor3")

	local Element = { Type = "Textbox", Value = Input.Text }

	local function Focus(State)
		Tween(BoxStroke, TI.Fast, {
			Transparency = State and 0 or 0.45,
			Color = State and CurrentTheme().Accent or CurrentTheme().Stroke,
		})
		Tween(Box, TI.Fast, { BackgroundColor3 = State and CurrentTheme().Card or CurrentTheme().Main })
	end

	AddConnection(Input.Focused, function() Focus(true) end)
	AddConnection(Input.FocusLost, function(EnterPressed)
		Focus(false)
		Element.Value = Input.Text
		SafeCall(Callback, Input.Text, EnterPressed)
		FireFlag(Element)
		if TextboxConfig.TextDisappear then
			Input.Text = ""
			Element.Value = ""
		end
	end)

	MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		Ripple = false,
	})
	AddConnection(Row.Click.MouseButton1Click, function()
		Input:CaptureFocus()
	end)

	function Element:Set(Text)
		Input.Text = tostring(Text or "")
		self.Value = Input.Text
		return self
	end
	function Element:Get()
		return Input.Text
	end
	function Element:Focus()
		Input:CaptureFocus()
		return self
	end
	function Element:Destroy()
		Row.Frame:Destroy()
		return true
	end

	RegisterFlag(Element, TextboxConfig, "Textbox", TextboxConfig.Save)
	OnThemeRefresh(function()
		if Row.Frame.Parent and not Input:IsFocused() then
			BoxStroke.Color = CurrentTheme().Stroke
			Box.BackgroundColor3 = CurrentTheme().Main
		end
	end)
	OnLanguageRefresh(function()
		if Row.Frame.Parent and TextboxConfig.Placeholder == nil then
			Input.PlaceholderText = L("Placeholder")
		end
	end)

	return Element
end

------------------------------------------------------------------------------
-- [ 26 ] 取色器 ( 支持拖动取色 / 十六进制输入 / 预设色板 )
------------------------------------------------------------------------------

local function AddColorpicker(ItemParent, Tab, ColorpickerConfig)
	ColorpickerConfig = ColorpickerConfig or {}
	local Name = ColorpickerConfig.Name or "取色器"
	local Callback = ColorpickerConfig.Callback
	local Presets = ColorpickerConfig.Presets or DefaultPresets

	local Row = CreateRow(ItemParent, 42, {
		Name = "Colorpicker",
		Text = Name,
		TitleRight = 116,
	})

	local Swatch = Create("Frame", {
		Name = "Swatch",
		Size = UDim2.fromOffset(22, 22),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -38, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 3,
		Parent = Row.Frame,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 7) }) })
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.25, Parent = Swatch })

	local Chevron = IconKit.Chevron(Row.Frame, 14, CurrentTheme().TextDark, 1.5, "down")
	Chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	Chevron.Position = UDim2.new(1, -17, 0, 21)

	local Body = Create("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = Row.Frame,
	})

	local SatVal = Create("ImageLabel", {
		Name = "SatVal",
		Position = UDim2.new(0, 14, 0, 12),
		Size = UDim2.new(1, -58, 0, 102),
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderSizePixel = 0,
		Image = "rbxassetid://4155801252",
		ZIndex = 3,
		Parent = Body,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = SatVal })

	local Cursor = Create("ImageLabel", {
		Name = "Cursor",
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = "http://www.roblox.com/asset/?id=4805639000",
		ZIndex = 4,
		Parent = SatVal,
	})

	local Hue = Create("Frame", {
		Name = "Hue",
		Position = UDim2.new(1, -32, 0, 12),
		Size = UDim2.new(0, 18, 0, 102),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = Body,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Create("UIGradient", {
			Rotation = 270,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 4)),
				ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234, 255, 0)),
				ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21, 255, 0)),
				ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0, 17, 255)),
				ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255, 0, 251)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 4)),
			}),
		}),
	})
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = Hue })

	local HueKnob = Create("Frame", {
		Name = "HueKnob",
		Size = UDim2.new(1, 6, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = Hue,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	Create("UIStroke", { Color = Color3.fromRGB(20, 20, 20), Thickness = 1, Transparency = 0.3, Parent = HueKnob })

	-- 底部: 十六进制输入 / RGB 预览 / 预设色板
	local HexBox = Create("Frame", {
		Name = "HexBox",
		Position = UDim2.new(0, 14, 0, 126),
		Size = UDim2.new(0, 96, 0, 28),
		BackgroundColor3 = CurrentTheme().Main,
		ZIndex = 3,
		Parent = Body,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	AddThemeObject(HexBox, "Main", "BackgroundColor3")
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = HexBox })

	local HexInput = Create("TextBox", {
		Name = "Hex",
		Text = "#FFFFFF",
		TextColor3 = CurrentTheme().Text,
		TextSize = 11.5,
		Font = Fonts.SemiBold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Size = UDim2.fromScale(1, 1),
		Parent = HexBox,
	})
	AddThemeObject(HexInput, "Text", "TextColor3")

	local RGBLabel = Create("TextLabel", {
		Name = "RGB",
		Text = "",
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 11,
		Font = Fonts.Medium,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 118, 0, 126),
		Size = UDim2.new(0, 62, 0, 28),
		ZIndex = 3,
		Parent = Body,
	})
	AddThemeObject(RGBLabel, "TextDark", "TextColor3")

	local PresetHolder = Create("Frame", {
		Name = "Presets",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 162),
		Size = UDim2.new(0, 200, 0, 20),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = Body,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	})

	local Element = { Type = "Colorpicker", Value = ColorpickerConfig.Default or Color3.fromRGB(255, 255, 255), Toggled = false }
	local ColorH, ColorS, ColorV = Color3.toHSV(Element.Value)

	local function Render()
		local Color = Color3.fromHSV(ColorH, ColorS, ColorV)
		Element.Value = Color
		SatVal.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
		Swatch.BackgroundColor3 = Color
		Cursor.Position = UDim2.fromScale(ColorS, 1 - ColorV)
		HueKnob.Position = UDim2.new(0.5, 0, 1 - ColorH, 0)
		if not HexInput:IsFocused() then
			HexInput.Text = Color3ToHex(Color)
		end
		RGBLabel.Text = string.format("%d, %d, %d",
			math.floor(Color.R * 255 + 0.5), math.floor(Color.G * 255 + 0.5), math.floor(Color.B * 255 + 0.5))
	end

	MakeInteractive(Row.Click, Row.Frame, {
		BaseToken = "Card",
		HoverToken = "CardHover",
		Ripple = false,
	})

	local function SetExpanded(State, Animate)
		Element.Toggled = State
		local Info = Animate == false and TI.Instant or TI.Smooth
		Tween(Chevron, Info, { Rotation = State and 180 or 0 })
		Tween(Body, Info, { Size = UDim2.new(1, 0, 0, State and 192 or 0) })
		Tween(Row.Frame, Info, { Size = UDim2.new(1, 0, 0, State and 238 or 42) })
	end

	BindDrag(SatVal, function(Position)
		local AlphaX = Clamp01((Position.X - SatVal.AbsolutePosition.X) / math.max(1, SatVal.AbsoluteSize.X))
		local AlphaY = Clamp01((Position.Y - SatVal.AbsolutePosition.Y) / math.max(1, SatVal.AbsoluteSize.Y))
		ColorS = AlphaX
		ColorV = 1 - AlphaY
		Render()
		SafeCall(Callback, Element.Value)
	end, function()
		FireFlag(Element)
	end)

	BindDrag(Hue, function(Position)
		local AlphaY = Clamp01((Position.Y - Hue.AbsolutePosition.Y) / math.max(1, Hue.AbsoluteSize.Y))
		ColorH = 1 - AlphaY
		Render()
		SafeCall(Callback, Element.Value)
	end, function()
		FireFlag(Element)
	end)

	AddConnection(SatVal.InputBegan, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Tween(Cursor, TI.Fast, { Size = UDim2.fromOffset(24, 24) })
		end
	end)
	AddConnection(SatVal.InputEnded, function()
		Tween(Cursor, TI.Spring, { Size = UDim2.fromOffset(18, 18) })
	end)

	for Index, PresetColor in ipairs(Presets) do
		local Preset = Create("TextButton", {
			Name = "Preset" .. Index,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = PresetColor,
			Size = UDim2.fromOffset(18, 18),
			LayoutOrder = Index,
			Parent = PresetHolder,
		}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.4, Parent = Preset })
		AddConnection(Preset.MouseEnter, function()
			Tween(Preset, TI.Fast, { Size = UDim2.fromOffset(22, 22) })
		end)
		AddConnection(Preset.MouseLeave, function()
			Tween(Preset, TI.Fast, { Size = UDim2.fromOffset(18, 18) })
		end)
		AddConnection(Preset.MouseButton1Click, function()
			Element:Set(PresetColor)
		end)
	end

	AddConnection(HexInput.FocusLost, function()
		local Parsed = HexToColor3(HexInput.Text)
		if Parsed then
			Element:Set(Parsed)
		else
			Render()
		end
	end)

	AddConnection(Row.Click.MouseButton1Click, function()
		SetExpanded(not Element.Toggled)
	end)

	function Element:Set(Color, Silent)
		if typeof(Color) ~= "Color3" then return self end
		ColorH, ColorS, ColorV = Color3.toHSV(Color)
		Render()
		if not Silent then
			SafeCall(Callback, Element.Value)
			FireFlag(Element)
		end
		return self
	end

	function Element:Get()
		return Element.Value
	end

	function Element:Open()
		if not Element.Toggled then SetExpanded(true) end
		return self
	end

	function Element:Close()
		if Element.Toggled then SetExpanded(false) end
		return self
	end

	function Element:Destroy()
		Row.Frame:Destroy()
		return true
	end

	RegisterFlag(Element, ColorpickerConfig, "Colorpicker", ColorpickerConfig.Save)
	OnThemeRefresh(function()
		if Row.Frame.Parent then
			Chevron.Rotation = Element.Toggled and 180 or 0
		end
	end)
	Render()

	return Element
end

------------------------------------------------------------------------------
-- [ 27 ] 新增小组件: 分隔线 / 占位块 / 图片
------------------------------------------------------------------------------

local function AddDivider(ItemParent, Tab, Config)
	Config = Config or {}
	local Holder = Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 9),
		BackgroundTransparency = 1,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	})
	local Line = FadeDivider(Holder, {
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	})
	local Element = { Type = "Divider" }
	function Element:Destroy()
		Holder:Destroy()
	end
	function Element:SetColor(Color)
		Line.BackgroundColor3 = Color
	end
	return Element
end

local function AddSpace(ItemParent, Tab, Height)
	if type(Height) == "table" then Height = Height.Height end
	local Holder = Create("Frame", {
		Name = "Space",
		Size = UDim2.new(1, 0, 0, tonumber(Height) or 6),
		BackgroundTransparency = 1,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	})
	local Element = { Type = "Space" }
	function Element:Set(NewHeight)
		Holder.Size = UDim2.new(1, 0, 0, tonumber(NewHeight) or 6)
	end
	function Element:Destroy()
		Holder:Destroy()
	end
	return Element
end

local function AddImage(ItemParent, Tab, Config)
	if type(Config) == "string" then Config = { Image = Config } end
	Config = Config or {}
	local Caption = Config.Caption
	local Height = tonumber(Config.Height) or 130
	local Radius = Config.Rounded == false and 0 or 12
	local InnerRadius = Config.Rounded == false and 0 or 9

	local Card = Create("Frame", {
		Name = "Image",
		Size = UDim2.new(1, 0, 0, Height + (Caption and 24 or 0)),
		BackgroundColor3 = CurrentTheme().Card,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, Radius) }) })
	AddThemeObject(Card, "Card", "BackgroundColor3")
	Create("UIStroke", { Color = CurrentTheme().Stroke, Thickness = 1, Transparency = 0.5, Parent = Card })
	EnsureScale(Card, 1)

	local ImageLabel = Create("ImageLabel", {
		Name = "Image",
		Size = UDim2.new(1, -16, 0, Height - 16),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = CurrentTheme().Main,
		BorderSizePixel = 0,
		Image = Config.Image or "",
		ImageTransparency = Config.Transparency or 0,
		ScaleType = Config.ScaleType == "Crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit,
		Parent = Card,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, InnerRadius) }) })
	AddThemeObject(ImageLabel, "Main", "BackgroundColor3")

	local CaptionLabel
	if Caption then
		CaptionLabel = Create("TextLabel", {
			Name = "Caption",
			Text = tostring(Caption),
			TextColor3 = CurrentTheme().TextDark,
			TextSize = 11.5,
			Font = Fonts.Medium,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 12, 0, Height),
			Size = UDim2.new(1, -24, 0, 20),
			Parent = Card,
		})
		AddThemeObject(CaptionLabel, "TextDark", "TextColor3")
	end

	local Element = { Type = "Image", Value = Config.Image }
	function Element:Set(ImageId)
		self.Value = ImageId
		ImageLabel.Image = ImageId
		return self
	end
	function Element:SetCaption(Text)
		if CaptionLabel then CaptionLabel.Text = tostring(Text) end
		return self
	end
	function Element:Destroy()
		Card:Destroy()
	end
	return Element
end

------------------------------------------------------------------------------
-- [ 28 ] 分组 ( 可折叠 )
------------------------------------------------------------------------------

local function AddSection(ItemParent, Tab, SectionConfig)
	SectionConfig = SectionConfig or {}
	local Name = SectionConfig.Name or "分组"

	local Section = Create("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = NextLayoutOrder(ItemParent),
		Parent = ItemParent,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	EnsureScale(Section, 1)

	local Header = Create("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = Section,
	})

	local Bar = Create("Frame", {
		Name = "Bar",
		Size = UDim2.fromOffset(3, 12),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		BackgroundColor3 = CurrentTheme().Accent,
		BorderSizePixel = 0,
		Parent = Header,
	}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	AddAccentObject(Bar, "BackgroundColor3", "color")

	local Title = Create("TextLabel", {
		Name = "Title",
		Text = Name,
		TextColor3 = CurrentTheme().TextDark,
		TextSize = 12.5,
		Font = Fonts.Bold,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 13, 0.5, 0),
		Size = UDim2.new(1, -46, 0, 16),
		Parent = Header,
	})
	AddThemeObject(Title, "TextDark", "TextColor3")

	local Chevron = IconKit.Chevron(Header, 13, CurrentTheme().TextDark, 1.4, "down")
	Chevron.AnchorPoint = Vector2.new(0.5, 0.5)
	Chevron.Position = UDim2.new(1, -12, 0.5, 0)

	local HeaderClick = Create("TextButton", {
		Name = "Click",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = Header,
	}, { Create("UICorner", { CornerRadius = UDim.new(0, 8) }) })

	local Holder = Create("Frame", {
		Name = "Holder",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = Section,
	}, {
		Create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	local HolderList = Holder.UIListLayout

	local Elements = BuildElements(Holder, Tab)

	local Collapsed = false
	local function SetCollapsed(State, Animate)
		Collapsed = State == true
		Tween(Chevron, Animate == false and TI.Instant or TI.Normal, { Rotation = Collapsed and -90 or 0 })
		Tween(Title, TI.Fast, { TextColor3 = Collapsed and CurrentTheme().TextDark or CurrentTheme().Text })
		if Collapsed then
			Holder.AutomaticSize = Enum.AutomaticSize.None
			Holder.Size = UDim2.new(1, 0, 0, Holder.AbsoluteSize.Y)
			Holder.ClipsDescendants = true
			Tween(Holder, TI.Smooth, { Size = UDim2.new(1, 0, 0, 0) })
			TaskDelay(0.42, function()
				if Collapsed then Holder.Visible = false end
			end)
		else
			Holder.Visible = true
			Holder.AutomaticSize = Enum.AutomaticSize.None
			Holder.ClipsDescendants = true
			Holder.Size = UDim2.new(1, 0, 0, 0)
			local Target = HolderList.AbsoluteContentSize.Y
			Tween(Holder, TI.Smooth, { Size = UDim2.new(1, 0, 0, Target) })
			TaskDelay(0.42, function()
				if not Collapsed then
					Holder.AutomaticSize = Enum.AutomaticSize.Y
					Holder.ClipsDescendants = false
				end
			end)
		end
	end

	AddConnection(HeaderClick.MouseEnter, function()
		Tween(Bar, TI.Fast, { Size = UDim2.fromOffset(3, 16) })
	end)
	AddConnection(HeaderClick.MouseLeave, function()
		Tween(Bar, TI.Fast, { Size = UDim2.fromOffset(3, 12) })
	end)
	AddConnection(HeaderClick.MouseButton1Click, function()
		SetCollapsed(not Collapsed)
	end)
	AddConnection(HolderList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		if not Collapsed then
			if Holder.AutomaticSize == Enum.AutomaticSize.None and Holder.Visible then
				Holder.Size = UDim2.new(1, 0, 0, HolderList.AbsoluteContentSize.Y)
			end
		end
	end)

	local SectionObject = {}
	for Key, Function in pairs(Elements) do
		SectionObject[Key] = Function
	end
	SectionObject.Type = "Section"
	SectionObject.Name = Name
	SectionObject.Holder = Holder
	SectionObject.Frame = Section

	function SectionObject:SetName(NewName)
		self.Name = NewName
		Title.Text = tostring(NewName)
		return self
	end

	function SectionObject:SetCollapsed(State)
		if (State == true) ~= Collapsed then
			SetCollapsed(State == true)
		end
		return self
	end

	function SectionObject:Toggle()
		SetCollapsed(not Collapsed)
		return self
	end

	function SectionObject:IsCollapsed()
		return Collapsed
	end

	function SectionObject:Destroy()
		Section:Destroy()
		return true
	end

	return SectionObject
end

------------------------------------------------------------------------------
-- [ 29 ] 组件装配
------------------------------------------------------------------------------

BuildElements = function(ItemParent, Tab)
	local Functions = {}
	Functions.AddLabel = function(_, ...) return AddLabel(ItemParent, Tab, ...) end
	Functions.AddParagraph = function(_, ...) return AddParagraph(ItemParent, Tab, ...) end
	Functions.AddButton = function(_, ...) return AddButton(ItemParent, Tab, ...) end
	Functions.AddToggle = function(_, ...) return AddToggle(ItemParent, Tab, ...) end
	Functions.AddSlider = function(_, ...) return AddSlider(ItemParent, Tab, ...) end
	Functions.AddDropdown = function(_, ...) return AddDropdown(ItemParent, Tab, ...) end
	Functions.AddBind = function(_, ...) return AddBind(ItemParent, Tab, ...) end
	Functions.AddKeybind = Functions.AddBind
	Functions.AddTextbox = function(_, ...) return AddTextbox(ItemParent, Tab, ...) end
	Functions.AddInput = Functions.AddTextbox
	Functions.AddColorpicker = function(_, ...) return AddColorpicker(ItemParent, Tab, ...) end
	Functions.AddDivider = function(_, ...) return AddDivider(ItemParent, Tab, ...) end
	Functions.AddSpace = function(_, ...) return AddSpace(ItemParent, Tab, ...) end
	Functions.AddImage = function(_, ...) return AddImage(ItemParent, Tab, ...) end
	Functions.AddSection = function(_, ...) return AddSection(ItemParent, Tab, ...) end
	return Functions
end

------------------------------------------------------------------------------
-- [ 30 ] 配置系统 / 存档
------------------------------------------------------------------------------

local function GetConfigPath(Name)
	local Folder = tostring(OrionLib.Folder or "Orion")
	return Folder .. "/" .. tostring(Name) .. ".txt"
end

local function HasFileApi()
	return type(writefile) == "function" and type(readfile) == "function"
end

local function CollectFlags()
	local Data = {}
	for FlagName, Element in pairs(OrionLib.Flags) do
		if Element and Element.Save then
			if Element.Type == "Colorpicker" then
				Data[FlagName] = PackColor(Element.Value)
			elseif Element.Type == "Dropdown" and type(Element.Value) == "table" then
				local Copy = {}
				for _, Item in ipairs(Element.Value) do table.insert(Copy, Item) end
				Data[FlagName] = Copy
			elseif Element.Type == "Bind" then
				Data[FlagName] = Element.Value
			else
				Data[FlagName] = Element.Value
			end
		end
	end
	return Data
end

function OrionLib:GetConfigJSON()
	local Ok, Encoded = pcall(function() return HttpService:JSONEncode(CollectFlags()) end)
	if Ok then return Encoded end
	return "{}"
end

function OrionLib:SaveConfig(Name)
	Name = Name or game.GameId
	if not HasFileApi() or type(isfolder) ~= "function" or type(makefolder) ~= "function" then
		return false
	end
	local Folder = tostring(OrionLib.Folder or "Orion")
	if not isfolder(Folder) then
		local Ok = pcall(makefolder, Folder)
		if not Ok then return false end
	end
	local Encoded = OrionLib:GetConfigJSON()
	local Ok = pcall(writefile, GetConfigPath(Name), Encoded)
	if not Ok then
		warn("[OrionLib] 配置保存失败: " .. GetConfigPath(Name))
	end
	return Ok
end

function OrionLib:LoadConfigJSON(JSON)
	local Ok, Data = pcall(function() return HttpService:JSONDecode(JSON) end)
	if not Ok or type(Data) ~= "table" then return false, 0 end
	local Applied = 0
	for FlagName, Value in pairs(Data) do
		local Element = OrionLib.Flags[FlagName]
		if Element and type(Element.Set) == "function" then
			TaskSpawn(function()
				if Element.Type == "Colorpicker" then
					SafeCall(Element.Set, Element, UnpackColor(Value))
				else
					SafeCall(Element.Set, Element, Value)
				end
			end)
			Applied = Applied + 1
		else
			warn("[OrionLib] 配置中存在未知 Flag: " .. tostring(FlagName))
		end
	end
	return true, Applied
end

function OrionLib:LoadConfig(Name)
	Name = Name or game.GameId
	if not HasFileApi() or type(isfile) ~= "function" then return false end
	local Path = GetConfigPath(Name)
	if not isfile(Path) then return false end
	local Ok, Body = pcall(readfile, Path)
	if not Ok or type(Body) ~= "string" then return false end
	return OrionLib:LoadConfigJSON(Body)
end

function OrionLib:ListConfigs()
	if type(listfiles) ~= "function" or type(isfolder) ~= "function" then return {} end
	local Folder = tostring(OrionLib.Folder or "Orion")
	if not isfolder(Folder) then return {} end
	local Ok, Files = pcall(listfiles, Folder)
	if not Ok or type(Files) ~= "table" then return {} end
	local Names = {}
	for _, File in ipairs(Files) do
		local Base = tostring(File):match("([^/\\]+)%.txt$")
		if Base then table.insert(Names, Base) end
	end
	return Names
end

function OrionLib:DeleteConfig(Name)
	if type(delfile) ~= "function" then return false end
	return pcall(delfile, GetConfigPath(Name))
end

------------------------------------------------------------------------------
-- [ 31 ] Flag 接口
------------------------------------------------------------------------------

function OrionLib:GetFlag(FlagName)
	local Element = OrionLib.Flags[FlagName]
	if not Element then return nil end
	if type(Element.Get) == "function" then return Element:Get() end
	return Element.Value
end

function OrionLib:SetFlag(FlagName, Value)
	local Element = OrionLib.Flags[FlagName]
	if not Element or type(Element.Set) ~= "function" then return false end
	Element:Set(Value)
	return true
end

function OrionLib:GetFlags()
	local Map = {}
	for FlagName, Element in pairs(OrionLib.Flags) do
		if type(Element.Get) == "function" then
			Map[FlagName] = Element:Get()
		else
			Map[FlagName] = Element.Value
		end
	end
	return Map
end

function OrionLib:OnFlagChanged(Callback)
	return OrionLib.FlagChanged:Connect(Callback)
end

------------------------------------------------------------------------------
-- [ 32 ] 图标包 ( 可选: 自定义图标源 )
------------------------------------------------------------------------------

function OrionLib:SetIconSources(Sources)
	if type(Sources) ~= "table" then return false end
	IconPack.Sources = Sources
	IconPack.Icons = {}
	IconPack.Loaded = false
	TaskSpawn(function()
		SafeCall(FetchIconPack)
	end)
	return true
end

function OrionLib:GetIcon(IconName)
	return GetIcon(IconName)
end

------------------------------------------------------------------------------
-- [ 33 ] 卸载
------------------------------------------------------------------------------

function OrionLib:Destroy()
	SafeCall(OrionLib.ClearNotifications, OrionLib)
	for _, Connection in ipairs(OrionLib.Connections) do
		pcall(function() Connection:Disconnect() end)
	end
	table.clear(OrionLib.Connections)
	pcall(function() Orion:Destroy() end)
	OrionLib.Flags = {}
	OrionLib.ThemeObjects = {}
	OrionLib.AccentObjects = {}
	OrionLib.Interactions = {}
	OrionLib.HoverState = {}
	OrionLib.RefreshHandlers = {}
	OrionLib.Window = nil
end

OrionLib.Unload = OrionLib.Destroy

return OrionLib
