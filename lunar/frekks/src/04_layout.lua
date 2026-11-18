---------------------------------------------------------------------
-- Groupbox cards
---------------------------------------------------------------------

local Tab = {}
Tab.__index = Tab

local function paintCard(card)
	local scale = card.Window._scale
	local height = card.Frame.AbsoluteSize.Y / scale
	local headerHeight = card.HeaderHeight
	if height <= 0 then
		return
	end
	local t = math.clamp(headerHeight / height, 0.02, 1)
	if t >= 0.95 then
		card._fill.Color = ColorSequence.new(Theme.HeaderTop, Theme.HeaderBottom)
		card._fill.Transparency = numberSeq(0, 0.16, 1, 0.24)
		return
	end
	card._fill.Color = colorSeq(
		0, Theme.HeaderTop,
		t, Theme.HeaderBottom,
		math.min(0.999, t + 0.002), Theme.BodyTop,
		t + (1 - t) * 0.45, Theme.BodyMid,
		1, Theme.BodyLow
	)
	card._fill.Transparency = numberSeq(0, 0.16, t, 0.24, math.min(0.999, t + 0.002), 0.16, 1, 0.2)
end

function Tab:AddCard(title, subtitle, side, iconName)
	local window = self.Window
	title = tostring(title or "Groupbox")
	subtitle = tostring(subtitle or "")
	local rightSide = string.lower(tostring(side or "left")) == "right" or side == 2
	local card = setmetatable({
		Tab = self,
		Window = window,
		Title = title,
		Name = title,
		Subtitle = subtitle,
		Side = rightSide and 2 or 1,
		ColumnSide = rightSide and "right" or "left",
		Elements = {},
		Collapsed = false,
	}, Card)
	card._host = nil
	local headerHeight = subtitle ~= "" and 56 or 42
	card.HeaderHeight = headerHeight

	local frame = new("Frame", {
		Name = title,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Parent = rightSide and self.Right or self.Left,
	})
	corner(frame, CARD_RADIUS)
	card._fill = new("UIGradient", { Rotation = 90, Parent = frame })
	local border = stroke(frame, nil, 1, 0)
	border.Color = WHITE
	gradient(border, 90, { { 0, "CardStrokeTop" }, { 0.12, "CardStrokeMid" }, { 0.8, "CardStrokeMid" }, { 1, "CardStrokeLow" } })
	card._halo = glow(frame, { Blur = 20, Transparency = 0.8 })
	card.Frame, card.Outer = frame, frame

	local header = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, headerHeight), BackgroundTransparency = 1, Parent = frame })
	card.Header = header
	icon(iconName or iconForTitle(title, self.Icon), 17, "Accent", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 11, 0.5, 0),
		Parent = header,
	})
	local titleLabel = new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(37, subtitle ~= "" and 8 or 0),
		Size = UDim2.new(1, -37 - 40, 0, subtitle ~= "" and 23 or headerHeight),
		FontFace = Fonts.CardTitle,
		TextSize = subtitle ~= "" and 23 or 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = title,
		Theme = { TextColor3 = "TextBright" },
		Parent = header,
	})
	card.TitleLabel = titleLabel
	if subtitle ~= "" then
		new("TextLabel", {
			Name = "Description",
			Position = UDim2.fromOffset(37, 31),
			Size = UDim2.new(1, -37 - 40, 0, 17),
			FontFace = Fonts.CardSub,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = subtitle,
			Theme = { TextColor3 = "SubText" },
			Parent = header,
		})
	end
	local menu = new("ImageButton", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = WHITE,
		Parent = header,
	})
	corner(menu, 7)
	local dots = icon("ellipsis", 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = menu })
	menu.MouseEnter:Connect(function()
		tween(menu, 0.15, { BackgroundTransparency = 0.9 })
		tween(dots, 0.15, { ImageColor3 = Theme.Accent })
	end)
	menu.MouseLeave:Connect(function()
		tween(menu, 0.25, { BackgroundTransparency = 1 })
		tween(dots, 0.25, { ImageColor3 = Theme.Text })
	end)
	menu.MouseButton1Click:Connect(function()
		Popup.open(window, menu, {
			Width = 172,
			Build = function(f, popup)
				return buildList(f, popup, {
					{ Text = card.Collapsed and "Expand" or "Collapse", Callback = function()
						card:SetCollapsed(not card.Collapsed)
					end },
					{ Text = "Reset to defaults", Callback = function()
						card:Reset()
					end },
				}, {})
			end,
		})
	end)

	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, headerHeight),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = frame,
	})
	local bodyList = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	new("UIPadding", { PaddingBottom = px(4), Parent = body })
	card.Body, card.Container, card.BodyList = body, body, bodyList

	function card:Resize(animated)
		if not self.Frame.Parent then
			return
		end
		local scale = window._scale
		local height = self.HeaderHeight
		if not self.Collapsed then
			height += round(self.BodyList.AbsoluteContentSize.Y / scale) + 6
		end
		local size = UDim2.new(1, 0, 0, height)
		if animated then
			self.Frame.ClipsDescendants = true
			tween(self.Frame, 0.3, { Size = size })
			task.delay(0.31, function()
				if not self.Collapsed then
					self.Frame.ClipsDescendants = false
				end
			end)
		else
			self.Frame.Size = size
		end
		self.Tab:_RefreshCanvas()
	end
	function card:SetCollapsed(value)
		self.Collapsed = value == true
		window:_closePopup()
		if self.Collapsed then
			self.Frame.ClipsDescendants = true
		end
		self:Resize(true)
		return self
	end
	function card:Reset()
		for _, element in ipairs(self.Elements) do
			local option = element.ValueObject
			if option and option.Default ~= nil and option.Set and option.Type ~= "KeyPicker" then
				option:Set(option.Default)
			end
		end
	end

	bodyList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		card:Resize()
	end)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		paintCard(card)
	end)
	onTheme(function()
		paintCard(card)
	end)
	frame.MouseEnter:Connect(function()
		setGlow(card._halo, 0.6, 0.25)
	end)
	frame.MouseLeave:Connect(function()
		setGlow(card._halo, 0.8, 0.4)
	end)

	table.insert(self.Cards, card)
	self:_UpdateCount()
	task.defer(function()
		card:Resize()
	end)
	return card
end

---------------------------------------------------------------------
-- Tabboxes: a card with page pills along its top
---------------------------------------------------------------------

local Tabbox = {}
Tabbox.__index = Tabbox

function Tab:_AddTabbox(name, side)
	local host = self:AddCard(name or "Tabs", "", side)
	local bar = new("Frame", {
		Name = "TabboxBar",
		LayoutOrder = -1,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = host.Body,
	})
	local strip = new("Frame", { Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Control" }, Parent = bar })
	corner(strip, 14)
	stroke(strip, "ControlStroke", 1, 0)
	local buttons = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Parent = strip })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(3), Parent = buttons })
	local box = setmetatable({ Card = host, Window = self.Window, Tab = self, Buttons = buttons, Tabs = {}, Active = nil, Name = name }, Tabbox)
	self.Tabboxes[name or ""] = box
	return box
end

function Tab:AddLeftTabbox(name)
	return self:_AddTabbox(name, "Left")
end

function Tab:AddRightTabbox(name)
	return self:_AddTabbox(name, "Right")
end

function Tabbox:AddTab(name)
	local host = self.Card
	local button = new("TextButton", {
		Name = name,
		LayoutOrder = #self.Tabs + 1,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		FontFace = Fonts.Strong,
		TextSize = 14,
		Text = name,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Theme = { BackgroundColor3 = "AccentDeep", TextColor3 = "SubText" },
		Parent = self.Buttons,
	})
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = button })
	corner(button, 11)
	local page = new("Frame", {
		Name = name,
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = host.Body,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
	local proxy = setmetatable({
		Tab = host.Tab,
		Window = host.Window,
		Title = tostring(host.Title) .. "/" .. name,
		Name = name,
		Body = page,
		Container = page,
		Elements = host.Elements,
		_host = host,
		_tabbox = self,
	}, Card)
	proxy.BodyList = page:FindFirstChildOfClass("UIListLayout")
	local record = { Button = button, Page = page, Proxy = proxy }
	table.insert(self.Tabs, record)
	local box = self
	local function select()
		if box.Active == record then
			return
		end
		if box.Active then
			box.Active.Page.Visible = false
			tween(box.Active.Button, 0.2, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
		end
		box.Active = record
		page.Visible = true
		tween(button, 0.2, { BackgroundTransparency = 0.15, TextColor3 = Theme.TextBright })
	end
	button.MouseButton1Click:Connect(select)
	function proxy:Show()
		select()
	end
	if not self.Active then
		select()
	end
	return proxy
end

---------------------------------------------------------------------
-- Tabs and sub-tabs
---------------------------------------------------------------------

function Tab:AddGroupbox(info)
	if type(info) == "string" then
		info = { Name = info, Side = 1 }
	end
	info = info or {}
	local name = info.Name or info.Text or ("Groupbox " .. tostring(#self.Cards + 1))
	local side = (info.Side == 2 or string.lower(tostring(info.Side)) == "right") and "Right" or "Left"
	local card = self:AddCard(name, info.Subtitle or info.Description or "", side, info.IconName or info.Icon)
	self.Groupboxes[name] = card
	return card
end

function Tab:AddLeftGroupbox(name, iconName)
	return self:AddGroupbox({ Name = name, Side = 1, Icon = type(iconName) == "string" and iconName or nil })
end

function Tab:AddRightGroupbox(name, iconName)
	return self:AddGroupbox({ Name = name, Side = 2, Icon = type(iconName) == "string" and iconName or nil })
end

function Tab:_UpdateCount()
	local target = self.ParentTab or self
	local active = target.ActiveSubtab or target
	local n = #active.Cards
	if target.CountLabel then
		target.CountLabel.Text = n .. (n == 1 and " module" or " modules")
	end
end

function Tab:_RefreshCanvas()
	if self._canvasQueued then
		return
	end
	self._canvasQueued = true
	task.defer(function()
		self._canvasQueued = false
		if not self.Left or not self.Left.Parent then
			return
		end
		local scale = self.Window._scale
		self.Left.CanvasSize = UDim2.fromOffset(0, self.LeftList.AbsoluteContentSize.Y / scale + 20)
		self.Right.CanvasSize = UDim2.fromOffset(0, self.RightList.AbsoluteContentSize.Y / scale + 20)
	end)
end

function Tab:_ApplySearch(query)
	local any = false
	for _, card in ipairs(self.Cards) do
		local titleHit = query == "" or string.find(string.lower(card.Title), query, 1, true) ~= nil
		local cardHit = titleHit
		for _, element in ipairs(card.Elements) do
			if not element.IsBox then
				local hit = titleHit or element:Matches(query)
				element._filtered = not hit
				element.Container.Visible = hit and not element.Hidden
				cardHit = cardHit or hit
			end
		end
		card.Frame.Visible = cardHit or card.Frame.Parent ~= (card.Side == 2 and self.Right or self.Left)
		any = any or cardHit
	end
	if self.Empty then
		self.Empty.Visible = query ~= "" and not any
	end
	self:_RefreshCanvas()
end

function Tab:_SetSelected(selected)
	if self.ParentTab then
		local button = self.SubtabButton
		if button then
			tween(button, 0.2, { BackgroundTransparency = selected and 0 or 1 })
			tween(self.SubtabStroke, 0.2, { Transparency = selected and 0 or 1 })
			tween(self.SubtabLabel, 0.2, { TextColor3 = selected and Theme.TextBright or Theme.SubText })
			tween(self.SubtabIcon, 0.2, { ImageColor3 = selected and Theme.TextBright or Theme.SubText })
		end
		return
	end
	if self.NavLabel then
		tween(self.NavLabel, 0.2, { TextColor3 = selected and Theme.TextBright or Theme.TextNav })
		tween(self.NavIcon, 0.2, { ImageColor3 = selected and Theme.TextBright or Theme.TextNav })
	end
end

function Tab:_SelectSubTab(sub)
	if type(sub) == "string" then
		sub = self.SubtabByName and self.SubtabByName[sub]
	end
	if not sub or sub.ParentTab ~= self or self.ActiveSubtab == sub then
		return
	end
	local window = self.Window
	window:_closePopup()
	local previous = self.ActiveSubtab
	if previous then
		fadeFinish(previous.Page)
		previous.Page.Visible = false
		previous:_SetSelected(false)
	end
	self.ActiveSubtab = sub
	sub:_SetSelected(true)
	if previous and window.Visible then
		sub.Grid.Position = UDim2.fromOffset(GRID_LEFT - 4, sub.GridTop + 8)
		tween(sub.Grid, 0.4, { Position = UDim2.fromOffset(GRID_LEFT - 4, sub.GridTop - 6) })
		fade(sub.Page, true, 0.2)
	else
		sub.Page.Visible = true
	end
	self:_UpdateCount()
	if window.Search and window.Search.Text ~= "" then
		window.Search.Text = ""
	end
	window:_updateCrumb()
	sub:_RefreshCanvas()
	window:_updateThumb()
end

function Tab:SelectSubTab(sub)
	self.Window:_SelectTab(self)
	self:_SelectSubTab(sub)
end

function Tab:Show()
	if self.ParentTab then
		self.ParentTab:SelectSubTab(self)
	else
		self.Window:_SelectTab(self)
	end
end
Tab.Select = Tab.Show

function Tab:AddSubTab(name, iconName)
	if self.SubtabByName and self.SubtabByName[name] then
		return self.SubtabByName[name]
	end
	local window = self.Window
	if not self.Subtabs then
		self.Subtabs, self.SubtabByName = {}, {}
		self.Scroll.Visible = false
		-- fixed header: title, module count and the sub-tab pills
		local fixed = new("Frame", { Name = "SubtabHeader", Size = UDim2.new(1, 0, 0, 102), BackgroundTransparency = 1, Parent = self.Page })
		self.Heading.Parent = fixed
		local barHolder = new("Frame", {
			Name = "SubtabStrip",
			Position = UDim2.fromOffset(GRID_LEFT, 52),
			Size = UDim2.new(1, -(GRID_LEFT + GRID_RIGHT), 0, 40),
			BackgroundTransparency = 0,
			Theme = { BackgroundColor3 = "Control" },
			Parent = fixed,
		})
		corner(barHolder, 20)
		stroke(barHolder, "ControlStroke", 1, 0)
		local bar = new("ScrollingFrame", {
			Name = "Subtabs",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 0,
			Parent = barHolder,
		})
		local row = new("Frame", { Name = "Buttons", Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 2, Parent = bar })
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(6), Parent = row })
		new("UIPadding", { PaddingLeft = px(3), PaddingRight = px(3), Parent = row })
		self.SubtabBar, self.SubtabButtons = bar, row
		self.SubArea = new("Frame", { Name = "SubPages", Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 1, -102), BackgroundTransparency = 1, ClipsDescendants = true, Parent = self.Page })
	end
	local sub = window:_CreateTab(name, iconName, self)
	sub.ParentTab = self
	local button = new("ImageButton", {
		Name = name,
		LayoutOrder = #self.Subtabs + 1,
		Size = UDim2.new(0, 0, 1, -8),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = self.SubtabButtons,
	})
	button.BackgroundColor3 = WHITE
	corner(button, 14)
	sub.SubtabFill = gradient(button, 0, { "PillA", "PillB" }, numberSeq(0, 0.84, 0.55, 0.9, 1, 0.94))
	sub.SubtabStroke = stroke(button, "PillStroke", 1.5, 1)
	new("UIPadding", { PaddingLeft = px(12), PaddingRight = px(14), Parent = button })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(7), Parent = button })
	sub.SubtabIcon = icon(iconName or name, 15, "SubText", { LayoutOrder = 1, ZIndex = 2, Parent = button })
	sub.SubtabLabel = new("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Strong,
		TextSize = 15,
		Text = name,
		ZIndex = 2,
		Theme = { TextColor3 = "SubText" },
		Parent = button,
	})
	sub.SubtabButton = button
	button.MouseButton1Click:Connect(function()
		self:SelectSubTab(sub)
	end)
	button.MouseEnter:Connect(function()
		if self.ActiveSubtab ~= sub then
			tween(sub.SubtabLabel, 0.15, { TextColor3 = Theme.Text })
		end
	end)
	button.MouseLeave:Connect(function()
		sub:_SetSelected(self.ActiveSubtab == sub)
	end)
	table.insert(self.Subtabs, sub)
	self.SubtabByName[name] = sub
	if not self.ActiveSubtab then
		self:_SelectSubTab(sub)
	end
	return sub
end
