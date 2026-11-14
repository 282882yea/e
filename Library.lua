--!nocheck
--[[
	Nova UI — a single-file Roblox UI library for script executors.

	local Nova = loadstring(game:HttpGet(URL))()
	local Window = Nova:CreateWindow({ Title = "My Hub" })
	local Tab = Window:AddTab("Main")
	Tab:AddToggle({ Name = "Enabled", Flag = "Enabled", Callback = print })

	See README.md for the full API.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Library = {
	Version = "1.0.0",
	Flags = {}, -- [flag] = current value
	Options = {}, -- [flag] = element object
	Themes = {},
	Theme = nil,
	Unloaded = false,
	_connections = {},
	_bindings = {},
	_themeCallbacks = {},
	_listening = false,
	_gui = nil,
}

---------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------

Library.Themes.Dark = {
	Background = Color3.fromRGB(24, 24, 28),
	Sidebar = Color3.fromRGB(19, 19, 22),
	Section = Color3.fromRGB(30, 30, 35),
	Element = Color3.fromRGB(38, 38, 45),
	ElementHover = Color3.fromRGB(46, 46, 54),
	Inset = Color3.fromRGB(22, 22, 26),
	Stroke = Color3.fromRGB(52, 52, 62),
	Accent = Color3.fromRGB(104, 124, 255),
	Text = Color3.fromRGB(236, 236, 242),
	SubText = Color3.fromRGB(150, 150, 162),
}

Library.Themes.Midnight = {
	Background = Color3.fromRGB(13, 15, 23),
	Sidebar = Color3.fromRGB(10, 11, 18),
	Section = Color3.fromRGB(18, 21, 32),
	Element = Color3.fromRGB(25, 29, 44),
	ElementHover = Color3.fromRGB(32, 37, 56),
	Inset = Color3.fromRGB(11, 13, 20),
	Stroke = Color3.fromRGB(40, 46, 70),
	Accent = Color3.fromRGB(0, 190, 230),
	Text = Color3.fromRGB(228, 234, 248),
	SubText = Color3.fromRGB(130, 142, 170),
}

Library.Themes.Rose = {
	Background = Color3.fromRGB(27, 22, 26),
	Sidebar = Color3.fromRGB(21, 17, 20),
	Section = Color3.fromRGB(34, 27, 32),
	Element = Color3.fromRGB(44, 35, 41),
	ElementHover = Color3.fromRGB(54, 43, 50),
	Inset = Color3.fromRGB(23, 18, 22),
	Stroke = Color3.fromRGB(66, 52, 60),
	Accent = Color3.fromRGB(240, 98, 146),
	Text = Color3.fromRGB(244, 234, 238),
	SubText = Color3.fromRGB(168, 148, 156),
}

Library.Themes.Light = {
	Background = Color3.fromRGB(244, 244, 248),
	Sidebar = Color3.fromRGB(232, 232, 238),
	Section = Color3.fromRGB(255, 255, 255),
	Element = Color3.fromRGB(238, 238, 244),
	ElementHover = Color3.fromRGB(228, 228, 236),
	Inset = Color3.fromRGB(250, 250, 252),
	Stroke = Color3.fromRGB(208, 208, 218),
	Accent = Color3.fromRGB(70, 96, 240),
	Text = Color3.fromRGB(28, 28, 36),
	SubText = Color3.fromRGB(108, 108, 122),
}

Library.Theme = Library.Themes.Dark

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local FONT = Enum.Font.Gotham
local FONT_MEDIUM = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_MED = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tween(instance, info, props)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

local function connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(Library._connections, conn)
	return conn
end

-- Sets theme-driven properties now and whenever the theme changes.
-- `map` is { PropertyName = "ThemeKey" }.
local function bind(instance, map)
	for prop, key in pairs(map) do
		instance[prop] = Library.Theme[key]
	end
	table.insert(Library._bindings, { instance, map })
	return instance
end

-- For state-dependent colours (e.g. a toggle that is accent only when on).
local function onTheme(fn)
	table.insert(Library._themeCallbacks, fn)
	fn(Library.Theme)
end

local function create(class, props, children)
	local instance = Instance.new(class)
	local parent, theme
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		elseif key == "Theme" then
			theme = value
		else
			instance[key] = value
		end
	end
	if theme then
		bind(instance, theme)
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

local function stroke()
	return create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 1,
		Theme = { Color = "Stroke" },
	})
end

local function padding(top, right, bottom, left)
	right = right or top
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right),
	})
end

local function label(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or FONT
	props.TextSize = props.TextSize or 13
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.Theme = props.Theme or { TextColor3 = "Text" }
	return create("TextLabel", props)
end

-- Invisible button covering its parent; the usual click target.
local function clickArea(parent)
	return create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = parent,
	})
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	task.spawn(function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[Nova UI] callback error: " .. tostring(err))
		end
	end, ...)
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Follows a press until it is released. `onMove` receives the pointer position.
local function trackDrag(startInput, onMove, onEnd)
	local moveConn, endConn
	moveConn = UserInputService.InputChanged:Connect(function(input)
		if input == startInput or input.UserInputType == Enum.UserInputType.MouseMovement then
			onMove(input.Position)
		end
	end)
	endConn = startInput.Changed:Connect(function()
		if startInput.UserInputState == Enum.UserInputState.End then
			moveConn:Disconnect()
			endConn:Disconnect()
			if onEnd then
				onEnd()
			end
		end
	end)
end

local function hoverEffect(button, target)
	button.MouseEnter:Connect(function()
		tween(target, TWEEN_FAST, { BackgroundColor3 = Library.Theme.ElementHover })
	end)
	button.MouseLeave:Connect(function()
		tween(target, TWEEN_FAST, { BackgroundColor3 = Library.Theme.Element })
	end)
end

local function round(value, step)
	local result = math.floor(value / step + 0.5) * step
	-- trim float noise such as 0.30000000000000004
	return tonumber(string.format("%.6f", result))
end

local function colorToHex(color)
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function hexToColor(hex)
	hex = tostring(hex):gsub("#", "")
	local r, g, b = hex:match("^(%x%x)(%x%x)(%x%x)$")
	if not r then
		return nil
	end
	return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function mountGui(gui)
	if type(gethui) == "function" then
		local ok = pcall(function()
			gui.Parent = gethui()
		end)
		if ok then
			return
		end
	end
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
	elseif type(protectgui) == "function" then
		pcall(protectgui, gui)
	end
	local ok = pcall(function()
		gui.Parent = CoreGui
	end)
	if not ok then
		-- No CoreGui access (e.g. running in Studio): fall back to PlayerGui.
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function getGui()
	if Library._gui then
		return Library._gui
	end
	local gui = create("ScreenGui", {
		Name = HttpService:GenerateGUID(false),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	mountGui(gui)
	Library._gui = gui
	return gui
end

---------------------------------------------------------------------
-- Theme switching
---------------------------------------------------------------------

function Library:SetTheme(theme)
	if type(theme) == "string" then
		theme = self.Themes[theme]
	end
	if type(theme) ~= "table" then
		return
	end
	-- Fill gaps from Dark so partial custom themes work.
	local resolved = {}
	for key, value in pairs(self.Themes.Dark) do
		resolved[key] = theme[key] or value
	end
	self.Theme = resolved
	for _, binding in ipairs(self._bindings) do
		local instance, map = binding[1], binding[2]
		for prop, key in pairs(map) do
			instance[prop] = resolved[key]
		end
	end
	for _, fn in ipairs(self._themeCallbacks) do
		fn(resolved)
	end
end

---------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------

local notifyHolder

function Library:Notify(config)
	if type(config) == "string" then
		config = { Content = config }
	end
	local duration = config.Duration or 4

	if not notifyHolder then
		notifyHolder = create("Frame", {
			Name = "Notifications",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, 280, 1, -32),
			BackgroundTransparency = 1,
			Parent = getGui(),
		}, {
			create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 8),
			}),
		})
	end

	local wrapper = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = notifyHolder,
	})

	local progress = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BorderSizePixel = 0,
		Theme = { BackgroundColor3 = "Accent" },
	})

	local card = create("Frame", {
		Position = UDim2.new(1, 300, 0, 0),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Section" },
		Parent = wrapper,
	}, {
		corner(8),
		stroke(),
		progress,
		create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			padding(10, 12, 12, 12),
			create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
			label({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Font = FONT_BOLD,
				Text = config.Title or "Notification",
			}),
			label({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = config.Content or "",
				Theme = { TextColor3 = "SubText" },
			}),
		}),
	})

	tween(card, TWEEN_MED, { Position = UDim2.new(0, 0, 0, 0) })
	tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

	task.delay(duration, function()
		if not wrapper.Parent then
			return
		end
		local out = tween(card, TWEEN_MED, { Position = UDim2.new(1, 300, 0, 0) })
		out.Completed:Wait()
		wrapper:Destroy()
	end)
end

---------------------------------------------------------------------
-- Elements (shared by tabs and sections)
---------------------------------------------------------------------

local Elements = {}
Elements.__index = Elements

local function nextOrder(self)
	self._order = (self._order or 0) + 1
	return self._order
end

local function makeRow(self, height)
	return create("Frame", {
		LayoutOrder = nextOrder(self),
		Size = UDim2.new(1, 0, 0, height or 36),
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Element" },
		Parent = self.Container,
	}, { corner(6) })
end

local function rowTitle(row, text)
	return label({
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -24, 0, 36),
		Font = FONT_MEDIUM,
		Text = text,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
end

-- Registers an element under its flag so it takes part in configs.
local function register(option, config)
	option.Flag = config.Flag
	if config.Flag then
		Library.Options[config.Flag] = option
		Library.Flags[config.Flag] = option.Value
	end
end

local function commit(option, callback, silent)
	if option.Flag then
		Library.Flags[option.Flag] = option.Value
	end
	if not silent then
		safeCall(callback, option.Value)
		safeCall(option._changed, option.Value)
	end
end

local function onChanged(option, fn)
	option._changed = fn
	return option
end

function Elements:AddLabel(text)
	local row = makeRow(self, 28)
	row.BackgroundTransparency = 1
	local text_ = label({
		Position = UDim2.new(0, 4, 0, 0),
		Size = UDim2.new(1, -8, 1, 0),
		Text = text or "",
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local option = { Type = "Label", Instance = row }
	function option:Set(value)
		text_.Text = tostring(value)
	end
	return option
end

function Elements:AddParagraph(config)
	local row = makeRow(self, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	padding(10, 12).Parent = row
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = row })
	local title = label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = FONT_BOLD,
		Text = config.Title or "",
		Parent = row,
	})
	local body = label({
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = config.Content or "",
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local option = { Type = "Paragraph", Instance = row }
	function option:Set(newConfig)
		title.Text = newConfig.Title or title.Text
		body.Text = newConfig.Content or body.Text
	end
	return option
end

function Elements:AddDivider()
	create("Frame", {
		LayoutOrder = nextOrder(self),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Theme = { BackgroundColor3 = "Stroke" },
		Parent = self.Container,
	})
end

function Elements:AddButton(config)
	local row = makeRow(self)
	local title = rowTitle(row, config.Name or "Button")
	label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 20, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = ">",
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local button = clickArea(row)
	hoverEffect(button, row)
	button.MouseButton1Click:Connect(function()
		row.BackgroundColor3 = Library.Theme.Accent
		tween(row, TWEEN_MED, { BackgroundColor3 = Library.Theme.ElementHover })
		safeCall(config.Callback)
	end)

	local option = { Type = "Button", Instance = row }
	function option:SetName(name)
		title.Text = name
	end
	function option:Fire()
		safeCall(config.Callback)
	end
	return option
end

function Elements:AddToggle(config)
	local row = makeRow(self)
	rowTitle(row, config.Name or "Toggle").Size = UDim2.new(1, -70, 0, 36)

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(8) })
	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		Parent = row,
	}, { corner(10), knob })

	local option = { Type = "Toggle", Value = config.Default == true, Instance = row }

	local function render(animated)
		local info = animated and TWEEN_FAST or TweenInfo.new(0)
		tween(track, info, {
			BackgroundColor3 = option.Value and Library.Theme.Accent or Library.Theme.Stroke,
		})
		tween(knob, info, {
			Position = option.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		})
	end

	function option:Set(value, silent)
		self.Value = value == true
		render(true)
		commit(self, config.Callback, silent)
	end
	option.OnChanged = onChanged

	local button = clickArea(row)
	hoverEffect(button, row)
	button.MouseButton1Click:Connect(function()
		option:Set(not option.Value)
	end)

	onTheme(function()
		render(false)
	end)
	register(option, config)
	if option.Value then
		safeCall(config.Callback, true)
	end
	return option
end

function Elements:AddSlider(config)
	local min, max = config.Min or 0, config.Max or 100
	local step = config.Increment or 1
	local suffix = config.Suffix or ""

	local row = makeRow(self, 50)
	rowTitle(row, config.Name or "Slider").Size = UDim2.new(1, -90, 0, 32)
	local valueLabel = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 0),
		Size = UDim2.new(0, 80, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})

	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		Theme = { BackgroundColor3 = "Accent" },
	}, { corner(3) })
	local bar = create("Frame", {
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(1, -24, 0, 6),
		Theme = { BackgroundColor3 = "Stroke" },
		Parent = row,
	}, { corner(3), fill })
	-- Taller invisible hit area so the thin bar is easy to grab.
	local hit = create("TextButton", {
		Position = UDim2.new(0, 12, 0, 24),
		Size = UDim2.new(1, -24, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	})

	local option = { Type = "Slider", Value = min, Instance = row }

	function option:Set(value, silent)
		value = math.clamp(round(tonumber(value) or min, step), min, max)
		self.Value = value
		valueLabel.Text = tostring(value) .. suffix
		tween(fill, TWEEN_FAST, { Size = UDim2.fromScale((value - min) / (max - min), 1) })
		commit(self, config.Callback, silent)
	end
	option.OnChanged = onChanged

	local function fromPointer(position)
		local alpha = math.clamp((position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local value = math.clamp(round(min + (max - min) * alpha, step), min, max)
		if value ~= option.Value then
			option:Set(value)
		end
	end

	hit.InputBegan:Connect(function(input)
		if isPress(input) then
			fromPointer(input.Position)
			trackDrag(input, fromPointer)
		end
	end)

	option:Set(config.Default or min, true)
	register(option, config)
	return option
end

function Elements:AddTextbox(config)
	local row = makeRow(self)
	rowTitle(row, config.Name or "Textbox").Size = UDim2.new(0.5, -12, 0, 36)

	local box = create("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.5, -8, 0, 24),
		Font = FONT,
		TextSize = 13,
		Text = config.Default or "",
		PlaceholderText = config.Placeholder or "...",
		ClearTextOnFocus = false,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Inset", TextColor3 = "Text", PlaceholderColor3 = "SubText" },
		Parent = row,
	}, { corner(4), stroke(), padding(0, 6) })

	local option = { Type = "Textbox", Value = config.Default or "", Instance = row }

	function option:Set(value, silent)
		value = tostring(value)
		if config.Numeric then
			value = tostring(tonumber(value) or tonumber(self.Value) or 0)
		end
		self.Value = value
		box.Text = value
		commit(self, config.Callback, silent)
	end
	option.OnChanged = onChanged

	box.FocusLost:Connect(function(enterPressed)
		if config.RequireEnter and not enterPressed then
			box.Text = option.Value
			return
		end
		option:Set(box.Text)
	end)

	register(option, config)
	return option
end

function Elements:AddKeybind(config)
	local row = makeRow(self)
	rowTitle(row, config.Name or "Keybind").Size = UDim2.new(1, -110, 0, 36)

	local keyLabel = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(90, 24),
		Font = FONT,
		TextSize = 12,
		AutoButtonColor = false,
		Theme = { BackgroundColor3 = "Inset", TextColor3 = "SubText" },
		Parent = row,
	}, { corner(4), stroke() })

	-- Value is a KeyCode name ("None" when unbound) so it serialises cleanly.
	local option = { Type = "Keybind", Value = "None", Instance = row }

	function option:Set(key, silent)
		if typeof(key) == "EnumItem" then
			key = key.Name
		end
		if type(key) ~= "string" or key == "Unknown" or not pcall(function()
			return Enum.KeyCode[key]
		end) then
			key = "None"
		end
		self.Value = key
		keyLabel.Text = key
		if self.Flag then
			Library.Flags[self.Flag] = key
		end
		if not silent then
			safeCall(config.ChangedCallback, key)
			safeCall(self._changed, key)
		end
	end
	option.OnChanged = onChanged

	keyLabel.MouseButton1Click:Connect(function()
		if Library._listening then
			return
		end
		Library._listening = true
		keyLabel.Text = "..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end
			conn:Disconnect()
			local key = input.KeyCode
			if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Backspace then
				option:Set("None")
			else
				option:Set(key)
			end
			-- Release on the next frame so this same press does not fire the bind.
			task.defer(function()
				Library._listening = false
			end)
		end)
	end)

	connect(UserInputService.InputBegan, function(input, processed)
		if processed or Library._listening or option.Value == "None" then
			return
		end
		if input.KeyCode.Name == option.Value then
			safeCall(config.Callback, option.Value)
		end
	end)

	option:Set(config.Default or "None", true)
	register(option, config)
	return option
end

function Elements:AddDropdown(config)
	local multi = config.Multi == true
	local options = config.Options or {}
	local ITEM_HEIGHT, MAX_VISIBLE = 28, 6

	local row = makeRow(self)
	rowTitle(row, config.Name or "Dropdown").Size = UDim2.new(0.5, -12, 0, 36)
	local valueLabel = label({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 0),
		Size = UDim2.new(0.5, -32, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local arrow = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(16, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = ">",
		Theme = { TextColor3 = "SubText" },
		Parent = row,
	})
	local header = clickArea(row)
	header.Size = UDim2.new(1, 0, 0, 36)
	hoverEffect(header, row)

	local listLayout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	local list = create("ScrollingFrame", {
		Position = UDim2.new(0, 8, 0, 38),
		Size = UDim2.new(1, -16, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { ScrollBarImageColor3 = "Stroke" },
		Parent = row,
	}, { listLayout })

	local option = { Type = "Dropdown", Value = multi and {} or nil, Instance = row }
	local open = false
	local items = {}

	local function isSelected(name)
		if multi then
			return table.find(option.Value, name) ~= nil
		end
		return option.Value == name
	end

	local function render()
		if multi then
			valueLabel.Text = #option.Value > 0 and table.concat(option.Value, ", ") or "None"
		else
			valueLabel.Text = option.Value ~= nil and tostring(option.Value) or "None"
		end
		for name, item in pairs(items) do
			local selected = isSelected(name)
			item.TextColor3 = selected and Library.Theme.Accent or Library.Theme.SubText
			item.BackgroundTransparency = selected and 0 or 1
		end
	end

	local function resize()
		local visible = math.min(#options, MAX_VISIBLE)
		local listHeight = visible * ITEM_HEIGHT + math.max(visible - 1, 0) * 2
		list.Size = UDim2.new(1, -16, 0, listHeight)
		tween(row, TWEEN_MED, { Size = UDim2.new(1, 0, 0, open and (36 + listHeight + 10) or 36) })
		tween(arrow, TWEEN_MED, { Rotation = open and 90 or 0 })
	end

	function option:Set(value, silent)
		if multi then
			local picked = {}
			if type(value) == "table" then
				for _, name in ipairs(value) do
					if table.find(options, name) and not table.find(picked, name) then
						table.insert(picked, name)
					end
				end
			end
			self.Value = picked
		else
			self.Value = table.find(options, value) and value or nil
		end
		render()
		commit(self, config.Callback, silent)
	end
	option.OnChanged = onChanged

	local function build()
		for _, item in pairs(items) do
			item:Destroy()
		end
		items = {}
		for index, name in ipairs(options) do
			local item = create("TextButton", {
				LayoutOrder = index,
				Size = UDim2.new(1, -4, 0, ITEM_HEIGHT),
				Font = FONT,
				TextSize = 13,
				Text = tostring(name),
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Theme = { BackgroundColor3 = "Inset" },
				Parent = list,
			}, { corner(4), padding(0, 8) })
			item.MouseButton1Click:Connect(function()
				if multi then
					local picked = table.clone(option.Value)
					local at = table.find(picked, name)
					if at then
						table.remove(picked, at)
					else
						table.insert(picked, name)
					end
					option:Set(picked)
				else
					option:Set(name)
					open = false
					resize()
				end
			end)
			items[name] = item
		end
		render()
	end

	-- Replaces the option list, dropping selections that no longer exist.
	function option:Refresh(newOptions)
		options = newOptions or {}
		build()
		self:Set(self.Value, true)
		resize()
	end

	header.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)

	onTheme(render)
	build()
	option:Set(config.Default, true)
	register(option, config)
	return option
end

function Elements:AddColorPicker(config)
	local default = config.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = default:ToHSV()

	local row = makeRow(self)
	rowTitle(row, config.Name or "Color").Size = UDim2.new(1, -70, 0, 36)
	local swatch = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(38, 20),
		Parent = row,
	}, { corner(4), stroke() })
	local header = clickArea(row)
	header.Size = UDim2.new(1, 0, 0, 36)
	hoverEffect(header, row)

	-- Saturation/value square: hue colour underneath, a white fade across and
	-- a black fade down, so no image assets are needed.
	local svCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
	}, { corner(4), create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })
	local svBox = create("TextButton", {
		Position = UDim2.new(0, 12, 0, 40),
		Size = UDim2.new(1, -24, 0, 100),
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, {
		corner(4),
		create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, {
			corner(4),
			create("UIGradient", {
				Transparency = NumberSequence.new(0, 1),
			}),
		}),
		create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 2 }, {
			corner(4),
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new(1, 0),
			}),
		}),
		svCursor,
	})

	local hueKeys = {}
	for i = 0, 6 do
		table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	local hueCursor = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 4, 1, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(2), create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1 }) })
	local hueBar = create("TextButton", {
		Position = UDim2.new(0, 12, 0, 148),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, { corner(4), create("UIGradient", { Color = ColorSequence.new(hueKeys) }), hueCursor })

	local option = { Type = "ColorPicker", Value = default, Instance = row }

	local function apply(silent)
		option.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = option.Value
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		commit(option, config.Callback, silent)
	end

	function option:Set(color, silent)
		if type(color) == "string" then
			color = hexToColor(color)
		end
		if typeof(color) ~= "Color3" then
			return
		end
		h, s, v = color:ToHSV()
		apply(silent)
	end
	option.OnChanged = onChanged

	local function dragSV(position)
		s = math.clamp((position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
		v = 1 - math.clamp((position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
		apply()
	end
	local function dragHue(position)
		h = math.clamp((position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
		apply()
	end
	svBox.InputBegan:Connect(function(input)
		if isPress(input) then
			dragSV(input.Position)
			trackDrag(input, dragSV)
		end
	end)
	hueBar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragHue(input.Position)
			trackDrag(input, dragHue)
		end
	end)

	local open = false
	header.MouseButton1Click:Connect(function()
		open = not open
		tween(row, TWEEN_MED, { Size = UDim2.new(1, 0, 0, open and 172 or 36) })
	end)

	apply(true)
	register(option, config)
	return option
end

---------------------------------------------------------------------
-- Sections and tabs
---------------------------------------------------------------------

local Section = setmetatable({}, Elements)
Section.__index = Section

local Tab = setmetatable({}, Elements)
Tab.__index = Tab

function Tab:AddSection(name)
	local frame = create("Frame", {
		LayoutOrder = nextOrder(self),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Section" },
		Parent = self.Container,
	}, {
		corner(8),
		stroke(),
		padding(10),
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		label({
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 18),
			Font = FONT_BOLD,
			TextSize = 12,
			Text = string.upper(name or "Section"),
			Theme = { TextColor3 = "SubText" },
		}),
	})
	return setmetatable({ Container = frame, Instance = frame, _order = 0 }, Section)
end

---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Library:CreateWindow(config)
	config = config or {}
	local size = config.Size or UDim2.fromOffset(580, 420)
	local gui = getGui()

	local self = setmetatable({
		Tabs = {},
		ToggleKey = config.ToggleKey or Enum.KeyCode.RightShift,
		ConfigFolder = config.ConfigFolder or "NovaUI",
		Visible = true,
		Minimized = false,
		_size = size,
	}, Window)

	local main = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		ClipsDescendants = true,
		Theme = { BackgroundColor3 = "Background" },
		Parent = gui,
	}, { corner(10), stroke() })
	self.Instance = main

	-- Shrink to fit small (phone) screens.
	local camera = workspace and workspace.CurrentCamera
	if camera and size.X.Offset > 0 and size.Y.Offset > 0 then
		local viewport = camera.ViewportSize
		local scale = math.min(1, (viewport.X - 24) / size.X.Offset, (viewport.Y - 24) / size.Y.Offset)
		if scale < 1 then
			create("UIScale", { Scale = math.max(scale, 0.5), Parent = main })
		end
	end

	-- Top bar -------------------------------------------------------
	local topBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = main,
	})
	label({
		Position = UDim2.new(0, 16, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = FONT_BOLD,
		TextSize = 14,
		Text = config.Title or "Nova UI",
		Parent = topBar,
	}, {})
	if config.SubTitle then
		label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -76, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 12,
			Text = config.SubTitle,
			Theme = { TextColor3 = "SubText" },
			Parent = topBar,
		})
	end
	create("Frame", {
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(1, 0, 0, 1),
		BorderSizePixel = 0,
		Theme = { BackgroundColor3 = "Stroke" },
		Parent = main,
	})

	local function topButton(text, offset, callback)
		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, offset, 0.5, 0),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Font = FONT_BOLD,
			TextSize = 14,
			Text = text,
			AutoButtonColor = false,
			Theme = { TextColor3 = "SubText", BackgroundColor3 = "Element" },
			Parent = topBar,
		}, { corner(6) })
		button.MouseEnter:Connect(function()
			tween(button, TWEEN_FAST, { BackgroundTransparency = 0 })
		end)
		button.MouseLeave:Connect(function()
			tween(button, TWEEN_FAST, { BackgroundTransparency = 1 })
		end)
		button.MouseButton1Click:Connect(callback)
		return button
	end
	topButton("X", -10, function()
		self:SetVisible(false)
	end)
	topButton("-", -40, function()
		self:SetMinimized(not self.Minimized)
	end)

	-- Dragging ------------------------------------------------------
	topBar.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		local origin = input.Position
		local start = main.Position
		trackDrag(input, function(position)
			local delta = position - origin
			main.Position = UDim2.new(
				start.X.Scale,
				start.X.Offset + delta.X,
				start.Y.Scale,
				start.Y.Offset + delta.Y
			)
		end)
	end)

	-- Sidebar and pages ----------------------------------------------
	self._tabList = create("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 43),
		Size = UDim2.new(0, 150, 1, -43),
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Theme = { BackgroundColor3 = "Sidebar" },
		Parent = main,
	}, {
		padding(8),
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	self._pages = create("Frame", {
		Position = UDim2.new(0, 150, 0, 43),
		Size = UDim2.new(1, -150, 1, -43),
		BackgroundTransparency = 1,
		Parent = main,
	})

	-- Toggle key ------------------------------------------------------
	connect(UserInputService.InputBegan, function(input, processed)
		if processed or Library._listening then
			return
		end
		if input.KeyCode == self.ToggleKey and input.KeyCode ~= Enum.KeyCode.Unknown then
			self:SetVisible(not self.Visible)
		end
	end)

	-- Touch devices have no toggle key, so give them a button.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local mobile = create("TextButton", {
			Position = UDim2.new(0, 12, 0.5, -20),
			Size = UDim2.fromOffset(40, 40),
			Font = FONT_BOLD,
			TextSize = 16,
			Text = string.sub(config.Title or "N", 1, 1),
			AutoButtonColor = false,
			Theme = { BackgroundColor3 = "Background", TextColor3 = "Accent" },
			Parent = gui,
		}, { corner(20), stroke() })
		mobile.MouseButton1Click:Connect(function()
			self:SetVisible(not self.Visible)
		end)
	end

	-- Intro animation
	main.Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 0)
	tween(main, TWEEN_MED, { Size = size })

	return self
end

function Window:SetVisible(visible)
	self.Visible = visible
	self.Instance.Visible = visible
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:SetMinimized(minimized)
	self.Minimized = minimized
	local size = self._size
	tween(self.Instance, TWEEN_MED, {
		Size = minimized and UDim2.new(size.X.Scale, size.X.Offset, 0, 42) or size,
	})
end

function Window:SelectTab(tab)
	for _, other in ipairs(self.Tabs) do
		local active = other == tab
		other.Container.Visible = active
		other._active = active
		tween(other._button, TWEEN_FAST, {
			BackgroundTransparency = active and 0 or 1,
			TextColor3 = active and Library.Theme.Text or Library.Theme.SubText,
		})
		other._indicator.Visible = active
	end
end

function Window:AddTab(config)
	if type(config) == "string" then
		config = { Name = config }
	end
	local window = self

	local indicator = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -6, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		Visible = false,
		Theme = { BackgroundColor3 = "Accent" },
	}, { corner(2) })
	local button = create("TextButton", {
		LayoutOrder = #self.Tabs + 1,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Font = FONT_MEDIUM,
		TextSize = 13,
		Text = config.Name or "Tab",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutoButtonColor = false,
		Theme = { BackgroundColor3 = "Element" },
		Parent = self._tabList,
	}, { corner(6), padding(0, 10), indicator })

	local page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Theme = { ScrollBarImageColor3 = "Stroke" },
		Parent = self._pages,
	}, {
		padding(12, 14, 12, 12),
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
	})

	local tab = setmetatable({
		Name = config.Name,
		Container = page,
		Instance = page,
		_button = button,
		_indicator = indicator,
		_active = false,
		_order = 0,
	}, Tab)
	table.insert(self.Tabs, tab)

	button.MouseButton1Click:Connect(function()
		window:SelectTab(tab)
	end)
	onTheme(function(theme)
		button.TextColor3 = tab._active and theme.Text or theme.SubText
	end)

	if #self.Tabs == 1 then
		self:SelectTab(tab)
	end
	return tab
end

-- Adds a ready-made settings tab: theme, toggle key, configs and unload.
function Window:AddSettingsTab(name)
	local window = self
	local tab = self:AddTab(name or "Settings")

	local interface = tab:AddSection("Interface")
	local themeNames = {}
	for themeName in pairs(Library.Themes) do
		table.insert(themeNames, themeName)
	end
	table.sort(themeNames)
	interface:AddDropdown({
		Name = "Theme",
		Options = themeNames,
		Default = "Dark",
		Callback = function(value)
			if value then
				Library:SetTheme(value)
			end
		end,
	})
	interface:AddKeybind({
		Name = "Toggle UI",
		Default = self.ToggleKey,
		ChangedCallback = function(key)
			window.ToggleKey = key ~= "None" and Enum.KeyCode[key] or Enum.KeyCode.Unknown
		end,
	})

	local configs = tab:AddSection("Configs")
	local nameBox = configs:AddTextbox({ Name = "Config name", Default = "default" })
	local picker = configs:AddDropdown({ Name = "Saved configs", Options = Library:ListConfigs(self.ConfigFolder) })
	picker:OnChanged(function(value)
		if value then
			nameBox:Set(value, true)
		end
	end)
	configs:AddButton({
		Name = "Save config",
		Callback = function()
			local ok, err = Library:SaveConfig(nameBox.Value, window.ConfigFolder)
			Library:Notify({
				Title = "Configs",
				Content = ok and ("Saved '" .. nameBox.Value .. "'") or ("Save failed: " .. tostring(err)),
			})
			picker:Refresh(Library:ListConfigs(window.ConfigFolder))
		end,
	})
	configs:AddButton({
		Name = "Load config",
		Callback = function()
			local ok, err = Library:LoadConfig(nameBox.Value, window.ConfigFolder)
			Library:Notify({
				Title = "Configs",
				Content = ok and ("Loaded '" .. nameBox.Value .. "'") or ("Load failed: " .. tostring(err)),
			})
		end,
	})

	tab:AddSection("Session"):AddButton({
		Name = "Unload UI",
		Callback = function()
			Library:Unload()
		end,
	})
	return tab
end

---------------------------------------------------------------------
-- Configs
---------------------------------------------------------------------

local function hasFileApi()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
		and type(makefolder) == "function"
end

local function configPath(name, folder)
	return (folder or "NovaUI") .. "/" .. tostring(name):gsub("[^%w%-_ ]", "") .. ".json"
end

function Library:SaveConfig(name, folder)
	if not hasFileApi() then
		return false, "executor has no file API"
	end
	local data = {}
	for flag, option in pairs(self.Options) do
		if option.Type == "ColorPicker" then
			data[flag] = colorToHex(option.Value)
		else
			data[flag] = option.Value
		end
	end
	return pcall(function()
		folder = folder or "NovaUI"
		if not (isfolder and isfolder(folder)) then
			makefolder(folder)
		end
		writefile(configPath(name, folder), HttpService:JSONEncode(data))
	end)
end

function Library:LoadConfig(name, folder)
	if not hasFileApi() then
		return false, "executor has no file API"
	end
	local path = configPath(name, folder)
	if not isfile(path) then
		return false, "config not found"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then
		return false, "config is corrupt"
	end
	for flag, value in pairs(data) do
		local option = self.Options[flag]
		if option then
			-- Not silent: callbacks must run so the loaded state takes effect.
			option:Set(value)
		end
	end
	return true
end

function Library:ListConfigs(folder)
	local names = {}
	folder = folder or "NovaUI"
	if type(listfiles) ~= "function" or type(isfolder) ~= "function" or not isfolder(folder) then
		return names
	end
	local ok, files = pcall(listfiles, folder)
	if not ok then
		return names
	end
	for _, path in ipairs(files) do
		local name = tostring(path):match("([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

---------------------------------------------------------------------
-- Teardown
---------------------------------------------------------------------

function Library:Unload()
	if self.Unloaded then
		return
	end
	self.Unloaded = true
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
	self._bindings = {}
	self._themeCallbacks = {}
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	notifyHolder = nil
	safeCall(self.OnUnload)
end

return Library
