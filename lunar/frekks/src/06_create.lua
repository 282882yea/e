---------------------------------------------------------------------
-- Decorative animation
---------------------------------------------------------------------

local function spawnPetals(window, layer, count)
	if Assets.petal == "" then
		return
	end
	for i = 1, count do
		task.spawn(function()
			local rng = Random.new(os.clock() * 1000 + i * 977)
			task.wait(rng:NextNumber(0, 9))
			while window._alive do
				if not (window.Visible and window.DecorationsEnabled) then
					task.wait(1)
					continue
				end
				local fromLeft = rng:NextNumber() < 0.45
				local startX = fromLeft and rng:NextNumber(0.01, 0.1) or rng:NextNumber(0.86, 0.99)
				local startY = rng:NextNumber(40, 150)
				local fall = rng:NextNumber(260, 430)
				local drift = rng:NextNumber(-90, 90) + (fromLeft and 60 or -60)
				local life = rng:NextNumber(7, 12)
				local size = rng:NextInteger(1, 2) * 7
				local holder = new("Frame", { Position = UDim2.new(startX, 0, 0, startY), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Parent = layer })
				local petal = new("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.fromOffset(size, size * 6 / 7),
					Image = Assets.petal,
					ImageTransparency = 1,
					ResampleMode = Enum.ResamplerMode.Pixelated,
					Rotation = rng:NextNumber(0, 360),
					Parent = holder,
				})
				tween(holder, life, { Position = UDim2.new(startX, drift, 0, startY + fall) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
				local sway = TweenService:Create(
					petal,
					TweenInfo.new(rng:NextNumber(1.4, 2.4), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Position = UDim2.fromOffset(rng:NextNumber(14, 30), 0), Rotation = petal.Rotation + rng:NextNumber(-120, 120) }
				)
				sway:Play()
				tween(petal, 1.2, { ImageTransparency = rng:NextNumber(0.25, 0.5) }, Enum.EasingStyle.Quad)
				task.wait(life - 1.6)
				tween(petal, 1.5, { ImageTransparency = 1 }, Enum.EasingStyle.Quad)
				task.wait(1.6)
				sway:Cancel()
				holder:Destroy()
				task.wait(rng:NextNumber(1, 6))
			end
		end)
	end
end

local function spawnTwinkles(window, image, points, pixel)
	if not points or #points == 0 then
		return
	end
	for i = 1, 5 do
		task.spawn(function()
			local rng = Random.new(os.clock() * 1000 + i * 131)
			task.wait(rng:NextNumber(0, 3))
			while window._alive do
				if not (window.Visible and window.DecorationsEnabled) then
					task.wait(1)
					continue
				end
				local point = points[rng:NextInteger(1, #points)]
				local star = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(point[1] * pixel + pixel / 2, point[2] * pixel + pixel / 2),
					Size = UDim2.fromOffset(pixel, pixel),
					BackgroundColor3 = rgb(255, 236, 246),
					BackgroundTransparency = 1,
					Parent = image,
				})
				local arms = {}
				for _, offset in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					table.insert(arms, new("Frame", {
						Position = UDim2.fromOffset(offset[1] * pixel, offset[2] * pixel),
						Size = UDim2.fromOffset(pixel, pixel),
						BackgroundColor3 = rgb(255, 190, 222),
						BackgroundTransparency = 1,
						Parent = star,
					}))
				end
				tween(star, 0.5, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
				for _, arm in ipairs(arms) do
					tween(arm, 0.5, { BackgroundTransparency = 0.25 }, Enum.EasingStyle.Sine)
				end
				task.wait(rng:NextNumber(0.6, 1.1))
				tween(star, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
				for _, arm in ipairs(arms) do
					tween(arm, 0.6, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
				end
				task.wait(0.65)
				star:Destroy()
				task.wait(rng:NextNumber(0.4, 2.2))
			end
		end)
	end
end

local function mount(gui)
	local ok = false
	if type(gethui) == "function" then
		ok = pcall(function()
			gui.Parent = gethui()
		end)
	end
	if not ok then
		ok = pcall(function()
			gui.Parent = service("CoreGui")
		end)
	end
	if not ok then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function draggable(handle, target, onEnd)
	local dragging, start, origin
	handle.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging, start, origin = true, input.Position, target.Position
		end
	end)
	connect(UserInputService.InputChanged, function(input)
		if dragging and isMove(input) then
			local delta = input.Position - start
			target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		if dragging and isPress(input) then
			dragging = false
			if onEnd then
				onEnd()
			end
		end
	end)
end

---------------------------------------------------------------------
-- CreateWindow
---------------------------------------------------------------------

function Library:CreateWindow(info)
	info = info or {}
	if Library.ActiveWindow and Library.ActiveWindow._alive then
		Library.ActiveWindow:Destroy()
	end
	local size = info.Size or Vector2.new(1024, 620)
	if typeof(size) == "UDim2" then
		size = Vector2.new(math.max(size.X.Offset, 1024), math.max(size.Y.Offset, 620))
	end
	local radius = CORNERS_OK and (info.CornerRadius or 10) or 0
	local layerAlpha = math.sqrt(math.clamp(info.Transparency or 0, 0, 0.6))
	loadAssets(info.AssetFolder or "Frekks Hail v3")

	local self = setmetatable({
		Title = info.Title or "Frekks Hail v3",
		Theme = setmetatable({}, {
			__index = function(_, key)
				return Theme[LEGACY_THEME[key] or key]
			end,
		}),
		Tabs = {},
		Elements = {},
		Options = Library.Options,
		Toggles = Library.Toggles,
		Keybinds = {},
		Visible = false,
		BlurEnabled = info.BlurEnabled ~= false,
		DecorationsEnabled = info.Decorations ~= false,
		NotificationsEnabled = info.Notifications ~= false,
		UnlockMouseWhileOpen = info.UnlockMouseWhileOpen ~= false,
		MenuKeybind = info.ToggleKeybind or Enum.KeyCode.RightShift,
		GlowStrength = Library.GlowStrength,
		_size = size,
		_userScale = info.Scale or 1,
		_scale = 1,
		_alive = true,
		_loops = {},
		_decor = {},
		_kbRows = {},
	}, Window)
	Library.ActiveWindow = self

	-- main gui ---------------------------------------------------------------
	local gui = new("ScreenGui", {
		Name = info.GuiName or HttpService:GenerateGUID(false),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = info.DisplayOrder or 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	pcall(function()
		gui.AutoLocalize = false
	end)
	self.Gui = gui

	local root = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = (info.Center ~= false or not info.Position) and UDim2.fromScale(0.5, 0.5) or info.Position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.Root, self.Holder = root, root
	self._scaler = new("UIScale", { Parent = root })
	self:_fit()

	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = layerAlpha,
		Active = true,
		ZIndex = 0,
		Theme = { BackgroundColor3 = "Window" },
		Parent = root,
	})
	pcall(function()
		body.InputSink = Enum.InputSink.All
	end)
	new("TextButton", { Name = "Modal", Size = UDim2.fromOffset(0, 0), Modal = true, Parent = root })
	corner(body, radius)
	local frameStroke = stroke(body, nil, 1, 0)
	frameStroke.Color = WHITE
	gradient(frameStroke, 90, { { 0, "WindowStrokeTop" }, { 0.06, "WindowStroke" }, { 1, "WindowStrokeLow" } })
	glow(body, { Color = "Black", Blur = 44, Transparency = 0.4, Offset = Vector2.new(0, 14) })
	local aura = glow(body, { Blur = 36, Transparency = 0.72 })
	self._blur = createBlur(info.Blur == nil and "Auto" or info.Blur, body, info.BlurStrength)
	self.Blur = self._blur
	self._body = body

	local backdrop = new("ImageLabel", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		Image = Assets.background,
		ImageTransparency = layerAlpha,
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 1,
		Parent = root,
	})
	corner(backdrop, radius)
	self._backdrop = backdrop
	local video = new("VideoFrame", { Name = "VideoBackground", Size = UDim2.fromScale(1, 1), Visible = false, Looped = true, ZIndex = 1, Parent = root })
	corner(video, radius)
	Library.InnerVideoBackground = video
	local blossoms = new("ImageLabel", {
		Name = "Blossoms",
		Size = UDim2.fromScale(1, 1),
		Image = Assets.blossoms,
		ImageTransparency = 0.1,
		ScaleType = Enum.ScaleType.Crop,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ZIndex = 2,
		Parent = root,
	})
	corner(blossoms, radius)
	self._blossoms = blossoms
	local petals = new("Frame", { Name = "Petals", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3, Parent = root })
	table.insert(self._decor, blossoms)
	table.insert(self._decor, petals)

	local chrome = new("Frame", { Name = "Chrome", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = root })

	-- sidebar -------------------------------------------------------------------
	local sidebar = new("Frame", { Name = "Sidebar", Size = UDim2.new(0, SIDEBAR, 1, -STATUS), BackgroundTransparency = 1, Parent = chrome })
	self.Sidebar = sidebar
	new("Frame", { Name = "Edge", Position = UDim2.fromOffset(SIDEBAR, 0), Size = UDim2.new(0, 1, 1, -STATUS), BackgroundTransparency = 0.1, Theme = { BackgroundColor3 = "LineDim" }, Parent = chrome })

	local brand = new("Frame", { Name = "Brand", Size = UDim2.fromOffset(SIDEBAR, 52), BackgroundTransparency = 1, Parent = sidebar })
	local logoSize = EMBEDDED.sizes and EMBEDDED.sizes.logo or { 720, 145 }
	if Assets.logo ~= "" then
		-- the script name is the Frekks Hail wordmark
		local logo = new("ImageLabel", {
			Name = "Logo",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 2),
			Size = UDim2.fromOffset(SIDEBAR - 22, round((SIDEBAR - 22) * logoSize[2] / logoSize[1])),
			Image = Assets.logo,
			ScaleType = Enum.ScaleType.Fit,
			Parent = brand,
		})
		self.BrandLogo = logo -- the artwork has its own glow; a UIShadow would trace the image rectangle
	else
		icon("moon", 18, "Brand", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(25, 26), Parent = brand })
		new("TextLabel", {
			Name = "Title",
			Position = UDim2.fromOffset(45, 0),
			Size = UDim2.new(1, -55, 1, 0),
			FontFace = Fonts.Brand,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = self.Title,
			Theme = { TextColor3 = "TextBright" },
			Parent = brand,
		})
	end

	local nav = new("ScrollingFrame", {
		Name = "Nav",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = sidebar,
	})
	self.Nav = nav
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(NAV_PITCH - NAV_HEIGHT), Parent = nav })
	new("UIPadding", { PaddingTop = px(2), PaddingRight = px(3), Parent = nav })

	local pill = new("Frame", {
		Name = "Selection",
		Size = UDim2.fromOffset(SIDEBAR - 3 - 4, NAV_HEIGHT + 8),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 1,
		Parent = sidebar,
	})
	corner(pill, 13)
	gradient(pill, 0, { "PillA", "PillB" }, numberSeq(0, 0.84, 0.55, 0.9, 1, 0.94))
	stroke(pill, "PillStroke", 2, 0)
	local pillGlow = glow(pill, { Blur = 16, Transparency = 0.5 })
	local dot = new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.fromOffset(6, 6), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Dot" }, Parent = pill })
	corner(dot, 3)
	glow(dot, { Blur = 6, Transparency = 0.3 })
	self._pill = pill
	self:_loop(pillGlow, 0.72, 1.8)
	-- the pill lives on the sidebar (not in the scroller) so it can sit under the
	-- nav buttons; keep it aligned when the list scrolls
	nav:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local tab = self.ActiveTab
		if tab and tab.NavButton then
			local y = (tab.NavButton.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) / self._scale
			pill.Position = UDim2.fromOffset(4, round(y - 4))
		end
	end)
	function self:_movePill(instant)
		local tab = self.ActiveTab
		if not tab or not tab.NavButton then
			return
		end
		local y = (tab.NavButton.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) / self._scale
		local target = UDim2.fromOffset(4, round(y - 4))
		pill.Visible = true
		if instant then
			pill.Position = target
		else
			tween(pill, 0.42, { Position = target }, Enum.EasingStyle.Back)
		end
	end

	-- top bar --------------------------------------------------------------------
	local topbar = new("Frame", {
		Name = "TopBar",
		Position = UDim2.fromOffset(SIDEBAR + 1, 0),
		Size = UDim2.new(1, -(SIDEBAR + 1), 0, TOPBAR),
		BackgroundTransparency = 0.45,
		Theme = { BackgroundColor3 = "TopBar" },
		Parent = chrome,
	})
	corners(topbar, 0, radius, 0, 0)
	self.Topbar = topbar
	local topline = new("Frame", { Name = "Line", Position = UDim2.fromOffset(SIDEBAR + 1, TOPBAR), Size = UDim2.new(1, -(SIDEBAR + 1), 0, 1), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Line" }, Parent = chrome })
	gradient(topline, 0, nil, numberSeq(0, 0.25, 0.5, 0, 1, 0.3))
	local bar = new("Frame", { Name = "Row", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = topbar })
	new("UIPadding", { PaddingLeft = px(14), PaddingRight = px(54), Parent = bar })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(10), Parent = bar })
	self._crumb = new("TextLabel", {
		Name = "Crumb",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, TOPBAR),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Crumb,
		TextSize = 20,
		Text = "",
		Theme = { TextColor3 = "TextTitle" },
		Parent = bar,
	})
	self.CurrentLabel = self._crumb
	local searchBox = new("Frame", { Name = "Search", LayoutOrder = 2, Size = UDim2.fromOffset(200, 30), BackgroundTransparency = 0.1, Theme = { BackgroundColor3 = "Control" }, Parent = bar })
	new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = searchBox })
	corner(searchBox, 8)
	local searchBorder = stroke(searchBox, "ControlStroke", 1, 0)
	local searchGlow = glow(searchBox, { Blur = 14, Transparency = 1 })
	local searchIcon = icon("search", 13, "SubText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Parent = searchBox })
	local search = new("TextBox", {
		Name = "Input",
		Position = UDim2.fromOffset(33, 0),
		Size = UDim2.new(1, -73, 1, 0),
		FontFace = Fonts.Body,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = info.SearchPlaceholder or "Search settings...",
		ClearTextOnFocus = false,
		Text = "",
		Theme = { TextColor3 = "Text", PlaceholderColor3 = "Placeholder" },
		Parent = searchBox,
	})
	self.Search, self.SearchBox = search, search
	local keycap = new("Frame", { Name = "Shortcut", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(27, 17), BackgroundColor3 = WHITE, BackgroundTransparency = 0.96, Parent = searchBox })
	corner(keycap, 4)
	stroke(keycap, "Keycap", 1, 0)
	icon("command", 10, "KeyText", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Parent = keycap })
	new("TextLabel", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -16, 1, 0), FontFace = Fonts.Strong, TextSize = 13, Text = "K", Theme = { TextColor3 = "KeyText" }, Parent = keycap })
	search.Focused:Connect(function()
		tween(searchBorder, 0.15, { Color = Theme.Accent })
		tween(searchIcon, 0.15, { ImageColor3 = Theme.Accent })
		setGlow(searchGlow, 0.72, 0.2)
	end)
	search.FocusLost:Connect(function()
		tween(searchBorder, 0.25, { Color = Theme.ControlStroke })
		tween(searchIcon, 0.25, { ImageColor3 = Theme.SubText })
		setGlow(searchGlow, 1, 0.3)
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local tab = self.ActiveTab
		if not tab then
			return
		end
		local query = string.lower(search.Text)
		self.SearchQuery = query
		if tab.Subtabs then
			for _, sub in ipairs(tab.Subtabs) do
				sub:_ApplySearch(query)
			end
		else
			tab:_ApplySearch(query)
		end
	end)
	self.SearchQuery = ""

	-- pages, scrollbar, status bar ----------------------------------------------
	self.Pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(SIDEBAR + 1, TOPBAR + 1),
		Size = UDim2.new(1, -(SIDEBAR + 1), 1, -(TOPBAR + 1 + STATUS)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = chrome,
	})
	self.Content = self.Pages
	local thumb = new("TextButton", { Name = "ScrollThumb", Size = UDim2.fromOffset(6, 60), BackgroundTransparency = 0.05, Visible = false, ZIndex = 6, Theme = { BackgroundColor3 = "Thumb" }, Parent = chrome })
	corner(thumb, 3)
	self._thumb = thumb
	thumb.MouseEnter:Connect(function()
		tween(thumb, 0.15, { BackgroundColor3 = Theme.Accent })
	end)
	thumb.MouseLeave:Connect(function()
		tween(thumb, 0.3, { BackgroundColor3 = Theme.Thumb })
	end)
	thumb.InputBegan:Connect(function(input)
		local tab = self.ActiveTab
		if tab and tab.Subtabs then
			tab = tab.ActiveSubtab
		end
		if not isPress(input) or not tab then
			return
		end
		local scroll = tab.Scroll
		local startY, startCanvas = input.Position.Y, scroll.CanvasPosition.Y
		self:_beginDrag(function(position)
			local view = scroll.AbsoluteWindowSize.Y
			local canvas = scroll.AbsoluteCanvasSize.Y
			local travel = view - 4 * self._scale - thumb.AbsoluteSize.Y
			if travel > 0 then
				local delta = (position.Y - startY) / travel * (canvas - view)
				scroll.CanvasPosition = Vector2.new(0, math.clamp(startCanvas + delta, 0, canvas - view))
			end
		end)
	end)

	local status = new("Frame", { Name = "Status", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, STATUS), BackgroundTransparency = 0.04, Theme = { BackgroundColor3 = "Status" }, Parent = chrome })
	corners(status, 0, 0, radius, radius)
	new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "StatusLine" }, Parent = status })
	local footerText = info.Footer and info.Footer ~= "" and (self.Title .. "  ·  " .. tostring(info.Footer)) or self.Title
	self._status = new("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(11, 1),
		Size = UDim2.new(1, -60, 1, -1),
		FontFace = Fonts.Body,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = footerText,
		Theme = { TextColor3 = "StatusText" },
		Parent = status,
	})
	local grip = new("ImageButton", { Name = "Resize", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -2), Size = UDim2.fromOffset(18, 18), Theme = { ImageColor3 = "Grip" }, Parent = status })
	setIcon(grip, "grip")
	grip.MouseEnter:Connect(function()
		tween(grip, 0.15, { ImageColor3 = Theme.Accent })
	end)
	grip.MouseLeave:Connect(function()
		tween(grip, 0.3, { ImageColor3 = Theme.Grip })
	end)

	-- flowers -------------------------------------------------------------------------
	local artSizes = EMBEDDED.sizes or {}
	local leftSize = artSizes.flowers_left or { 28, 80 }
	local rightSize = artSizes.flowers_right or { 46, 116 }
	local leftArt = new("ImageLabel", {
		Name = "FlowersLeft",
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.fromOffset(leftSize[1] * 2, leftSize[2] * 2),
		Image = Assets.flowers_left,
		ImageTransparency = 0.28,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ZIndex = 20,
		Parent = root,
	})
	local rightArt = new("ImageLabel", {
		Name = "FlowersRight",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -1, 0, 1),
		Size = UDim2.fromOffset(rightSize[1] * 2, rightSize[2] * 2),
		Image = Assets.flowers_right,
		ImageTransparency = 0.05,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ZIndex = 20,
		Parent = root,
	})
	table.insert(self._decor, leftArt)
	table.insert(self._decor, rightArt)

	-- popups and tooltip ------------------------------------------------------------------
	self.PopupLayer = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = root })
	local tooltip = new("Frame", {
		Name = "Tooltip",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 80,
		Theme = { BackgroundColor3 = "Popup" },
		Parent = self.PopupLayer,
	})
	corner(tooltip, 8)
	stroke(tooltip, "CardStrokeMid", 1, 0)
	new("UIPadding", { PaddingLeft = px(9), PaddingRight = px(9), PaddingTop = px(6), PaddingBottom = px(6), Parent = tooltip })
	local tooltipLabel = new("TextLabel", {
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = Fonts.Body,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 80,
		Theme = { TextColor3 = "Text" },
		Parent = tooltip,
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(280, math.huge), Parent = tooltipLabel })
	self._tooltip, self._tooltipLabel = tooltip, tooltipLabel
	connect(RunService.RenderStepped, function()
		if self._tooltipOn then
			local mouse = mouseLocation()
			local rel = (mouse - root.AbsolutePosition) / self._scale
			tooltip.Position = UDim2.fromOffset(round(rel.X + 14), round(rel.Y + 18))
		end
	end)

	-- dragging and resizing --------------------------------------------------------------
	local function hookDrag(handle)
		handle.InputBegan:Connect(function(input)
			if not isPress(input) or self._drag then
				return
			end
			local start, origin, moved = input.Position, root.Position, false
			self:_beginDrag(function(position)
				local delta = position - start
				if not moved and math.abs(delta.X) + math.abs(delta.Y) < 4 then
					return
				end
				moved = true
				tween(root, 0.08, { Position = UDim2.new(origin.X.Scale, origin.X.Offset + delta.X, origin.Y.Scale, origin.Y.Offset + delta.Y) }, Enum.EasingStyle.Quad)
			end)
		end)
	end
	hookDrag(topbar)
	hookDrag(brand)
	hookDrag(status)
	grip.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		local start, origin = input.Position, self._size
		local minSize = info.MinSize or Vector2.new(820, 460)
		self:_beginDrag(function(position)
			local delta = (position - start) / self._scale
			local width = math.max(minSize.X, round(origin.X + delta.X * 2))
			local height = math.max(minSize.Y, round(origin.Y + delta.Y * 2))
			self._size = Vector2.new(width, height)
			root.Size = UDim2.fromOffset(width, height)
		end, function()
			self:_fit()
		end)
	end)
	connect(UserInputService.InputChanged, function(input)
		local drag = self._drag
		if drag and isMove(input) then
			drag.Move(input.Position)
		end
	end)
	connect(UserInputService.InputEnded, function(input)
		local drag = self._drag
		if drag and isPress(input) then
			self._drag = nil
			if drag.End then
				drag.End()
			end
		end
		if self._capturing == nil then
			for _, bind in ipairs(self.Keybinds) do
				if bind.Mode == "Hold" then
					bind:_input(input, false)
				end
			end
		end
	end)
	connect(UserInputService.WindowFocusReleased, function()
		for _, bind in ipairs(self.Keybinds) do
			bind:_release()
		end
	end)

	-- keyboard: menu key, keybinds, Ctrl+K, Escape ----------------------------------------
	connect(UserInputService.InputBegan, function(input, processed)
		if not self._alive or self._capturing then
			return
		end
		local focused = UserInputService:GetFocusedTextBox()
		if not processed and not focused then
			local menuKey = self.MenuKeybind
			local option = Library.ToggleKeybind
			if type(option) == "table" then
				menuKey = stringToEnum(option.Value or (option.Get and option:Get()))
			end
			if inputMatches(input, menuKey) then
				self:Toggle()
			end
			for _, bind in ipairs(self.Keybinds) do
				if bind ~= option then
					bind:_input(input, true)
				end
			end
		end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.K and self.Visible then
			local held = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftMeta)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightMeta)
			if held then
				task.defer(function()
					RunService.RenderStepped:Wait()
					search:CaptureFocus()
				end)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape and self._popup then
			self:_closePopup()
		end
	end)

	-- input ownership: the game never sees clicks or scrolls aimed at the menu ----------------
	local surfaces = { [root] = true }
	local owners = {}
	self._inputAction = HttpService:GenerateGUID(false) .. "_MenuPointer"
	local function contains(surface, point)
		if not surface.Parent then
			return false
		end
		local ancestor = surface
		while ancestor do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				return false
			end
			if ancestor:IsA("ScreenGui") then
				if not ancestor.Enabled then
					return false
				end
				break
			end
			ancestor = ancestor.Parent
		end
		if not ancestor then
			return false
		end
		local p, s = surface.AbsolutePosition, surface.AbsoluteSize
		return point.X >= p.X and point.Y >= p.Y and point.X < p.X + s.X and point.Y < p.Y + s.Y
	end
	function self:RegisterInputSurface(surface)
		surfaces[surface] = true
		surface.Active = true
		pcall(function()
			surface.InputSink = Enum.InputSink.All
		end)
		return function()
			surfaces[surface] = nil
		end
	end
	function self:IsPointerOverMenu(point)
		if not gui.Enabled or not self.Visible then
			return false
		end
		point = point or mouseLocation()
		for surface in pairs(surfaces) do
			if contains(surface, point) then
				return true
			end
		end
		return self._popup ~= nil and self._popup:ContainsPoint(point)
	end
	pcall(function()
		ContextActionService:BindActionAtPriority(self._inputAction, function(_, state, input)
			local kind = input.UserInputType
			local key = kind == Enum.UserInputType.Touch and input or kind
			local point
			if kind == Enum.UserInputType.Touch then
				local inset = GuiService:GetGuiInset()
				point = Vector2.new(input.Position.X - inset.X, input.Position.Y - inset.Y)
			end
			local owned = owners[key]
			if state == Enum.UserInputState.Begin or kind == Enum.UserInputType.MouseWheel then
				owned = self:IsPointerOverMenu(point)
				owners[key] = owned
			elseif owned == nil and state ~= Enum.UserInputState.End and state ~= Enum.UserInputState.Cancel then
				owned = self:IsPointerOverMenu(point)
			end
			if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				owners[key] = nil
			end
			return owned and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
		end, false, 5000, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.MouseWheel, Enum.UserInputType.Touch)
	end)
	function self:_applyInputState(open)
		if open and self.UnlockMouseWhileOpen then
			pcall(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
		end
		pcall(function()
			UserInputService.MouseIconEnabled = true
		end)
	end
	connect(RunService.RenderStepped, function()
		if self.Visible and self.UnlockMouseWhileOpen then
			pcall(function()
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			end)
		end
	end)

	local camera = workspace.CurrentCamera
	if camera then
		connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			self:_fit()
		end)
	end

	-- notification gui: toasts, watermark, keybind list -------------------------------------
	local notificationGui = new("ScreenGui", {
		Name = HttpService:GenerateGUID(false),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = gui.DisplayOrder + 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	self.NotificationGui = notificationGui
	local area = new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = notificationGui })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = px(10), Parent = area })
	self.NotificationArea = area
	self:SetNotifySide(Library.NotifySide)

	local watermark = new("Frame", {
		Name = "Watermark",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Visible = false,
		Active = true,
		Parent = notificationGui,
	})
	corner(watermark, 15)
	gradient(watermark, 0, { "HeaderTop", "BodyMid" }, numberSeq(0, 0.06, 1, 0.06))
	local wmBorder = stroke(watermark, nil, 1, 0)
	wmBorder.Color = WHITE
	gradient(wmBorder, 0, { "CardStrokeTop", "CardStrokeLow" })
	glow(watermark, { Blur = 16, Transparency = 0.75 })
	new("UIPadding", { PaddingLeft = px(12), PaddingRight = px(14), Parent = watermark })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = px(8), Parent = watermark })
	icon("crown", 14, "Accent", { LayoutOrder = 1, Parent = watermark })
	self.WatermarkLabel = new("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Strong,
		TextSize = 14,
		Text = self.Title,
		Theme = { TextColor3 = "Text" },
		Parent = watermark,
	})
	self.Watermark = watermark
	draggable(watermark, watermark)

	local kb = new("Frame", {
		Name = "Keybinds",
		Position = UDim2.new(0, 16, 0.5, -60),
		Size = UDim2.fromOffset(210, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		Visible = false,
		Active = true,
		Parent = notificationGui,
	})
	corner(kb, 12)
	gradient(kb, 90, { "HeaderTop", "BodyMid" }, numberSeq(0, 0.06, 1, 0.06))
	local kbBorder = stroke(kb, nil, 1, 0)
	kbBorder.Color = WHITE
	gradient(kbBorder, 90, { "CardStrokeTop", "CardStrokeLow" })
	glow(kb, { Blur = 16, Transparency = 0.78 })
	local kbHeader = new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = kb })
	icon("keyboard", 14, "Accent", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Parent = kbHeader })
	new("TextLabel", { Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), FontFace = Fonts.CardTitle, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Text = "Keybinds", Theme = { TextColor3 = "TextBright" }, Parent = kbHeader })
	new("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.2, Theme = { BackgroundColor3 = "HeaderDivider" }, Parent = kb })
	local kbBody = new("Frame", { Name = "Body", Position = UDim2.fromOffset(11, 35), Size = UDim2.new(1, -22, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = kb })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = kbBody })
	new("UIPadding", { PaddingBottom = px(8), Parent = kbBody })
	self._kbEmpty = new("TextLabel", { LayoutOrder = 9999, Size = UDim2.new(1, 0, 0, 22), FontFace = Fonts.CardSub, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = "No active keybinds", Theme = { TextColor3 = "SubText" }, Parent = kbBody })
	self.KeybindList, self.KeybindListBody = kb, kbBody
	draggable(kbHeader, kb)

	-- mobile toggle -----------------------------------------------------------------------------
	local mobileGui = new("ScreenGui", { Name = HttpService:GenerateGUID(false), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = gui.DisplayOrder + 2, Enabled = UserInputService.TouchEnabled or info.ShowMobileToggleOnDesktop == true })
	self.MobileToggleGui = mobileGui
	local mobile = new("ImageButton", { Name = "Toggle", Position = UDim2.fromOffset(16, 80), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 0.1, Theme = { BackgroundColor3 = "Popup" }, Parent = mobileGui })
	corner(mobile, 23)
	stroke(mobile, "PillStroke", 1.5, 0)
	glow(mobile, { Blur = 14, Transparency = 0.5 })
	icon("crown", 22, "Accent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = mobile })
	local mobileMoved = false
	mobile.InputBegan:Connect(function(input)
		if isPress(input) then
			mobileMoved = false
		end
	end)
	draggable(mobile, mobile, function()
		task.defer(function()
			mobileMoved = false
		end)
	end)
	mobile:GetPropertyChangedSignal("Position"):Connect(function()
		mobileMoved = true
	end)
	mobile.MouseButton1Click:Connect(function()
		if not mobileMoved then
			self:Toggle()
		end
	end)
	self.MobileToggleButton = mobile

	-- mount and animate ------------------------------------------------------------------------
	mount(gui)
	mount(notificationGui)
	mount(mobileGui)
	self:_loop(aura, 0.84, 3.2)
	spawnPetals(self, petals, info.PetalCount or 9)
	if EMBEDDED.sparkles then
		spawnTwinkles(self, leftArt, EMBEDDED.sparkles.flowers_left, 2)
		spawnTwinkles(self, rightArt, EMBEDDED.sparkles.flowers_right, 2)
	end

	Library.Window = self
	Library.ScreenGui = gui
	Library.KeybindFrame = kb
	Library.KeybindContainer = kbBody
	Library.Unloaded = false
	if info.AutoShow == false then
		self.Visible = false
		Library.Toggled = false
		root.Visible = false
		gui.Enabled = false
		self._shown = false
	else
		task.defer(function()
			if self._alive then
				self:SetVisible(true)
			end
		end)
	end
	return self
end
