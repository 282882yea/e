---------------------------------------------------------------------
-- Card controls (shared by groupboxes, dependency boxes, tabbox pages, dialogs)
---------------------------------------------------------------------

local function cardChanged(card)
	if card._host then
		card._host:Resize()
	elseif card.Resize then
		card:Resize()
	end
end

-- Toggle -------------------------------------------------------------

function Card:AddToggle(id, info, legacyCallback)
	local display, explicit
	if type(info) == "table" then
		display, explicit = info.Text or tostring(id), id
	else
		display = tostring(id)
		info = { Text = display, Default = info, Callback = legacyCallback }
	end
	local default = info.Default == true
	if self.Window and self.Window.FeatureDefaultsOff then
		default = false
	end
	local row, element = makeRow(self, display, 35)
	element.SearchText = display
	local label = rowLabel(row, display, { Size = UDim2.new(1, -60, 1, 0) })
	if info.Risky then
		paint(label, { TextColor3 = "Risk" })
	end

	local switch = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(32, 18),
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Control" },
		Parent = row,
	})
	corner(switch, 9)
	local border = stroke(switch, "ControlStroke", 1, 0)
	local fill = new("Frame", { Name = "On", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Parent = switch })
	corner(fill, 9)
	gradient(fill, 0, { "ToggleA", "ToggleB" })
	local halo = glow(fill, { Blur = 10, Transparency = 1 })
	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 0,
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Knob" },
		Parent = switch,
	})
	corner(knob, 7)
	glow(knob, { Color = "Black", Blur = 4, Transparency = 0.7, Offset = Vector2.new(0, 1) })
	local hit = new("TextButton", { Name = "Hit", Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(0, 0), ZIndex = 1, Parent = row })
	local hitSwitch = new("TextButton", { Name = "HitSwitch", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 46, 1, 0), ZIndex = 3, Parent = row })

	-- addons sit left of the switch
	local holder = addonHolder(row)
	holder.Position = UDim2.new(1, -46, 0.5, 0)

	local api = { _element = element, _label = label, Addons = {} }
	local ready = false
	local function render()
		local on = api.Value
		local time = ready and 0.28 or 0
		local knobPos = UDim2.new(0, on and 16 or 2, 0.5, 0)
		if ready then
			tween(knob, time, { Position = knobPos, Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
			tween(fill, 0.2, { BackgroundTransparency = on and 0 or 1 })
			tween(border, 0.2, { Transparency = on and 1 or 0 })
			if not info.Risky then
				tween(label, 0.2, { TextColor3 = on and Theme.Text or Theme.TextOff })
			end
		else
			knob.Position = knobPos
			fill.BackgroundTransparency = on and 0 or 1
			border.Transparency = on and 1 or 0
			if not info.Risky then
				label.TextColor3 = on and Theme.Text or Theme.TextOff
			end
		end
		setGlow(halo, on and 0.45 or 1, time)
	end
	if not info.Risky then
		onTheme(function()
			if ready then
				label.TextColor3 = api.Value and Theme.Text or Theme.TextOff
			end
		end)
	end

	function api:Get()
		return self.Value
	end
	function api:Set(value, silent)
		value = value == true
		self.Value = value
		render()
		for _, addon in ipairs(self.Addons) do
			if addon.Type == "KeyPicker" and addon._syncToggle and addon.Toggled ~= value then
				addon:SetActive(value, true)
			end
		end
		if self.Disabled and not silent then
			return self
		end
		changed(self, silent)
		return self
	end
	api.SetValue = api.Set

	local function click()
		if api.Disabled then
			return
		end
		api:Set(not api.Value)
	end
	hit.MouseButton1Click:Connect(click)
	hitSwitch.MouseButton1Down:Connect(function()
		tween(knob, 0.12, { Size = UDim2.fromOffset(18, 14), Position = UDim2.new(0, api.Value and 12 or 2, 0.5, 0) })
	end)
	hitSwitch.MouseButton1Click:Connect(click)
	hitSwitch.MouseLeave:Connect(render)

	function api:AddKeyPicker(keyId, keyInfo)
		keyInfo = keyInfo or {}
		local picker = createKeyPicker(self._card, row, element, keyId, keyInfo, true)
		picker._parentToggle = self
		picker._syncToggle = keyInfo.SyncToggleState == true
		table.insert(self.Addons, picker)
		if picker._syncToggle then
			picker:SetActive(self.Value, true)
		end
		return picker
	end
	function api:AddColorPicker(colorId, colorInfo)
		colorInfo = colorInfo or {}
		if colorInfo.Title == nil and colorInfo.Text == nil then
			colorInfo.Title = display
		end
		local picker = createColorPicker(self._card, row, element, colorId, colorInfo, true)
		table.insert(self.Addons, picker)
		return picker
	end

	api.Value = default
	api.Default = default
	render()
	ready = true
	register(self, api, "Toggle", explicit, display, info)
	return api
end

-- Slider -------------------------------------------------------------

function Card:AddSlider(id, info, max, default, step, legacyCallback)
	local display, explicit
	if type(info) == "table" then
		display, explicit = info.Text or tostring(id), id
	else
		display = tostring(id)
		info = { Text = display, Min = info, Max = max, Default = default, Callback = legacyCallback }
		if step then
			info.Rounding = math.max(0, math.ceil(-math.log10(step) - 1e-9))
		end
	end
	local min = tonumber(info.Min) or 0
	local maxValue = tonumber(info.Max) or 100
	local rounding = tonumber(info.Rounding) or 0
	local suffix = tostring(info.Suffix or "")
	local row, element = makeRow(self, display, 41)
	local api = { _element = element, Min = min, Max = maxValue, Rounding = rounding, Suffix = suffix }

	local line = new("Frame", { Name = "Line", Position = UDim2.fromOffset(0, 1), Size = UDim2.new(1, 0, 1, -1), BackgroundTransparency = 1, Parent = row })
	new("UIPadding", { PaddingLeft = px(7), PaddingRight = px(7), Parent = line })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = line,
	})
	local label = rowLabel(line, display, { Position = UDim2.new(), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, TextTruncate = Enum.TextTruncate.None })
	new("UISizeConstraint", { MaxSize = Vector2.new(172, math.huge), Parent = label })
	label.TextTruncate = Enum.TextTruncate.AtEnd
	api._label = label
	new("Frame", { Name = "Gap", LayoutOrder = 2, Size = UDim2.fromOffset(13, 1), BackgroundTransparency = 1, Parent = line })
	local trackFrame = new("TextButton", {
		Name = "Track",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(60, 18),
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Control" },
		Parent = line,
	})
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = trackFrame })
	corner(trackFrame, 9)
	stroke(trackFrame, "ControlStroke", 1, 0)
	local fillFrame = new("Frame", { Name = "Fill", Size = UDim2.new(0, 9, 1, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0, Parent = trackFrame })
	corner(fillFrame, 9)
	gradient(fillFrame, 0, { "AccentDeep", "SliderB" })
	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 9, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 0,
		ZIndex = 2,
		Theme = { BackgroundColor3 = "Knob" },
		Parent = trackFrame,
	})
	corner(knob, 7)
	local halo = glow(knob, { Blur = 9, Transparency = 0.5 })
	new("Frame", { Name = "Gap", LayoutOrder = 4, Size = UDim2.fromOffset(8, 1), BackgroundTransparency = 1, Parent = line })
	local box = new("Frame", {
		Name = "Value",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(0, 23),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Control" },
		Parent = line,
	})
	new("UISizeConstraint", { MinSize = Vector2.new(54, 23), Parent = box })
	new("UIPadding", { PaddingLeft = px(8), PaddingRight = px(8), Parent = box })
	corner(box, 10)
	local boxBorder = stroke(box, "ControlStroke", 1, 0)
	local input = new("TextBox", {
		Name = "Input",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Mono,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		Text = "",
		Theme = { TextColor3 = "Text" },
		Parent = box,
	})
	new("UISizeConstraint", { MinSize = Vector2.new(38, 0), Parent = input })

	local function format(value)
		local text = string.format("%." .. math.max(0, rounding) .. "f", value)
		return text .. suffix
	end
	local function quantize(value)
		local mult = 10 ^ rounding
		value = math.floor(value * mult + 0.5) / mult
		return math.clamp(value, api.Min, api.Max)
	end
	local function layout(animated)
		local scale = self.Window and self.Window._scale or 1
		local width = trackFrame.AbsoluteSize.X / scale
		if width <= 0 then
			return
		end
		local range = api.Max - api.Min
		local frac = range > 0 and (api.Value - api.Min) / range or 0
		local center = math.clamp(frac * width, 9, math.max(9, width - 9))
		if animated then
			tween(knob, 0.12, { Position = UDim2.new(0, center, 0.5, 0) }, Enum.EasingStyle.Quad)
			tween(fillFrame, 0.12, { Size = UDim2.new(0, center, 1, 0) }, Enum.EasingStyle.Quad)
		else
			knob.Position = UDim2.new(0, center, 0.5, 0)
			fillFrame.Size = UDim2.new(0, center, 1, 0)
		end
	end

	local ready = false
	function api:Get()
		return self.Value
	end
	function api:Set(value, silent)
		local number = tonumber(value)
		if number == nil or number ~= number then
			return self
		end
		self.Value = quantize(number)
		input.Text = format(self.Value)
		layout(ready)
		changed(self, silent)
		return self
	end
	api.SetValue = api.Set
	function api:SetMin(value)
		self.Min = tonumber(value) or self.Min
		self:Set(math.max(self.Value, self.Min), true)
		return self
	end
	function api:SetMax(value)
		self.Max = tonumber(value) or self.Max
		self:Set(math.min(self.Value, self.Max), true)
		return self
	end
	function api:SetSuffix(value)
		suffix = tostring(value or "")
		self.Suffix = suffix
		input.Text = format(self.Value)
		return self
	end

	trackFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout(false)
	end)
	local function fromX(x)
		local width = trackFrame.AbsoluteSize.X
		if width <= 0 or api.Disabled then
			return
		end
		local frac = math.clamp((x - trackFrame.AbsolutePosition.X) / width, 0, 1)
		local value = quantize(api.Min + frac * (api.Max - api.Min))
		if value ~= api.Value then
			api:Set(value)
		end
	end
	local function setActive(active)
		tween(knob, 0.18, { Size = active and UDim2.fromOffset(16, 16) or UDim2.fromOffset(14, 14) })
		setGlow(halo, active and 0.15 or 0.5, 0.18)
	end
	trackFrame.InputBegan:Connect(function(inputObject)
		if isPress(inputObject) and self.Window then
			setActive(true)
			fromX(inputObject.Position.X)
			self.Window:_beginDrag(function(position)
				fromX(position.X)
			end, function()
				setActive(false)
			end)
		end
	end)
	trackFrame.MouseEnter:Connect(function()
		setGlow(halo, 0.3, 0.15)
	end)
	trackFrame.MouseLeave:Connect(function()
		if not (self.Window and self.Window._drag) then
			setGlow(halo, 0.5, 0.25)
		end
	end)
	input.Focused:Connect(function()
		tween(boxBorder, 0.15, { Color = Theme.Accent })
		input.Text = string.format("%." .. math.max(0, rounding) .. "f", api.Value)
	end)
	input.FocusLost:Connect(function()
		tween(boxBorder, 0.25, { Color = Theme.ControlStroke })
		local typed = tonumber((string.gsub(input.Text, "[^%d%.%-]", "")))
		if typed then
			api:Set(typed)
		end
		input.Text = format(api.Value)
	end)

	local start = tonumber(info.Default) or min
	api.Value = quantize(start)
	api.Default = api.Value
	input.Text = format(api.Value)
	ready = true
	task.defer(layout, false)
	register(self, api, "Slider", explicit, display, info)
	return api
end

-- Dropdown -----------------------------------------------------------

function Card:AddDropdown(id, info, legacyDefault, legacyCallback)
	local display, explicit
	if type(info) == "table" and (info.Values ~= nil or info.Text ~= nil or info.Multi ~= nil or info.Default ~= nil) then
		display, explicit = info.Text or tostring(id), id
	else
		display = tostring(id)
		info = { Text = display, Values = info or {}, Default = legacyDefault, Callback = legacyCallback }
	end
	local multi = info.Multi == true
	local row, element = makeRow(self, display, 43)
	local label = rowLabel(row, display)
	local api = { _element = element, _label = label, Multi = multi, AllowNull = info.AllowNull == true, Values = info.Values or {}, DisabledValues = {} }

	local pill = new("ImageButton", {
		Name = "Select",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Control" },
		Parent = row,
	})
	corner(pill, 12)
	local border = stroke(pill, "ControlStroke", 1, 0)
	new("UIPadding", { PaddingLeft = px(10), PaddingRight = px(10), Parent = pill })
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = px(10),
		Parent = pill,
	})
	local valueLabel = new("TextLabel", {
		Name = "Value",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Label,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Theme = { TextColor3 = "Text" },
		Parent = pill,
	})
	new("UISizeConstraint", { MinSize = Vector2.new(69, 0), MaxSize = Vector2.new(190, math.huge), Parent = valueLabel })
	local chevron = icon("chevron-down", 12, "TextTitle", { Name = "Chevron", LayoutOrder = 2, Parent = pill })
	label.Size = UDim2.new(1, -230, 1, 0)

	local function formatValue(value)
		if type(info.FormatDisplayValue) == "function" then
			local ok, result = pcall(info.FormatDisplayValue, value)
			if ok and result ~= nil then
				return tostring(result)
			end
		end
		return tostring(value)
	end
	local function display_()
		if multi then
			local picked = {}
			for _, option in ipairs(api.Values) do
				if api.Value[option] then
					table.insert(picked, formatValue(option))
				end
			end
			return #picked > 0 and table.concat(picked, ", ") or "None"
		end
		return api.Value ~= nil and formatValue(api.Value) or "None"
	end
	local function normalise(value)
		if multi then
			local set = {}
			if type(value) == "table" then
				for k, v in pairs(value) do
					if type(k) == "number" then
						set[v] = true
					elseif v then
						set[k] = true
					end
				end
			end
			return set
		end
		if type(value) == "number" and api.Values[value] ~= nil and not table.find(api.Values, value) then
			return api.Values[value]
		end
		return value
	end

	function api:Get()
		return self.Value
	end
	function api:Set(value, silent)
		self.Value = normalise(value)
		valueLabel.Text = display_()
		changed(self, silent)
		return self
	end
	api.SetValue = api.Set
	function api:SetValues(values)
		self.Values = values or {}
		if multi then
			local set = {}
			for k in pairs(self.Value or {}) do
				if table.find(self.Values, k) then
					set[k] = true
				end
			end
			self.Value = set
		elseif self.Value ~= nil and not table.find(self.Values, self.Value) then
			self.Value = self.AllowNull and nil or self.Values[1]
		end
		valueLabel.Text = display_()
		return self
	end
	function api:AddValues(values)
		for _, v in ipairs(type(values) == "table" and values or { values }) do
			table.insert(self.Values, v)
		end
		return self:SetValues(self.Values)
	end
	function api:SetDisabledValues(values)
		self.DisabledValues = values or {}
		return self
	end
	function api:GetActiveValues()
		if not multi then
			return self.Value ~= nil and 1 or 0
		end
		local list = {}
		for _, option in ipairs(self.Values) do
			if self.Value[option] then
				table.insert(list, option)
			end
		end
		return list
	end
	function api:Display()
		valueLabel.Text = display_()
	end

	local open = false
	pill.MouseButton1Click:Connect(function()
		if api.Disabled then
			return
		end
		if open then
			self.Window:_closePopup()
			return
		end
		local items = {}
		for _, option in ipairs(api.Values) do
			local text = tostring(option)
			if type(info.FormatListValue) == "function" then
				local ok, result = pcall(info.FormatListValue, option)
				if ok and result ~= nil then
					text = tostring(result)
				end
			end
			table.insert(items, {
				Text = text,
				Selected = multi and api.Value[option] == true or (not multi and api.Value == option),
				Disabled = table.find(api.DisabledValues, option) ~= nil,
				Callback = function(popup, index)
					if multi then
						local set = cloneTable(api.Value)
						set[option] = not set[option] or nil
						api:Set(set)
						popup.Rows[index].SetSelected(set[option] == true)
						return true
					end
					if api.Value == option and api.AllowNull then
						api:Set(nil)
					else
						api:Set(option)
					end
				end,
			})
		end
		local width = math.max(pill.AbsoluteSize.X / self.Window._scale, 170)
		local popup = Popup.open(self.Window, pill, {
			Width = width,
			OnClose = function()
				open = false
				tween(chevron, 0.25, { Rotation = 0 })
			end,
			Build = function(frame, popup)
				return buildList(frame, popup, items, {
					Searchable = info.Searchable == true or #items > 12,
					MaxVisible = tonumber(info.MaxVisibleDropdownItems) or 8,
				})
			end,
		})
		if popup then
			open = true
			tween(chevron, 0.25, { Rotation = 180 })
		end
	end)
	pill.MouseEnter:Connect(function()
		tween(border, 0.15, { Color = Theme.AccentDeep })
	end)
	pill.MouseLeave:Connect(function()
		tween(border, 0.25, { Color = Theme.ControlStroke })
	end)

	local start = info.Default
	if not multi and start == nil and not api.AllowNull then
		start = api.Values[1]
	end
	api.Value = normalise(start)
	if not multi and api.Value ~= nil and not table.find(api.Values, api.Value) and not api.AllowNull then
		api.Value = api.Values[1]
	end
	api.Default = multi and cloneTable(api.Value) or api.Value
	valueLabel.Text = display_()
	register(self, api, "Dropdown", explicit, display, info)
	return api
end

function Card:AddMultiDropdown(id, info)
	info = info or {}
	info.Multi = true
	return self:AddDropdown(id, info)
end

-- Input ---------------------------------------------------------------

function Card:AddInput(id, info, placeholder, legacyCallback)
	local display, explicit
	if type(info) == "table" then
		display, explicit = info.Text or tostring(id), id
	else
		display = tostring(id)
		info = { Text = display, Default = info, Placeholder = placeholder, Callback = legacyCallback }
	end
	local row, element = makeRow(self, display, 43)
	local label = rowLabel(row, display, { Size = UDim2.new(1, -214, 1, 0) })
	local api = { _element = element, _label = label }
	local box = new("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.fromOffset(info.Width or 196, 26),
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = "Control" },
		Parent = row,
	})
	corner(box, 12)
	local border = stroke(box, "ControlStroke", 1, 0)
	local textBox = new("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		FontFace = Fonts.Label,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = info.ClearTextOnFocus == true,
		PlaceholderText = tostring(info.Placeholder or info.PlaceholderText or ""),
		Text = "",
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder" },
		Parent = box,
	})
	api.Textbox = textBox

	local function clean(text)
		text = tostring(text or "")
		if info.Numeric then
			text = string.gsub(text, "[^%d%.%-]", "")
		end
		if info.MaxLength and #text > info.MaxLength then
			text = string.sub(text, 1, info.MaxLength)
		end
		return text
	end
	function api:Get()
		return self.Value
	end
	function api:Set(text, silent)
		text = clean(text)
		if text == "" and info.AllowEmpty == false then
			text = tostring(info.EmptyReset or self.Value or "")
		end
		self.Value = text
		if textBox.Text ~= text then
			textBox.Text = text
		end
		changed(self, silent)
		return self
	end
	api.SetValue = api.Set

	local committing = false
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		if committing then
			return
		end
		if info.Numeric or info.MaxLength then
			local cleaned = clean(textBox.Text)
			if cleaned ~= textBox.Text then
				textBox.Text = cleaned
				return
			end
		end
		if not info.Finished and textBox:IsFocused() and textBox.Text ~= api.Value then
			api:Set(textBox.Text)
		end
	end)
	textBox.Focused:Connect(function()
		tween(border, 0.15, { Color = Theme.Accent })
	end)
	textBox.FocusLost:Connect(function()
		tween(border, 0.25, { Color = Theme.ControlStroke })
		if api.Disabled then
			textBox.Text = api.Value
			return
		end
		if textBox.Text ~= api.Value then
			committing = true
			api:Set(textBox.Text)
			committing = false
		end
	end)

	api.Value = clean(info.Default or "")
	api.Default = api.Value
	textBox.Text = api.Value
	register(self, api, "Input", explicit, display, info)
	return api
end
Card.AddTextbox = Card.AddInput

-- Key picker / colour picker rows -----------------------------------------

function Card:AddKeyPicker(id, info)
	info = info or {}
	local display = info.Text or tostring(id)
	local row, element = makeRow(self, display, 43)
	local label = rowLabel(row, display, { Size = UDim2.new(1, -200, 1, 0) })
	local picker = createKeyPicker(self, row, element, id, info, false)
	picker._label = label
	return picker
end

function Card:AddKeybind(id, default, callback, mode)
	if type(default) == "table" then
		return self:AddKeyPicker(id, default)
	end
	return self:AddKeyPicker(id, { Text = tostring(id), Default = default, Callback = callback, Mode = mode })
end

function Card:AddColorPicker(id, info)
	info = info or {}
	local display = info.Title or info.Text or tostring(id)
	local row, element = makeRow(self, display, 35)
	rowLabel(row, display, { Size = UDim2.new(1, -60, 1, 0) })
	return createColorPicker(self, row, element, id, info, false)
end

-- Label / divider / blank ----------------------------------------------------

function Card:AddLabel(text, wrap, idx)
	if type(text) == "table" then
		wrap = text.DoesWrap or text.Wrap
		text = text.Text
	end
	text = tostring(text or "")
	local row, element = makeRow(self, text ~= "" and text or "Label", wrap and 24 or 32)
	element.SearchText = text
	row.BackgroundTransparency = 1
	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(7, wrap and 6 or 0),
		Size = wrap and UDim2.new(1, -14, 0, 0) or UDim2.new(1, -14, 1, 0),
		AutomaticSize = wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		FontFace = wrap and Fonts.Body or Fonts.Label,
		TextSize = wrap and 14 or 15,
		TextWrapped = wrap == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		TextTruncate = wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd,
		RichText = true,
		Text = text,
		Theme = { TextColor3 = wrap and "SubText" or "TextOff" },
		Parent = row,
	})
	if wrap then
		row.AutomaticSize = Enum.AutomaticSize.Y
		new("UIPadding", { PaddingBottom = px(6), Parent = row })
	end
	local api = setmetatable({ Container = row, Label = label, TextLabel = label, Text = text, _card = self, _element = element, Addons = {} }, {})
	function api:SetText(value)
		self.Text = tostring(value)
		label.Text = self.Text
		element.SearchText = self.Text
		return self
	end
	function api:SetVisible(visible)
		element:SetVisible(visible ~= false)
		return self
	end
	function api:AddColorPicker(colorId, colorInfo)
		colorInfo = colorInfo or {}
		if colorInfo.Title == nil and colorInfo.Text == nil then
			colorInfo.Title = self.Text
		end
		label.Size = UDim2.new(1, -60, 1, 0)
		paint(label, { TextColor3 = "Text" })
		local picker = createColorPicker(self._card, row, element, colorId, colorInfo, false)
		table.insert(self.Addons, picker)
		return picker
	end
	function api:AddKeyPicker(keyId, keyInfo)
		keyInfo = keyInfo or {}
		if keyInfo.Text == nil then
			keyInfo.Text = self.Text
		end
		row.Size = UDim2.new(1, 0, 0, 43)
		label.Size = UDim2.new(1, -200, 1, 0)
		label.FontFace = Fonts.Label
		label.TextSize = 16
		paint(label, { TextColor3 = "Text" })
		local picker = createKeyPicker(self._card, row, element, keyId, keyInfo, false)
		picker._label = label
		table.insert(self.Addons, picker)
		return picker
	end
	if idx then
		Library.Labels[idx] = api
	end
	return api
end

function Card:AddDivider(text)
	local row, element = makeRow(self, "Divider", text and 26 or 12)
	element.SearchText = ""
	row.Divider.Visible = false
	local lineFrame = new("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.new(1, -20, 0, 1),
		BackgroundTransparency = 0.2,
		Theme = { BackgroundColor3 = "HeaderDivider" },
		Parent = row,
	})
	gradient(lineFrame, 0, nil, numberSeq(0, 1, 0.15, 0.2, 0.85, 0.2, 1, 1))
	if text then
		local tag = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			FontFace = Fonts.CardSub,
			TextSize = 14,
			Text = tostring(text),
			Theme = { BackgroundColor3 = "BodyMid", TextColor3 = "SubText" },
			Parent = row,
		})
		new("UIPadding", { PaddingLeft = px(8), PaddingRight = px(8), Parent = tag })
	end
	return row
end

function Card:AddBlank(height, visible)
	local row, element = makeRow(self, "Blank", tonumber(height) or 6)
	element.SearchText = ""
	row.Divider.Visible = false
	element:SetVisible(visible ~= false)
	return setmetatable({ Container = row, Visible = visible ~= false }, {
		__index = {
			SetVisible = function(api, value)
				api.Visible = value ~= false
				element:SetVisible(api.Visible)
				return api
			end,
		},
	})
end

-- Buttons -------------------------------------------------------------------

function Card:AddButton(info, text, legacyCallback)
	local label, fn, tooltip, doubleClick
	if type(info) == "table" then
		label, fn, tooltip, doubleClick = info.Text or "Button", info.Func or info.Callback, info.Tooltip, info.DoubleClick
	elseif type(text) == "function" and legacyCallback == nil then
		label, fn = tostring(info or "Button"), text
	else
		label, fn = tostring(text or info or "Button"), legacyCallback
	end
	local row, element = makeRow(self, label, 42)
	local line = new("Frame", { Name = "Buttons", Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1, Parent = row })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(6), Parent = line })
	local window = self.Window
	local card = self

	local function makeButton(text, callback, tip, confirm, order)
		local button = new("TextButton", {
			Name = text,
			LayoutOrder = order,
			Size = UDim2.new(0, 10, 1, 0),
			BackgroundTransparency = 0,
			FontFace = Fonts.Label,
			TextSize = 15,
			Text = text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Theme = { BackgroundColor3 = "Control", TextColor3 = "Text" },
			Parent = line,
		})
		new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = button })
		corner(button, 12)
		local border = stroke(button, "ControlStroke", 1, 0)
		local halo = glow(button, { Blur = 12, Transparency = 1 })
		local api = { Button = button, Container = row, Text = text, Func = callback, _card = card }
		local armedAt
		button.MouseEnter:Connect(function()
			tween(border, 0.15, { Color = Theme.Accent })
			setGlow(halo, 0.6, 0.15)
		end)
		button.MouseLeave:Connect(function()
			tween(border, 0.25, { Color = Theme.ControlStroke })
			tween(button, 0.25, { BackgroundColor3 = Theme.Control })
			setGlow(halo, 1, 0.25)
		end)
		button.MouseButton1Down:Connect(function()
			if not api.Disabled then
				tween(button, 0.1, { BackgroundColor3 = Theme.AccentDeep })
			end
		end)
		button.MouseButton1Click:Connect(function()
			tween(button, 0.3, { BackgroundColor3 = Theme.Control })
			if api.Disabled then
				return
			end
			if confirm then
				if not armedAt or os.clock() - armedAt > 2 then
					armedAt = os.clock()
					button.Text = "Click again to confirm"
					task.delay(2, function()
						if armedAt and os.clock() - armedAt >= 1.95 then
							armedAt = nil
							button.Text = api.Text
						end
					end)
					return
				end
				armedAt = nil
				button.Text = api.Text
			end
			fire(api.Func)
		end)
		if tip and window then
			window:_attachTooltip(button, tip)
		end
		function api:OnClick(cb)
			if type(cb) == "function" then
				button.MouseButton1Click:Connect(cb)
			end
			return self
		end
		function api:SetText(value)
			self.Text = tostring(value)
			button.Text = self.Text
			return self
		end
		function api:SetDisabled(disabled)
			self.Disabled = disabled == true
			button.TextTransparency = self.Disabled and 0.5 or 0
			return self
		end
		function api:SetVisible(visible)
			button.Visible = visible ~= false
			return self
		end
		function api:AddButton(subInfo, subText, subCallback)
			local t, f, tt, dc
			if type(subInfo) == "table" then
				t, f, tt, dc = subInfo.Text or "Button", subInfo.Func or subInfo.Callback, subInfo.Tooltip, subInfo.DoubleClick
			elseif type(subText) == "function" then
				t, f = tostring(subInfo), subText
			else
				t, f = tostring(subText or subInfo), subCallback
			end
			element.SearchText = element.SearchText .. " " .. t
			return makeButton(t, f, tt, dc, order + 1)
		end
		return api
	end
	local api = makeButton(label, fn, tooltip, doubleClick, 1)
	api._element = element
	table.insert(Library.Buttons, api)
	return api
end

-- Viewport ---------------------------------------------------------------

function Card:AddViewport(id, info)
	info = info or {}
	local height = tonumber(info.Height) or 220
	local holder = new("Frame", {
		Name = tostring(id or "Viewport"),
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, height + 12),
		BackgroundTransparency = 1,
		Parent = self.Body,
	})
	local viewport = new("ViewportFrame", {
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, height),
		BackgroundTransparency = 0.08,
		Ambient = rgb(180, 160, 190),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		Theme = { BackgroundColor3 = "Window" },
		Parent = holder,
	})
	corner(viewport, 12)
	stroke(viewport, "Divider", 1, 0.2)
	local camera = info.Camera or Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local object = info.Object
	if object and info.Clone then
		local ok, clone = pcall(function()
			return object:Clone()
		end)
		if ok then
			object = clone
		end
	end
	if object then
		object.Parent = viewport
	end
	local element = setmetatable({ Container = holder, SearchText = "", Card = self }, Element)
	table.insert(self.Elements, element)
	local api = { Type = "Viewport", Object = object, Camera = camera, Holder = holder, Container = viewport, Height = height, Visible = info.Visible ~= false, _card = self }
	holder.Visible = api.Visible
	function api:SetObject(newObject, clone)
		if self.Object and self.Object.Parent == viewport then
			pcall(function()
				self.Object:Destroy()
			end)
		end
		if newObject and clone then
			local ok, c = pcall(function()
				return newObject:Clone()
			end)
			if ok then
				newObject = c
			end
		end
		self.Object = newObject
		if newObject then
			newObject.Parent = viewport
		end
		return self
	end
	function api:SetHeight(value)
		self.Height = math.max(40, tonumber(value) or self.Height)
		holder.Size = UDim2.new(1, 0, 0, self.Height + 12)
		viewport.Size = UDim2.new(1, -16, 0, self.Height)
		return self
	end
	function api:SetVisible(value)
		self.Visible = value ~= false
		element:SetVisible(self.Visible)
		return self
	end
	Library.Options[id] = api
	return api
end

-- Dependency boxes ------------------------------------------------------------

function Card:AddDependencyBox(name)
	local host = new("Frame", {
		Name = tostring(name or "DependencyBox"),
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self.Body,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = host })
	local proxy = setmetatable({
		Tab = self.Tab,
		Window = self.Window,
		Title = tostring(self.Title or "Card") .. "/" .. tostring(name or "Dependency"),
		Body = host,
		Container = host,
		Elements = self.Elements, -- searching treats the box's rows as the card's rows
		Dependencies = {},
		_host = self._host or self,
		_parentBox = self,
	}, Card)
	proxy.BodyList = host:FindFirstChildOfClass("UIListLayout")
	local element = setmetatable({ Container = host, SearchText = "", Card = self, IsBox = true }, Element)
	proxy._element = element
	local function evaluate()
		local visible = true
		for _, dep in ipairs(proxy.Dependencies) do
			local option, expected = dep[1], dep[2]
			local current
			if option then
				if option.Type == "Dropdown" and option.Multi and type(expected) ~= "function" and type(expected) ~= "table" then
					current = option.Value and option.Value[expected] == true
					expected = true
				else
					current = option.Value
				end
			end
			if type(expected) == "function" then
				local ok, result = pcall(expected, current)
				visible = visible and ok and result == true
			else
				visible = visible and current == expected
			end
		end
		proxy.Visible = visible
		element.Hidden = not visible
		host.Visible = visible and not element._filtered
	end
	function proxy:RefreshDependencies()
		evaluate()
		return self
	end
	function proxy:AddDependency(option, expected)
		table.insert(self.Dependencies, { option, expected })
		if option and type(option.OnChanged) == "function" then
			option:OnChanged(evaluate)
		end
		evaluate()
		return self
	end
	function proxy:SetupDependencies(list)
		self.Dependencies = {}
		for _, dep in ipairs(list or {}) do
			table.insert(self.Dependencies, { dep[1], dep[2] })
			if dep[1] and type(dep[1].OnChanged) == "function" then
				dep[1]:OnChanged(evaluate)
			end
		end
		evaluate()
		return self
	end
	function proxy:Resize()
		if self._host and self._host.Resize then
			self._host:Resize()
		end
	end
	table.insert(self.Tab and self.Tab.DependencyGroupboxes or {}, proxy)
	return proxy
end
