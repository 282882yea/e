---------------------------------------------------------------------
-- Popups (dropdown lists, colour pickers, card menus)
---------------------------------------------------------------------

local Popup = {}
Popup.__index = Popup

-- opts: Width, Height, Build(frame, popup) -> optional height, OnClose, Below
function Popup.open(window, anchor, opts)
	if window._popupAnchor == anchor and os.clock() - (window._popupClosed or 0) < 0.2 then
		return nil
	end
	window:_closePopup()
	local scale = window._scale
	local overlay = window.PopupLayer
	local anchorPos = (anchor.AbsolutePosition - overlay.AbsolutePosition) / scale
	local anchorSize = anchor.AbsoluteSize / scale
	local area = overlay.AbsoluteSize / scale

	local self = setmetatable({ Window = window, Anchor = anchor, OnClose = opts.OnClose }, Popup)
	local catcher = new("TextButton", { Name = "PopupCatcher", Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = overlay })
	catcher.MouseButton1Down:Connect(function()
		window:_closePopup()
	end)
	self.Catcher = catcher

	local width = math.max(opts.Width or 0, 132)
	local frame = new("Frame", {
		Name = "Popup",
		Size = UDim2.fromOffset(width, 40),
		BackgroundTransparency = 0,
		Active = true,
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Popup" },
		Parent = overlay,
	})
	pcall(function()
		frame.InputSink = Enum.InputSink.All
	end)
	corner(frame, 10)
	local border = stroke(frame, nil, 1, 0)
	border.Color = WHITE
	gradient(border, 90, { "CardStrokeTop", "CardStrokeMid" })
	glow(frame, { Color = "Black", Blur = 22, Transparency = 0.45, Offset = Vector2.new(0, 8) })
	glow(frame, { Blur = 18, Transparency = 0.8 })
	self.Frame = frame

	local height = opts.Build(frame, self) or 40
	frame.Size = UDim2.fromOffset(width, height)

	local x = anchorPos.X + anchorSize.X - width
	local y = anchorPos.Y + anchorSize.Y + 5
	local below = true
	if y + height > area.Y - 6 then
		y = anchorPos.Y - height - 5
		below = false
	end
	x = math.clamp(x, 6, math.max(6, area.X - width - 6))
	y = math.clamp(y, 6, math.max(6, area.Y - height - 6))
	frame.Position = UDim2.fromOffset(round(x), round(y + (below and -6 or 6)))
	window._popup = self
	frame.Visible = false
	fade(frame, true, 0.16)
	tween(frame, 0.22, { Position = UDim2.fromOffset(round(x), round(y)) })
	return self
end

function Popup:ContainsPoint(point)
	local f = self.Frame
	if not f or not f.Parent then
		return false
	end
	local p, s = f.AbsolutePosition, f.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X <= p.X + s.X and point.Y <= p.Y + s.Y
end

function Popup:Close()
	if self.Closed then
		return
	end
	self.Closed = true
	self.Window._popupAnchor = self.Anchor
	self.Window._popupClosed = os.clock()
	self.Catcher:Destroy()
	local frame = self.Frame
	fade(frame, false, 0.12, function()
		frame:Destroy()
	end)
	if self.OnClose then
		self.OnClose()
	end
end

-- A scrolling list of rows; items: { Text, Selected, Icon, Disabled, Callback(popup, index) -> keepOpen }
local function buildList(frame, popup, items, opts)
	local ITEM = 28
	local search
	local top = 4
	if opts.Searchable then
		local box = new("Frame", {
			Name = "Search",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 26),
			BackgroundTransparency = 0,
			ZIndex = 3,
			Theme = { BackgroundColor3 = "Control" },
			Parent = frame,
		})
		corner(box, 8)
		stroke(box, "ControlStroke", 1, 0)
		icon("search", 12, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 3, Parent = box })
		search = new("TextBox", {
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -32, 1, 0),
			FontFace = Fonts.Body,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			PlaceholderText = "Search...",
			ClearTextOnFocus = false,
			Text = "",
			ZIndex = 3,
			Theme = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder" },
			Parent = box,
		})
		top = 38
	end
	local visibleCount = math.min(#items, opts.MaxVisible or 8)
	local listHeight = math.max(1, visibleCount) * ITEM
	local list = new("ScrollingFrame", {
		Name = "Items",
		Position = UDim2.fromOffset(4, top),
		Size = UDim2.new(1, -8, 0, listHeight),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, #items * ITEM),
		ScrollBarThickness = #items > visibleCount and 2 or 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Theme = { ScrollBarImageColor3 = "AccentDeep" },
		Parent = frame,
	})
	local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	popup.Rows = {}
	for index, item in ipairs(items) do
		local row = new("TextButton", {
			Name = "Item",
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, ITEM),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = list,
		})
		corner(row, 7)
		local label = new("TextLabel", {
			Name = "Text",
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.new(1, -35, 1, 0),
			FontFace = Fonts.Label,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = item.Text,
			TextTransparency = item.Disabled and 0.5 or 0,
			ZIndex = 3,
			Parent = row,
		})
		local check = icon("check", 13, "Accent", {
			Name = "Check",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Visible = item.Selected == true,
			ZIndex = 3,
			Parent = row,
		})
		local entry = { Row = row, Label = label, Check = check, Text = string.lower(item.Text) }
		local function color()
			label.TextColor3 = entry.Selected and Theme.Accent or Theme.Text
		end
		entry.Selected = item.Selected == true
		color()
		row.MouseEnter:Connect(function()
			tween(row, 0.12, { BackgroundTransparency = 0.93 })
		end)
		row.MouseLeave:Connect(function()
			tween(row, 0.2, { BackgroundTransparency = 1 })
		end)
		row.MouseButton1Click:Connect(function()
			if item.Disabled then
				return
			end
			local keepOpen = item.Callback and item.Callback(popup, index) == true
			if not keepOpen then
				popup.Window:_closePopup()
			end
		end)
		function entry.SetSelected(selected)
			entry.Selected = selected
			check.Visible = selected
			color()
		end
		popup.Rows[index] = entry
	end
	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local query = string.lower(search.Text)
			local shown = 0
			for _, entry in ipairs(popup.Rows) do
				local hit = query == "" or string.find(entry.Text, query, 1, true) ~= nil
				entry.Row.Visible = hit
				if hit then
					shown += 1
				end
			end
			list.CanvasSize = UDim2.fromOffset(0, shown * ITEM)
			list.CanvasPosition = Vector2.new(0, 0)
		end)
		task.defer(function()
			if search.Parent then
				search:CaptureFocus()
			end
		end)
	end
	if #items == 0 then
		new("TextLabel", {
			Position = UDim2.fromOffset(10, top),
			Size = UDim2.new(1, -20, 0, ITEM),
			FontFace = Fonts.Body,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "No options",
			ZIndex = 3,
			Theme = { TextColor3 = "SubText" },
			Parent = frame,
		})
	end
	return top + listHeight + 4
end

---------------------------------------------------------------------
-- Elements and option registration
---------------------------------------------------------------------

local Element = {}
Element.__index = Element

function Element:SetVisible(visible)
	self.Hidden = not visible
	if self.Container then
		self.Container.Visible = visible and not self._filtered
	end
end

function Element:Matches(query)
	if query == "" then
		return true
	end
	return string.find(string.lower(self.SearchText or ""), query, 1, true) ~= nil
end

local orderCounter = 0
local function nextOrder()
	orderCounter += 1
	return orderCounter
end

local function makeRow(card, name, height)
	local row = new("Frame", {
		Name = tostring(name),
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		Parent = card.Body,
	})
	local divider = new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundTransparency = 0.25,
		Theme = { BackgroundColor3 = "Divider" },
		Parent = row,
	})
	row.MouseEnter:Connect(function()
		tween(row, 0.15, { BackgroundTransparency = 0.965 })
	end)
	row.MouseLeave:Connect(function()
		tween(row, 0.3, { BackgroundTransparency = 1 })
	end)
	local element = setmetatable({ Container = row, Divider = divider, SearchText = tostring(name), Card = card }, Element)
	table.insert(card.Elements, element)
	if card.Window then
		table.insert(card.Window.Elements, element)
	end
	return row, element
end

local function rowLabel(row, text, props)
	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(1, -14, 1, 0),
		FontFace = Fonts.Label,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(text),
		Theme = { TextColor3 = "Text" },
		Parent = row,
	})
	if props then
		for key, value in pairs(props) do
			label[key] = value
		end
	end
	return label
end

local function sanitizeId(text)
	return (string.gsub(tostring(text or "Option"), "[^%w_%-%.]", "_"))
end

local OptionMethods = {}

function OptionMethods:OnChanged(fn)
	if type(fn) == "function" then
		table.insert(self._listeners, fn)
	end
	return self
end

function OptionMethods:RunChanged()
	fire(self.Callback, self.Value)
	for _, fn in ipairs(self._listeners) do
		fire(fn, self.Value)
	end
	return self
end

function OptionMethods:SetVisible(visible)
	if self._element then
		self._element:SetVisible(visible)
	end
	self.Visible = visible ~= false
	return self
end

function OptionMethods:SetDisabled(disabled)
	self.Disabled = disabled == true
	local row = self._element and self._element.Container
	if row then
		for _, child in ipairs(row:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextBox") then
				child.TextTransparency = self.Disabled and 0.5 or 0
			end
		end
	end
	return self
end

function OptionMethods:SetText(text)
	self.Text = tostring(text)
	self.DisplayName = self.Text
	if self._label then
		self._label.Text = self.Text
	end
	if self._element then
		self._element.SearchText = self.Text
	end
	return self
end

-- Adds the common option surface and files the option under its id.
local function register(card, api, optionType, id, displayName, info)
	local window = card.Window
	local registry = optionType == "Toggle" and Library.Toggles or Library.Options
	local base = sanitizeId(id or ((card.Tab and card.Tab.Name or "Tab") .. "." .. tostring(card.Title or "Card") .. "." .. tostring(displayName)))
	local final, n = base, 2
	while registry[final] and registry[final] ~= api do
		final = base .. "_" .. n
		n += 1
	end
	api.Id = final
	api.Idx = final
	api.Type = optionType
	api.Text = displayName
	api.DisplayName = displayName
	api.NoSave = info and info.NoSave == true or false
	api.Callback = info and info.Callback or nil
	api.Tooltip = info and info.Tooltip or nil
	api.Visible = true
	api._listeners = api._listeners or {}
	api._card = card
	api._window = window
	for name, fn in pairs(OptionMethods) do
		if api[name] == nil then
			api[name] = fn
		end
	end
	api.SetValue = api.SetValue or api.Set
	api.Set = api.Set or api.SetValue
	registry[final] = api
	if api._element then
		api._element.ValueObject = api
	end
	if api.Tooltip and api._element and window then
		window:_attachTooltip(api._element.Container, api.Tooltip)
	end
	return api
end

local function changed(api, silent)
	if silent then
		return
	end
	fire(api.Callback, api.Value)
	for _, fn in ipairs(api._listeners) do
		fire(fn, api.Value)
	end
end

---------------------------------------------------------------------
-- Inline addons: key chip and colour swatch
---------------------------------------------------------------------

local Card = {}
Card.__index = Card

local function addonHolder(row)
	local holder = row:FindFirstChild("Addons")
	if holder then
		return holder
	end
	holder = new("Frame", {
		Name = "Addons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = px(6),
		Parent = holder,
	})
	return holder
end

-- Key picker. `row` is where it lives; `inline` makes it a compact chip.
local function createKeyPicker(card, row, element, id, info, inline)
	info = info or {}
	local window = card.Window
	local display = info.Text or tostring(id)
	local modes = info.Modes or { "Toggle", "Hold", "Always" }
	local mode = info.Mode or modes[1] or "Toggle"
	if not table.find(modes, mode) then
		table.insert(modes, mode)
	end
	local value = stringToEnum(info.Default or "None")
	local api = { ShowInList = info.NoUI ~= true, Modifiers = info.Modifiers or {}, _element = element }
	api.Toggled = mode == "Always"

	local holder = addonHolder(row)
	local chip = new("TextButton", {
		Name = "Key",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, inline and 22 or 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		FontFace = inline and Fonts.Strong or Fonts.Label,
		TextSize = inline and 13 or 15,
		Text = "",
		Theme = { BackgroundColor3 = "Control", TextColor3 = "Text" },
		Parent = holder,
	})
	corner(chip, inline and 8 or 12)
	local chipStroke = stroke(chip, "ControlStroke", 1, 0)
	new("UIPadding", { PaddingLeft = px(inline and 8 or 12), PaddingRight = px(inline and 8 or 12), Parent = chip })
	new("UISizeConstraint", { MinSize = Vector2.new(inline and 30 or 64, 0), Parent = chip })
	local modeChip
	if not inline and #modes > 1 then
		modeChip = new("TextButton", {
			Name = "Mode",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			FontFace = Fonts.Strong,
			TextSize = 13,
			Text = mode,
			Theme = { BackgroundColor3 = "Control", TextColor3 = "SubText" },
			Parent = holder,
		})
		corner(modeChip, 12)
		stroke(modeChip, "ControlStroke", 1, 0)
		new("UIPadding", { PaddingLeft = px(10), PaddingRight = px(10), Parent = modeChip })
	end

	local listening = false
	local function render()
		if listening then
			chip.Text = "..."
			return
		end
		chip.Text = value == KEY_NONE and (inline and "—" or "None") or keyLabel(value)
		if modeChip then
			modeChip.Text = mode
		end
	end

	function api:Get()
		return value
	end
	function api:GetMode()
		return mode
	end
	function api:IsActive()
		return mode == "Always" or (value ~= KEY_NONE and self.Toggled == true)
	end
	function api:GetState()
		return self:IsActive()
	end
	local function sync()
		api.Value = enumToString(value)
		api.Mode = mode
	end
	function api:SetActive(active, silent)
		local before = self.Toggled
		self.Toggled = mode == "Always" or (value ~= KEY_NONE and active == true)
		if not silent then
			if info.SyncToggleState and self._parentToggle then
				self._parentToggle:SetValue(self.Toggled)
			end
			fire(info.Callback, self.Toggled, value, mode)
			if before ~= self.Toggled then
				fire(info.Clicked, self.Toggled)
			end
		end
		window:_refreshKeybinds()
		return self
	end
	function api:SetMode(newMode, silent)
		if not table.find(modes, newMode) then
			return self
		end
		mode = newMode
		sync()
		render()
		self.Toggled = mode == "Always" or (mode == "Toggle" and self.Toggled == true)
		if not silent then
			fire(info.ChangedCallback, value, mode)
			changed(self, false)
		end
		window:_refreshKeybinds()
		return self
	end
	function api:Set(v, silent)
		if type(v) == "table" then
			local key, newMode, modifiers = v[1] or v.Key, v[2] or v.Mode, v[3] or v.Modifiers
			if key ~= nil then
				value = stringToEnum(key)
			end
			if newMode and table.find(modes, newMode) then
				mode = newMode
			end
			if type(modifiers) == "table" then
				self.Modifiers = modifiers
			end
		else
			value = stringToEnum(v)
		end
		if mode ~= "Always" and mode ~= "Toggle" then
			self.Toggled = false
		end
		sync()
		render()
		if not silent then
			fire(info.ChangedCallback, value, mode)
			changed(self, false)
		end
		window:_refreshKeybinds()
		return self
	end
	api.SetValue = api.Set
	function api:Update()
		if mode == "Always" then
			self.Toggled = true
		elseif value == KEY_NONE then
			self.Toggled = false
		end
		sync()
		render()
		window:_refreshKeybinds()
		return self
	end
	function api:DoClick()
		if mode == "Toggle" then
			self:SetActive(not self.Toggled)
		elseif mode == "Always" then
			fire(info.Callback, true, value, mode)
		end
	end
	-- key events routed by the window
	function api:_input(input, began)
		if not inputMatches(input, value) then
			return
		end
		if began then
			if mode == "Toggle" then
				self:SetActive(not self.Toggled)
			elseif mode == "Hold" then
				self:SetActive(true)
			elseif mode == "Always" then
				fire(info.Callback, true, value, mode)
			end
		elseif mode == "Hold" then
			self:SetActive(false)
		end
	end
	function api:_release()
		if mode == "Hold" and self.Toggled then
			self:SetActive(false)
		end
	end

	local function capture()
		if listening then
			return
		end
		window:_closePopup()
		listening = true
		window._capturing = api
		render()
		tween(chipStroke, 0.15, { Color = Theme.Accent })
		local armed = false
		task.delay(0.12, function()
			armed = true
		end)
		local conn
		conn = connect(UserInputService.InputBegan, function(input)
			if not armed then
				return
			end
			local picked
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					picked = value
				elseif input.KeyCode == Enum.KeyCode.Backspace then
					picked = KEY_NONE
				else
					picked = input.KeyCode
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				picked = input.UserInputType
			else
				return
			end
			conn:Disconnect()
			listening = false
			task.defer(function()
				if window._capturing == api then
					window._capturing = nil
				end
			end)
			tween(chipStroke, 0.25, { Color = Theme.ControlStroke })
			if picked ~= value then
				api:Set(picked)
			else
				render()
			end
		end)
	end

	local function openModes(anchor)
		local items = {}
		for _, m in ipairs(modes) do
			table.insert(items, {
				Text = m,
				Selected = m == mode,
				Callback = function()
					api:SetMode(m)
				end,
			})
		end
		Popup.open(window, anchor, {
			Width = 120,
			Build = function(frame, popup)
				return buildList(frame, popup, items, {})
			end,
		})
	end

	chip.MouseButton1Click:Connect(capture)
	chip.MouseButton2Click:Connect(function()
		if #modes > 1 then
			openModes(chip)
		end
	end)
	if modeChip then
		modeChip.MouseButton1Click:Connect(function()
			openModes(modeChip)
		end)
	end
	chip.MouseEnter:Connect(function()
		if not listening then
			tween(chipStroke, 0.15, { Color = Theme.AccentDeep })
		end
	end)
	chip.MouseLeave:Connect(function()
		if not listening then
			tween(chipStroke, 0.25, { Color = Theme.ControlStroke })
		end
	end)
	if inline and #modes > 1 then
		window:_attachTooltip(chip, "Click to rebind, right-click for mode")
	end

	sync()
	render()
	register(card, api, "KeyPicker", id, display, info)
	api.Callback = nil -- the key callback has its own signature, fired by SetActive
	api.KeyCallback = info.Callback
	table.insert(window.Keybinds, api)
	window:_refreshKeybinds()
	return api
end

local function hexOf(color)
	return string.format("#%02X%02X%02X", round(color.R * 255), round(color.G * 255), round(color.B * 255))
end

local function parseHex(text)
	local hex = string.gsub(tostring(text or ""), "[^%x]", "")
	if #hex == 3 then
		hex = string.gsub(hex, "%x", "%0%0")
	end
	if #hex ~= 6 then
		return nil
	end
	return Color3.fromRGB(tonumber(string.sub(hex, 1, 2), 16), tonumber(string.sub(hex, 3, 4), 16), tonumber(string.sub(hex, 5, 6), 16))
end

local function createColorPicker(card, row, element, id, info, inline)
	info = info or {}
	local window = card.Window
	local display = info.Title or info.Text or tostring(id)
	local color = typeof(info.Default) == "Color3" and info.Default or Theme.Accent
	local h, s, v = color:ToHSV()
	local hasAlpha = info.Transparency ~= nil
	local api = { Transparency = tonumber(info.Transparency) or 0, _element = element }

	local holder = addonHolder(row)
	local swatch = new("TextButton", {
		Name = "Color",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(inline and 26 or 34, inline and 18 or 22),
		BackgroundTransparency = 0,
		Parent = holder,
	})
	corner(swatch, 6)
	stroke(swatch, "ControlStroke", 1, 0)
	local swatchGlow = glow(swatch, { Blur = 6, Transparency = 0.7 })

	local popupRefs
	local function render(silent)
		color = Color3.fromHSV(h, s, v)
		api.Value = color
		swatch.BackgroundColor3 = color
		swatch.BackgroundTransparency = math.clamp(api.Transparency, 0, 0.85)
		if swatchGlow.Instance then
			swatchGlow.Instance.Color = color
		end
		if popupRefs then
			popupRefs.sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			popupRefs.cursor.Position = UDim2.fromScale(s, 1 - v)
			popupRefs.hueCursor.Position = UDim2.new(0.5, 0, h, 0)
			if popupRefs.hex and not popupRefs.hex:IsFocused() then
				popupRefs.hex.Text = hexOf(color)
			end
			if popupRefs.alphaCursor then
				popupRefs.alphaCursor.Position = UDim2.new(api.Transparency, 0, 0.5, 0)
				popupRefs.alphaFill.BackgroundColor3 = color
			end
		end
		changed(api, silent)
	end

	function api:Get()
		return color
	end
	function api:Set(newColor, silent)
		if typeof(newColor) == "Color3" then
			h, s, v = newColor:ToHSV()
		elseif type(newColor) == "table" then
			h, s, v = newColor[1] or newColor.H or h, newColor[2] or newColor.S or s, newColor[3] or newColor.V or v
		else
			return self
		end
		render(silent)
		return self
	end
	api.SetValue = api.Set
	function api:SetValueRGB(newColor, transparency)
		if transparency ~= nil then
			self.Transparency = tonumber(transparency) or self.Transparency
		end
		return self:Set(newColor)
	end
	function api:SetHSV(hh, ss, vv)
		h, s, v = hh, ss, vv
		render(false)
		return self
	end

	local dragging
	local function open()
		popupRefs = nil
		Popup.open(window, swatch, {
			Width = 214,
			OnClose = function()
				popupRefs = nil
				dragging = nil
			end,
			Build = function(frame)
				local refs = {}
				new("TextLabel", {
					Position = UDim2.fromOffset(12, 8),
					Size = UDim2.new(1, -24, 0, 18),
					FontFace = Fonts.Strong,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = display,
					ZIndex = 3,
					Theme = { TextColor3 = "Text" },
					Parent = frame,
				})
				local sv = new("TextButton", { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(160, 120), BackgroundTransparency = 0, ZIndex = 3, Parent = frame })
				corner(sv, 6)
				local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 3, Parent = sv })
				corner(white, 6)
				new("UIGradient", { Transparency = numberSeq(0, 0, 1, 1), Parent = white })
				local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0, ZIndex = 3, Parent = sv })
				corner(black, 6)
				new("UIGradient", { Rotation = 90, Transparency = numberSeq(0, 1, 1, 0), Parent = black })
				local cursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 4, Parent = sv })
				corner(cursor, 5)
				local cs = stroke(cursor, nil, 1.5, 0.1)
				cs.Color = BLACK
				local hue = new("TextButton", { Position = UDim2.fromOffset(182, 32), Size = UDim2.fromOffset(20, 120), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 3, Parent = frame })
				corner(hue, 6)
				local hueKeys = {}
				for i = 0, 6 do
					table.insert(hueKeys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
				end
				new("UIGradient", { Rotation = 90, Color = ColorSequence.new(hueKeys), Parent = hue })
				local hueCursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 3), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 4, Parent = hue })
				corner(hueCursor, 2)
				local y = 160
				local alpha
				if hasAlpha then
					alpha = new("TextButton", { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(190, 12), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 3, Parent = frame })
					corner(alpha, 6)
					local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, ZIndex = 3, Parent = alpha })
					corner(fill, 6)
					new("UIGradient", { Transparency = numberSeq(0, 0, 1, 1), Parent = fill })
					refs.alphaFill = fill
					refs.alphaCursor = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 16), BackgroundColor3 = WHITE, BackgroundTransparency = 0, ZIndex = 4, Parent = alpha })
					corner(refs.alphaCursor, 2)
					y += 20
				end
				local hexBox = new("Frame", { Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(190, 26), BackgroundTransparency = 0, ZIndex = 3, Theme = { BackgroundColor3 = "Control" }, Parent = frame })
				corner(hexBox, 8)
				stroke(hexBox, "ControlStroke", 1, 0)
				local hex = new("TextBox", {
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.new(1, -20, 1, 0),
					FontFace = Fonts.Mono,
					TextSize = 14,
					ClearTextOnFocus = false,
					Text = hexOf(color),
					ZIndex = 3,
					Theme = { TextColor3 = "Text" },
					Parent = hexBox,
				})
				hex.FocusLost:Connect(function()
					local parsed = parseHex(hex.Text)
					if parsed then
						api:Set(parsed)
					else
						hex.Text = hexOf(color)
					end
				end)
				refs.sv, refs.cursor, refs.hueCursor, refs.hex = sv, cursor, hueCursor, hex
				local function begin(target, kind)
					target.InputBegan:Connect(function(input)
						if isPress(input) then
							dragging = kind
							window:_beginDrag(function(position)
								if kind == "sv" then
									s = math.clamp((position.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
									v = 1 - math.clamp((position.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
								elseif kind == "hue" then
									h = math.clamp((position.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 0.999)
								else
									api.Transparency = math.clamp((position.X - alpha.AbsolutePosition.X) / math.max(alpha.AbsoluteSize.X, 1), 0, 1)
								end
								render(false)
							end, function()
								dragging = nil
							end)
							window._drag.Move(input.Position)
						end
					end)
				end
				begin(sv, "sv")
				begin(hue, "hue")
				if alpha then
					begin(alpha, "alpha")
				end
				popupRefs = refs
				render(true)
				return y + 36
			end,
		})
	end
	swatch.MouseButton1Click:Connect(open)
	function api:Close()
		window:_closePopup()
	end
	render(true)
	register(card, api, "ColorPicker", id, display, info)
	return api
end
