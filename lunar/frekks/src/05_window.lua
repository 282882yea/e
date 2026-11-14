---------------------------------------------------------------------
-- Window
---------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:_closePopup()
	local popup = self._popup
	if popup then
		self._popup = nil
		popup:Close()
	end
end

function Window:_beginDrag(onMove, onEnd)
	self._drag = { Move = onMove, End = onEnd }
end

function Window:_attachTooltip(target, text)
	if type(text) ~= "string" or text == "" then
		return
	end
	local token = 0
	target.MouseEnter:Connect(function()
		token += 1
		local mine = token
		task.delay(0.45, function()
			if mine ~= token or not self.Visible or not target.Parent then
				return
			end
			self:_showTooltip(text)
		end)
	end)
	target.MouseLeave:Connect(function()
		token += 1
		self:_hideTooltip()
	end)
end

function Window:_showTooltip(text)
	local tip = self._tooltip
	self._tooltipLabel.Text = text
	tip.Visible = true
	self._tooltipOn = true
	tip.BackgroundTransparency = 1
	self._tooltipLabel.TextTransparency = 1
	tween(tip, 0.15, { BackgroundTransparency = 0.04 })
	tween(self._tooltipLabel, 0.15, { TextTransparency = 0 })
end

function Window:_hideTooltip()
	self._tooltipOn = false
	if self._tooltip then
		self._tooltip.Visible = false
	end
end

function Window:_updateThumb()
	local tab = self.ActiveTab
	if tab and tab.Subtabs then
		tab = tab.ActiveSubtab
	end
	local thumb = self._thumb
	if not tab or not tab.Scroll then
		thumb.Visible = false
		return
	end
	local scroll = tab.Scroll
	local view = scroll.AbsoluteWindowSize.Y
	local canvas = scroll.AbsoluteCanvasSize.Y
	if view <= 0 or canvas <= view + 1 then
		thumb.Visible = false
		return
	end
	local scale = self._scale
	local top = (scroll.AbsolutePosition.Y - self.Root.AbsolutePosition.Y) / scale + 2
	local trackLength = view / scale - 4
	local length = math.max(28, trackLength * view / canvas)
	local progress = math.clamp(scroll.CanvasPosition.Y / (canvas - view), 0, 1)
	thumb.Visible = true
	thumb.Size = UDim2.fromOffset(6, round(length))
	thumb.Position = UDim2.new(1, -9, 0, round(top + (trackLength - length) * progress))
end

function Window:_updateCrumb()
	local tab = self.ActiveTab
	if not tab then
		return
	end
	self._crumb.Text = tab.Name
end

function Window:_CreateTab(name, iconName, parentTab)
	local tab = setmetatable({
		Window = self,
		Name = name,
		Icon = iconName or name,
		Cards = {},
		Groupboxes = {},
		Tabboxes = {},
		DependencyGroupboxes = {},
	}, Tab)

	local page = new("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parentTab and parentTab.SubArea or self.Pages,
	})
	tab.Page = page
	local scroll = new("ScrollingFrame", {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 0,
		ScrollBarImageTransparency = 1,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	tab.Scroll = scroll
	tab.Sides = { scroll, scroll }

	local gridTop = 12
	if not parentTab then
		local heading = new("Frame", { Name = "Heading", Position = UDim2.fromOffset(14, 17), Size = UDim2.new(1, -40, 0, 27), BackgroundTransparency = 1, Parent = scroll })
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = px(10),
			Parent = heading,
		})
		new("TextLabel", {
			Name = "Title",
			LayoutOrder = 1,
			Size = UDim2.fromOffset(0, 27),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Fonts.PageTitle,
			TextSize = 27,
			Text = name,
			Theme = { TextColor3 = "TextTitle" },
			Parent = heading,
		})
		tab.CountLabel = new("TextLabel", {
			Name = "Count",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Fonts.Body,
			TextSize = 16,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = "0 modules",
			Theme = { TextColor3 = "SubText" },
			Parent = heading,
		})
		tab.Heading, tab.Header = heading, heading
		gridTop = 53
	end
	tab.GridTop = gridTop
	local grid = new("Frame", { Name = "Grid", Position = UDim2.fromOffset(GRID_LEFT, gridTop), Size = UDim2.new(1, -(GRID_LEFT + GRID_RIGHT), 0, 0), BackgroundTransparency = 1, Parent = scroll })
	tab.Grid = grid
	local function column(colName, x)
		local col = new("Frame", {
			Name = colName,
			Position = UDim2.new(x, x > 0 and COLUMN_GAP / 2 or 0, 0, 0),
			Size = UDim2.new(0.5, -COLUMN_GAP / 2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = grid,
		})
		local list = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(CARD_GAP), Parent = col })
		list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			tab:_RefreshCanvas()
		end)
		return col, list
	end
	tab.Left, tab.LeftList = column("Left", 0)
	tab.Right, tab.RightList = column("Right", 0.5)
	tab.Empty = new("TextLabel", {
		Name = "Empty",
		Position = UDim2.fromOffset(14, gridTop + 8),
		Size = UDim2.new(1, -40, 0, 22),
		FontFace = Fonts.CardSub,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Nothing matches your search.",
		Visible = false,
		Theme = { TextColor3 = "SubText" },
		Parent = scroll,
	})
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_closePopup()
		self:_updateThumb()
	end)
	scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		self:_updateThumb()
	end)
	scroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		self:_updateThumb()
	end)

	table.insert(self.Tabs, tab)
	Library.Tabs[name] = tab
	return tab
end

function Window:AddTab(name, iconName)
	if type(name) == "table" then
		iconName = name.Icon
		name = name.Name or name.Title
	end
	name = tostring(name or "Tab")
	local tab = self:_CreateTab(name, iconName)
	local isSettings = name == "Settings" or name == "UI Settings"

	if isSettings and not self._settingsDivider then
		self._settingsDivider = new("Frame", {
			Name = "Divider",
			LayoutOrder = 999,
			Size = UDim2.new(1, -28, 0, 9),
			BackgroundTransparency = 1,
			Parent = self.Nav,
		})
		new("Frame", { Position = UDim2.new(0, 15, 0.5, 0), Size = UDim2.new(1, -15, 0, 1), BackgroundTransparency = 0.1, Theme = { BackgroundColor3 = "LineDim" }, Parent = self._settingsDivider })
	end
	self._navCount = (self._navCount or 0) + 1
	local button = new("TextButton", {
		Name = name,
		LayoutOrder = isSettings and 1000 + self._navCount or self._navCount,
		Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
		ZIndex = 2,
		Parent = self.Nav,
	})
	local glyph = icon(iconName or name, 21, "TextNav", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), ZIndex = 2, Parent = button })
	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(45, 0),
		Size = UDim2.new(1, -70, 1, 0),
		FontFace = Fonts.Nav,
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = name,
		ZIndex = 2,
		Theme = { TextColor3 = "TextNav" },
		Parent = button,
	})
	tab.NavButton, tab.NavIcon, tab.NavLabel = button, glyph, label
	button.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then
			tween(label, 0.15, { TextColor3 = Theme.Text, Position = UDim2.fromOffset(48, 0) })
			tween(glyph, 0.15, { ImageColor3 = Theme.Text })
		end
	end)
	button.MouseLeave:Connect(function()
		tween(label, 0.25, { Position = UDim2.fromOffset(45, 0) })
		if self.ActiveTab ~= tab then
			tween(label, 0.25, { TextColor3 = Theme.TextNav })
			tween(glyph, 0.25, { ImageColor3 = Theme.TextNav })
		end
	end)
	button.MouseButton1Click:Connect(function()
		self:_SelectTab(tab)
	end)
	if not self.ActiveTab then
		self:_SelectTab(tab, true)
	end
	return tab
end

function Window:_SelectTab(tab, instant)
	if tab.ParentTab then
		tab.ParentTab:SelectSubTab(tab)
		return
	end
	local previous = self.ActiveTab
	if previous == tab then
		return
	end
	self:_closePopup()
	self.ActiveTab = tab
	if previous then
		fadeFinish(previous.Page)
		previous.Page.Visible = false
		previous:_SetSelected(false)
	end
	tab:_SetSelected(true)
	if instant or not self.Visible then
		tab.Page.Visible = true
		task.defer(function()
			self:_movePill(true)
		end)
	else
		self:_movePill(false)
		local inner = tab.Subtabs and tab.ActiveSubtab or tab
		inner.Scroll.CanvasPosition = Vector2.new(0, 0)
		inner.Grid.Position = UDim2.fromOffset(GRID_LEFT, inner.GridTop + 16)
		tween(inner.Grid, 0.4, { Position = UDim2.fromOffset(GRID_LEFT, inner.GridTop) })
		fade(tab.Page, true, 0.22)
	end
	if self.Search.Text ~= "" then
		self.Search.Text = ""
	end
	tab:_UpdateCount()
	self:_updateCrumb()
	self:_updateThumb()
end

-- Visibility ------------------------------------------------------------------

function Window:_loop(handle, peak, period)
	if not handle or not handle.Instance then
		return
	end
	local entry = { Handle = handle, Peak = peak, Period = period }
	table.insert(self._loops, entry)
	self:_startLoop(entry)
end

function Window:_startLoop(entry)
	if entry.Tween then
		entry.Tween:Cancel()
	end
	local handle = entry.Handle
	handle.Instance[handle.Property] = effective(handle.Base, handle.Black)
	entry.Tween = TweenService:Create(handle.Instance, TweenInfo.new(entry.Period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		[handle.Property] = effective(entry.Peak, handle.Black),
	})
	entry.Tween:Play()
end

function Window:_restartLoops()
	for _, entry in ipairs(self._loops) do
		self:_startLoop(entry)
	end
end

function Window:SetVisible(visible)
	visible = visible == true
	if self.Visible == visible and self._shown ~= nil then
		return
	end
	self.Visible = visible
	self._shown = visible
	Library.Toggled = visible
	self:_closePopup()
	self:_hideTooltip()
	local root, scaler = self.Root, self._scaler
	if visible then
		self.Gui.Enabled = true
		if self._blur and self.BlurEnabled then
			self._blur:SetEnabled(true)
		end
		scaler.Scale = self._scale * 0.955
		tween(scaler, 0.38, { Scale = self._scale }, Enum.EasingStyle.Back)
		for _, entry in ipairs(self._loops) do
			if entry.Tween then
				entry.Tween:Cancel()
			end
		end
		fade(root, true, 0.24, function()
			self:_restartLoops()
		end)
		self:_applyInputState(true)
	else
		self:_applyInputState(false)
		tween(scaler, 0.2, { Scale = self._scale * 0.97 }, Enum.EasingStyle.Quad)
		fade(root, false, 0.18, function()
			if not self.Visible then
				self.Gui.Enabled = false
				if self._blur then
					self._blur:SetEnabled(false)
				end
			end
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:SetBlurEnabled(enabled)
	self.BlurEnabled = enabled ~= false
	if self._blur then
		self._blur:SetEnabled(self.BlurEnabled and self.Visible)
	end
end

function Window:SetFlowersVisible(visible)
	self.DecorationsEnabled = visible ~= false
	for _, item in ipairs(self._decor) do
		item.Visible = self.DecorationsEnabled
	end
end

function Window:SetGlowStrength(value)
	Library.GlowStrength = math.clamp(tonumber(value) or 0.2, 0, 1)
	self.GlowStrength = Library.GlowStrength
	refreshGlows()
	if self.Visible then
		self:_restartLoops()
	end
end

function Window:SetBackgroundImage(value)
	value = tostring(value or "")
	local id = value
	if string.match(value, "^%d+$") then
		id = "rbxassetid://" .. value
	end
	if value == "" then
		self._backdrop.Image = Assets.background
		self._blossoms.Visible = self.DecorationsEnabled
	else
		self._backdrop.Image = id
	end
	self.BackgroundImage = value
end

function Window:SetScale(scale)
	self._userScale = tonumber(scale) or 1
	self:_fit()
end

function Window:SetSize(size)
	if typeof(size) == "UDim2" then
		size = Vector2.new(size.X.Offset, size.Y.Offset)
	end
	if typeof(size) == "Vector2" then
		self._size = size
		self.Root.Size = UDim2.fromOffset(size.X, size.Y)
		self:_fit()
	end
end

function Window:_fit()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local size = self._size
	local fit = math.min((viewport.X - 16) / size.X, (viewport.Y - 16) / size.Y)
	local scale = math.clamp(math.min(self._userScale, fit), 0.35, 3)
	self._scale = scale
	self._scaler.Scale = scale
end

function Window:SetToggleKeybind(value)
	if typeof(value) == "EnumItem" then
		self.MenuKeybind = value
	end
end

function Window:SetKeybindListVisible(value)
	if Library.KeybindFrame then
		Library.KeybindFrame.Visible = value == true
	end
end

function Window:SetWatermarkVisible(value)
	self.Watermark.Visible = value == true
end

function Window:SetWatermark(text)
	self.WatermarkLabel.Text = tostring(text or "")
end

function Window:SetNotifySide(side)
	side = tostring(side or "Right")
	Library.NotifySide = side
	local area = self.NotificationArea
	local left = string.lower(side) == "left"
	area.AnchorPoint = Vector2.new(left and 0 or 1, 1)
	area.Position = left and UDim2.new(0, 18, 1, -18) or UDim2.new(1, -18, 1, -18)
end

function Window:GetOption(id)
	return Library.Options[id] or Library.Toggles[id]
end

-- Keybind list -------------------------------------------------------------------

function Window:_refreshKeybinds()
	if self._kbQueued then
		return
	end
	self._kbQueued = true
	task.defer(function()
		self._kbQueued = false
		if not self.KeybindListBody or not self.KeybindListBody.Parent then
			return
		end
		local always = Library.KeybindMenuMode == "Always"
		local used = {}
		local order = 0
		for _, bind in ipairs(self.Keybinds) do
			local key = bind:Get()
			local show = bind.ShowInList and key ~= KEY_NONE and (always or bind:IsActive())
			if show then
				order += 1
				local entry = self._kbRows[bind]
				if not entry then
					local row = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = self.KeybindListBody })
					local nameLabel = new("TextLabel", {
						Name = "Name",
						Size = UDim2.new(1, -96, 1, 0),
						FontFace = Fonts.Body,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						Theme = { TextColor3 = "Text" },
						Parent = row,
					})
					local keyText = new("TextLabel", {
						Name = "Key",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0, 92, 1, 0),
						FontFace = Fonts.Strong,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Right,
						Parent = row,
					})
					entry = { Frame = row, Name = nameLabel, Key = keyText }
					self._kbRows[bind] = entry
				end
				entry.Frame.LayoutOrder = order
				entry.Name.Text = bind.DisplayName or bind.Id or "Keybind"
				entry.Key.Text = "[" .. keyLabel(key) .. "]  " .. bind:GetMode()
				entry.Key.TextColor3 = bind:IsActive() and Theme.Accent or Theme.SubText
				entry.Frame.Visible = true
				used[bind] = true
			end
		end
		for bind, entry in pairs(self._kbRows) do
			if not used[bind] then
				entry.Frame.Visible = false
			end
		end
		self._kbEmpty.Visible = order == 0
	end)
end

-- Notifications ---------------------------------------------------------------------

function Window:Notify(message, duration, kind)
	if not self.NotificationsEnabled or not self.NotificationArea or not self.NotificationArea.Parent then
		return
	end
	local title, body = nil, tostring(message)
	if type(message) == "table" then
		title = message.Title
		body = tostring(message.Description or message.Text or message.Content or "")
		duration = message.Time or message.Duration or duration
		kind = message.Type or kind
	end
	duration = tonumber(duration) or 3.2
	self._toasts = (self._toasts or 0) + 1
	local toast = new("Frame", {
		Name = "Toast",
		LayoutOrder = self._toasts,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Visible = false,
		Parent = self.NotificationArea,
	})
	corner(toast, 13)
	gradient(toast, 90, { "HeaderTop", "BodyMid" }, numberSeq(0, 0.04, 1, 0.04))
	local border = stroke(toast, nil, 1, 0)
	border.Color = WHITE
	gradient(border, 90, { "CardStrokeTop", "CardStrokeLow" })
	glow(toast, { Blur = 22, Transparency = 0.7 })
	local accentKey = kind == "Error" and "Risk" or (kind == "Success" and "Green" or "Accent")
	icon(kind == "Error" and "x" or (kind == "Success" and "check" or "sparkles"), 16, accentKey, { Name = "Badge", Position = UDim2.fromOffset(13, title and 13 or 11), Parent = toast })
	local column = new("Frame", { Name = "Text", Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -52, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = toast })
	new("UIPadding", { PaddingTop = px(title and 9 or 10), PaddingBottom = px(title and 11 or 10), Parent = column })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(2), Parent = column })
	if title and tostring(title) ~= "" then
		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			FontFace = Fonts.CardTitle,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(title),
			Theme = { TextColor3 = "TextBright" },
			Parent = column,
		})
	end
	if body ~= "" then
		new("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 16),
			AutomaticSize = Enum.AutomaticSize.Y,
			FontFace = Fonts.Body,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			RichText = true,
			Text = body,
			Theme = { TextColor3 = title and "SubText" or "Text" },
			Parent = column,
		})
	end
	fade(toast, true, 0.25)
	local api = { Frame = toast }
	function api:Destroy()
		if toast.Parent then
			fade(toast, false, 0.3, function()
				toast:Destroy()
			end)
		end
	end
	api.Hide = api.Destroy
	function api:SetText(text)
		local labels = column:GetChildren()
		for _, child in ipairs(labels) do
			if child:IsA("TextLabel") and child.LayoutOrder == 2 then
				child.Text = tostring(text)
			end
		end
	end
	task.delay(duration, function()
		api:Destroy()
	end)
	return api
end

-- Dialogs ---------------------------------------------------------------------------

function Window:AddDialog(id, info)
	info = info or {}
	local window = self
	local overlay = new("TextButton", {
		Name = "Dialog_" .. tostring(id),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.45,
		ZIndex = 60,
		Parent = self.Root,
	})
	corner(overlay, 10)
	local frame = new("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 160),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Active = true,
		ZIndex = 61,
		Parent = overlay,
	})
	corner(frame, CARD_RADIUS)
	gradient(frame, 90, { { 0, "HeaderTop" }, { 0.25, "BodyTop" }, { 0.7, "BodyMid" }, { 1, "BodyLow" } }, numberSeq(0, 0.02, 1, 0.02))
	local border = stroke(frame, nil, 1, 0)
	border.Color = WHITE
	gradient(border, 90, { "CardStrokeTop", "CardStrokeLow" })
	glow(frame, { Blur = 30, Transparency = 0.7 })
	new("TextLabel", {
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 0, 28),
		FontFace = Fonts.CardTitle,
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = tostring(info.Title or "Dialog"),
		ZIndex = 62,
		Theme = { TextColor3 = "TextBright" },
		Parent = frame,
	})
	local desc = new("TextLabel", {
		Position = UDim2.fromOffset(18, 42),
		Size = UDim2.new(1, -36, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Fonts.CardSub,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tostring(info.Description or ""),
		ZIndex = 62,
		Theme = { TextColor3 = "SubText" },
		Parent = frame,
	})
	local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(6, 70), Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 62, Parent = frame })
	local bodyList = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local footer = new("Frame", { Name = "Footer", Size = UDim2.new(1, -36, 0, 32), BackgroundTransparency = 1, ZIndex = 62, Parent = frame })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(8), Parent = footer })

	local dialog = setmetatable({
		Window = self,
		Tab = nil,
		Title = tostring(info.Title or "Dialog"),
		Body = body,
		Container = body,
		BodyList = bodyList,
		Elements = {},
		Overlay = overlay,
		Frame = frame,
		Footer = footer,
		FooterButtons = {},
	}, Card)
	function dialog:Resize()
		task.defer(function()
			if not overlay.Parent then
				return
			end
			local scale = window._scale
			local descH = math.max(0, desc.AbsoluteSize.Y / scale)
			local bodyH = bodyList.AbsoluteContentSize.Y / scale
			local top = 42 + descH + 12
			body.Position = UDim2.fromOffset(6, top)
			footer.Position = UDim2.fromOffset(18, top + bodyH + 10)
			frame.Size = UDim2.fromOffset(480, top + bodyH + 10 + 32 + 16)
		end)
	end
	function dialog:Dismiss()
		if overlay.Parent then
			fade(overlay, false, 0.15, function()
				overlay:Destroy()
			end)
		end
		Library.Dialogues[id] = nil
	end
	dialog.Close = dialog.Dismiss
	function dialog:RemoveFooterButton(buttonId)
		local old = self.FooterButtons[buttonId]
		if old and old.Container then
			old.Container:Destroy()
		end
		self.FooterButtons[buttonId] = nil
	end
	function dialog:AddFooterButton(buttonId, buttonInfo)
		buttonInfo = buttonInfo or {}
		self:RemoveFooterButton(buttonId)
		local variant = buttonInfo.Variant or "Secondary"
		local destructive = variant == "Destructive"
		local primary = variant == "Primary"
		local ghost = variant == "Ghost"
		local btn = new("TextButton", {
			Name = tostring(buttonId),
			LayoutOrder = tonumber(buttonInfo.Order) or 0,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = ghost and 1 or 0,
			FontFace = Fonts.Label,
			TextSize = 15,
			Text = tostring(buttonInfo.Title or buttonId),
			ZIndex = 63,
			Theme = { BackgroundColor3 = primary and "AccentDeep" or "Control", TextColor3 = destructive and "Risk" or "Text" },
			Parent = footer,
		})
		new("UIPadding", { PaddingLeft = px(16), PaddingRight = px(16), Parent = btn })
		corner(btn, 12)
		stroke(btn, primary and "Accent" or (destructive and "Risk" or "ControlStroke"), 1, ghost and 0.4 or 0)
		btn.MouseButton1Click:Connect(function()
			fire(buttonInfo.Callback, self)
			if info.AutoDismiss ~= false and buttonInfo.AutoDismiss ~= false then
				self:Dismiss()
			end
		end)
		local wrap = { Container = btn }
		self.FooterButtons[buttonId] = wrap
		return wrap
	end
	bodyList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		dialog:Resize()
	end)
	if info.OutsideClickDismiss ~= false then
		overlay.MouseButton1Click:Connect(function()
			dialog:Dismiss()
		end)
	end
	for buttonId, buttonInfo in pairs(info.FooterButtons or {}) do
		dialog:AddFooterButton(buttonId, buttonInfo)
	end
	dialog:Resize()
	overlay.Visible = false
	fade(overlay, true, 0.2)
	if Library.Dialogues[id] and Library.Dialogues[id] ~= dialog then
		pcall(function()
			Library.Dialogues[id]:Dismiss()
		end)
	end
	Library.Dialogues[id] = dialog
	return dialog
end

-- Teardown ----------------------------------------------------------------------

function Window:Destroy()
	self._alive = false
	self:_closePopup()
	if self._blur then
		self._blur:Destroy()
	end
	pcall(function()
		ContextActionService:UnbindAction(self._inputAction)
	end)
	pcall(function()
		UserInputService.MouseIconEnabled = true
	end)
	for _, gui in ipairs({ self.Gui, self.NotificationGui, self.MobileToggleGui }) do
		if gui then
			gui:Destroy()
		end
	end
end
