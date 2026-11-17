-- UI layer: the calls frekksec makes (window, tabs, groupboxes, controls, toasts and the
-- live preview) implemented on top of the Sakura UI library bundled above.
local function loadFrekksecUI(private)
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local black = Color3.new(0, 0, 0)
    local ui = {
        Registry = setmetatable({}, {__mode = "k"}),
        -- Theme colours. The settings tab edits these, then calls UpdateColorsUsingRegistry.
        MainColor = Color3.fromRGB(54, 30, 72),
        AccentColor = Color3.fromRGB(255, 126, 182),
        BackgroundColor = Color3.fromRGB(35, 19, 48),
        OutlineColor = Color3.fromRGB(104, 66, 128),
        FontColor = Color3.fromRGB(255, 236, 245),
        SurfaceGlowColor = Color3.fromRGB(255, 126, 182),
        ControlGlowColor = Color3.fromRGB(255, 126, 182),
        LogoGlowColor = Color3.fromRGB(180, 124, 255),
        Scene = "Dusk",
        Library = Sakura,
        _connections = {},
        _shadows = setmetatable({}, {__mode = "k"}),
        _glowStrength = 0.35,
    }
    private.Toggles, private.Options = {}, {}

    local GUI = {Frame = true, TextLabel = true, TextButton = true, TextBox = true, ScrollingFrame = true, ImageLabel = true}
    local function create(class, properties)
        local object = Instance.new(class)
        if GUI[class] then object.BorderSizePixel = 0 end
        for key, value in pairs(properties) do
            if key ~= "Parent" then object[key] = value end
        end
        object.Parent = properties.Parent
        return object
    end
    -- Colours derived from the five theme colours. Light themes get pale bars instead of dark ones.
    local function derive()
        local bg, accent, font = ui.BackgroundColor, ui.AccentColor, ui.FontColor
        ui.Bright = 0.299 * bg.R + 0.587 * bg.G + 0.114 * bg.B > 0.55
        ui.StageColor = ui.Bright and bg:Lerp(accent, 0.12) or bg:Lerp(black, 0.5)
        ui.GridColor = ui.OutlineColor:Lerp(bg, 0.5)
        ui.SubColor = font:Lerp(bg, 0.4)
        ui.HeaderColor = ui.Bright and bg:Lerp(accent, 0.16) or bg:Lerp(black, 0.3)
        ui.FrameColor = ui.Bright and font:Lerp(accent, 0.25) or bg:Lerp(black, 0.55)
    end
    derive()

    function ui:Create(class, props) return create(class, props) end
    function ui:CreateLabel(props)
        props.Font = props.Font or Enum.Font.Arcade
        props.TextSize = props.TextSize or 8
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
        props.TextColor3 = props.TextColor3 or self.FontColor
        return create("TextLabel", props)
    end
    function ui:AddToRegistry(object, props) self.Registry[object] = props end
    function ui:GetDarkerColor(color) return color:Lerp(black, 0.35) end
    function ui:_watch(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(self._connections, connection)
        return connection
    end

    -- Extra UIShadows (HUD, keybind list...) follow the window glow settings.
    function ui:_paintShadows()
        for shadow in pairs(self._shadows) do
            if shadow.Parent then
                shadow.Color = self.SurfaceGlowColor
                shadow.Transparency = 1 - math.clamp(self._glowStrength * 1.4, 0, 1)
            end
        end
    end
    function ui:SurfaceShadow(parent, blur)
        if not Sakura.Support.UIShadow then return nil end
        local made, shadow = pcall(function()
            local item = Instance.new("UIShadow")
            item.BlurRadius = UDim.new(0, blur or 12)
            item.Parent = parent
            return item
        end)
        if not made then return nil end
        self._shadows[shadow] = true
        self:_paintShadows()
        return shadow
    end
    -- Border lights up under the pointer.
    function ui:AttachButtonGlow(button)
        local border = button:FindFirstChildOfClass("UIStroke")
        if not border then return end
        button.MouseEnter:Connect(function() border.Color = self.AccentColor end)
        button.MouseLeave:Connect(function() border.Color = self.OutlineColor end)
    end

    -- Maps the five theme colours onto a Sakura theme and recolours everything registered.
    function ui:UpdateColorsUsingRegistry()
        derive()
        local accent, bg, main, line, font = self.AccentColor, self.BackgroundColor, self.MainColor, self.OutlineColor, self.FontColor
        Sakura:SetTheme({
            Scene = self.Scene,
            Outline = self.FrameColor,
            Accent = accent,
            Panel = bg,
            Header = self.HeaderColor,
            Element = main,
            ElementHover = main:Lerp(font, 0.1),
            Stroke = line,
            Text = font,
            SubText = self.SubColor,
            Knob = self.Bright and accent:Lerp(black, 0.35) or Color3.new(1, 1, 1),
        })
        Sakura:SetGlow({SurfaceColor = self.SurfaceGlowColor, ControlColor = self.ControlGlowColor, LogoColor = self.LogoGlowColor})
        for object, properties in pairs(self.Registry) do
            if object.Parent then
                for property, key in pairs(properties) do object[property] = self[key] end
            end
        end
        self:_paintShadows()
    end

    -- Look settings --------------------------------------------------------
    function ui:SetMenuOpacity(_, percent) Sakura:SetGlass({Transparency = 1 - percent / 100}) end
    function ui:SetPanelBlur(level) Sakura:SetGlass({Blur = level}) end
    function ui:SetButtonGlow(strength, controls) Sakura:SetGlow({ElementStrength = strength, Elements = controls ~= false}) end
    function ui:SetWindowGlow(strength, width)
        self._glowStrength = strength
        Sakura:SetGlow({Strength = strength, Size = width})
        self:_paintShadows()
    end
    function ui:SetLogoGlow(percent) Sakura:SetGlow({LogoStrength = math.clamp((tonumber(percent) or 85) / 100, 0, 1)}) end
    -- Frost (baked blur) is skipped while a custom background image covers the scene.
    function ui:SetFrost(on) Sakura:SetFrost({Enabled = on ~= false}) end
    function ui:SetGlowPulse(on) Sakura:SetGlow({Pulse = on == true}) end
    function ui:SetScene(name)
        if self.Scene ~= name then self.Scene = name; self:UpdateColorsUsingRegistry() end
    end
    function ui:SetBackdrop(on) if self.Window then self.Window:SetBackground(on) end end
    function ui:SetPetals(on, count) Sakura:SetPetals({Enabled = on == true, Count = count}) end
    function ui:SetScale(percent) if self.Window then self.Window:SetScale(percent) end end
    function ui:SetToggleKey(key) if self.Window then self.Window:SetToggleKey(key) end end
    function ui:CaptureKeys(active)
        if active then Sakura:CaptureKeys(true)
        else task.defer(function() Sakura:CaptureKeys(false) end) end -- let both key handlers see this press
    end
    function ui:SetOpen(value) if self.Window then self.Window:SetVisible(value) end end
    function ui:IsOpen() return self.Window ~= nil and self.Window.Visible end
    function ui:SetNotificationSide(side) Sakura:SetNotifications({Side = side}) end
    function ui:Notify(text, duration) Sakura:Notify({Title = "frekksec", Content = tostring(text), Duration = duration or 4}) end
    function ui:SetWatermarkVisibility(value) self.Mark:SetVisible(value) end
    function ui:SetWatermark(text) self.Mark:SetFields(string.split(text, " | ")) end
    function ui:Mount() end
    function ui:Unload()
        if self._unloaded then return end
        self._unloaded = true
        for _, connection in ipairs(self._connections) do pcall(connection.Disconnect, connection) end
        table.clear(self._connections)
        Sakura:Unload()
    end

    function ui:MakeDraggable(object, keepOnScreen)
        local pointer, origin, start
        object.Active = true
        object.InputBegan:Connect(function(input)
            local kind = input.UserInputType
            if not pointer and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
                pointer, origin, start = input, object.Position, input.Position
            end
        end)
        self:_watch(UIS.InputChanged, function(input)
            if pointer and (input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement)) then
                local delta = input.Position - start
                if keepOnScreen then
                    local screen, size, anchor = self.ScreenGui.AbsoluteSize, object.AbsoluteSize, object.AnchorPoint
                    local minX, minY = size.X * anchor.X, size.Y * anchor.Y
                    local x = math.clamp(screen.X * origin.X.Scale + origin.X.Offset + delta.X,
                        minX, math.max(minX, screen.X - size.X + minX))
                    local y = math.clamp(screen.Y * origin.Y.Scale + origin.Y.Offset + delta.Y,
                        minY, math.max(minY, screen.Y - size.Y + minY))
                    object.Position = UDim2.new(origin.X.Scale, x - screen.X * origin.X.Scale,
                        origin.Y.Scale, y - screen.Y * origin.Y.Scale)
                else
                    object.Position = origin + UDim2.fromOffset(delta.X, delta.Y)
                end
            end
        end)
        self:_watch(UIS.InputEnded, function(input)
            if input == pointer or input.UserInputType == Enum.UserInputType.MouseButton1 then pointer = nil end
        end)
    end

    -- Controls --------------------------------------------------------------
    local function option(registry, id, initial, render)
        local item = {Value = initial, listeners = {}}
        function item:OnChanged(fn) table.insert(self.listeners, fn) end
        function item:SetValue(value, fromControl)
            local changed = self.Value ~= value
            self.Value = value
            if not fromControl then render(value) end
            if changed then
                for _, listener in ipairs(self.listeners) do listener(value) end
            end
        end
        registry[id] = item
        return item
    end
    local function group(box)
        local g = {Container = box.Container, Box = box}
        function g:Resize() end
        function g:AddButton(text, fn)
            local control = box:AddButton({Name = text, Callback = fn})
            return {SetText = function(_, value) control:SetName(value) end}
        end
        function g:AddLabel(text)
            local label = box:AddLabel(text)
            local line = label.TextLabel
            if #tostring(text) > 36 then label:SetWrapped(true) end -- long hints wrap instead of being cut off
            -- Callers switch TextWrapped on for long text; make the row grow with it.
            line:GetPropertyChangedSignal("TextWrapped"):Connect(function()
                if line.TextWrapped and line.AutomaticSize == Enum.AutomaticSize.None then label:SetWrapped(true) end
            end)
            return {
                TextLabel = line,
                AddColorPicker = function(_, id, info)
                    label.Instance.Visible = false
                    local item
                    local picker = box:AddColorPicker({Name = text, Default = info.Default, Callback = function(value)
                        if item then item:SetValue(value, true) end
                    end})
                    item = option(private.Options, id, info.Default, function(value) picker:Set(value, true) end)
                    item.SetValueRGB = item.SetValue
                    return item
                end,
            }
        end
        function g:AddToggle(id, info)
            local item
            local control = box:AddToggle({Name = info.Text, Default = false, Callback = function(value)
                if item then item:SetValue(value, true) end
            end})
            control:Set(info.Default == true, true)
            item = option(private.Toggles, id, info.Default, function(value) control:Set(value, true) end)
            return item
        end
        function g:AddSlider(id, info)
            local item
            local wide = info.ToFraction ~= nil
            local function toSlider(value) return wide and info.ToFraction(value) * 1000 or value end
            local control = box:AddSlider({
                Name = info.Text, Min = wide and 0 or info.Min, Max = wide and 1000 or info.Max,
                Default = toSlider(info.Default), Increment = wide and 1 or 10 ^ -(info.Rounding or 0),
                Format = wide and function(value) return info.Format(info.FromFraction(value / 1000)) end or nil,
                Callback = function(value)
                    if item then item:SetValue(wide and info.FromFraction(value / 1000) or value, true) end
                end,
            })
            item = option(private.Options, id, info.Default, function(value) control:Set(toSlider(value), true) end)
            return item
        end
        function g:AddInput(id, info)
            local item
            local initial = tostring(info.Default or "")
            local control = box:AddTextbox({Name = info.Text, Default = initial, Callback = function(value)
                if item then item:SetValue(value, true) end
            end})
            item = option(private.Options, id, initial, function(value) control:Set(tostring(value or ""), true) end)
            return item
        end
        function g:AddDropdown(id, info)
            local item
            local default = info.Default
            if not info.AllowNull and not table.find(info.Values, default) then default = info.Values[1] end
            local control = box:AddDropdown({Name = info.Text, Options = info.Values, Default = default, Callback = function(value)
                if item then item:SetValue(value, true) end
            end})
            item = option(private.Options, id, control.Value, function(value) control:Set(value, true) end)
            item.Values = info.Values
            function item:SetValues() control:Refresh(self.Values) end
            return item
        end
        return g
    end
    local function tabbox(box)
        return {AddTab = function(_, name) return group(box:AddTab(name)) end}
    end
    local function surface(host)
        return {
            AddLeftGroupbox = function(_, title) return group(host:AddLeftGroupbox(title)) end,
            AddRightGroupbox = function(_, title) return group(host:AddRightGroupbox(title)) end,
            AddLeftTabbox = function() return tabbox(host:AddLeftTabbox()) end,
            AddRightTabbox = function() return tabbox(host:AddRightTabbox()) end,
        }
    end

    -- Live preview ----------------------------------------------------------
    -- A neutral robot that mirrors the movement mode frekksec reports. It never drives
    -- the game or claims a replicated server position.
    local function buildStatus(window)
        local side = window:AddSidePanel({Title = "live preview", Width = 250})
        local pane = side.Container
        local STAGE_W, STAGE_H = side.Width - 16, 168
        local stage = create("Frame", {
            Name = "FrekksecMovementVisual", Parent = pane, Position = UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(STAGE_W, STAGE_H), BackgroundColor3 = ui.StageColor, ClipsDescendants = true,
        })
        ui:AddToRegistry(stage, {BackgroundColor3 = "StageColor"})
        local edge = create("UIStroke", {Parent = stage, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Thickness = 1, Color = ui.OutlineColor})
        ui:AddToRegistry(edge, {Color = "OutlineColor"})
        local function gridLine(size, position)
            local item = create("Frame", {Parent = stage, Size = size, Position = position, BackgroundColor3 = ui.GridColor})
            ui:AddToRegistry(item, {BackgroundColor3 = "GridColor"})
        end
        for i = 1, 3 do gridLine(UDim2.new(1, -10, 0, 1), UDim2.new(0, 5, i / 4, 0)) end
        for i = 1, 5 do gridLine(UDim2.new(0, 1, 1, -38), UDim2.new(i / 6, 0, 0, 23)) end
        local modeText = ui:CreateLabel({Parent = stage, Text = "ROBOT / IDLE", Position = UDim2.fromOffset(8, 7),
            Size = UDim2.new(1, -16, 0, 10), ZIndex = 12, TextColor3 = ui.AccentColor})
        ui:AddToRegistry(modeText, {TextColor3 = "AccentColor"})
        local foot = ui:CreateLabel({Parent = stage, Text = "LIVE / MOVEMENT PREVIEW", Position = UDim2.new(0, 8, 1, -16),
            Size = UDim2.new(1, -16, 0, 10), ZIndex = 12, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = ui.SubColor})
        ui:AddToRegistry(foot, {TextColor3 = "SubColor"})

        local ring = create("Frame", {Parent = stage, Size = UDim2.fromOffset(86, 86), Position = UDim2.fromScale(0.5, 0.56),
            AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1})
        local ringStroke = create("UIStroke", {Parent = ring, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1, Transparency = 0.35, Color = ui.AccentColor})
        ui:AddToRegistry(ringStroke, {Color = "AccentColor"})

        local limbs = {}
        local function figure(role)
            local avatar = create("Frame", {
                Name = "StatusRobot_" .. role, Parent = stage, BackgroundTransparency = 1,
                Size = UDim2.fromOffset(48, 82), Position = UDim2.fromScale(0.5, 0.55),
                AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = role == "mover" and 8 or 6,
            })
            local alpha = role == "ghost" and 0.62 or (role == "target" and 0.42 or 0)
            local body = role == "target" and Color3.fromRGB(150, 140, 175) or ui.AccentColor
            local function block(name, x, y, w, h, fill, accent)
                local part = create("Frame", {
                    Name = name, Parent = avatar, Size = UDim2.fromScale(w, h), Position = UDim2.fromScale(x, y),
                    AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = fill,
                    BackgroundTransparency = alpha, ZIndex = avatar.ZIndex,
                })
                if accent and role ~= "target" then ui:AddToRegistry(part, {BackgroundColor3 = "AccentColor"}) end
                return part
            end
            block("Antenna", 0.5, 0.015, 0.07, 0.09, body, true)
            block("Head", 0.5, 0.09, 0.62, 0.25, Color3.fromRGB(255, 238, 246))
            block("LeftEye", 0.37, 0.17, 0.075, 0.055, Color3.fromRGB(58, 30, 78))
            block("RightEye", 0.63, 0.17, 0.075, 0.055, Color3.fromRGB(58, 30, 78))
            block("Smile", 0.5, 0.263, 0.20, 0.025, Color3.fromRGB(58, 30, 78))
            block("Torso", 0.5, 0.37, 0.48, 0.29, body, true)
            block("Badge", 0.5, 0.45, 0.16, 0.07, Color3.fromRGB(255, 255, 255))
            limbs[avatar] = {
                block("LeftArm", 0.17, 0.38, 0.14, 0.30, body, true),
                block("RightArm", 0.83, 0.38, 0.14, 0.30, body, true),
                block("LeftLeg", 0.35, 0.68, 0.19, 0.28, Color3.fromRGB(205, 170, 225)),
                block("RightLeg", 0.65, 0.68, 0.19, 0.28, Color3.fromRGB(205, 170, 225)),
            }
            return avatar
        end
        local target, ghost, mover = figure("target"), figure("ghost"), figure("mover")
        local function poseFigure(avatar, pose, t)
            local parts = limbs[avatar]
            local swing = math.sin(t * 12)
            if pose == "split" then
                parts[1].Rotation, parts[2].Rotation = 58, -58
                parts[3].Rotation, parts[4].Rotation = 64, -64
            elseif pose == "run" then
                parts[1].Rotation, parts[2].Rotation = swing * 48, -swing * 48
                parts[3].Rotation, parts[4].Rotation = -swing * 37, swing * 37
            else
                parts[1].Rotation, parts[2].Rotation = 5 + math.sin(t * 2) * 3, -5 - math.sin(t * 2) * 3
                parts[3].Rotation, parts[4].Rotation = 0, 0
            end
        end
        local trails, streaks = {}, {}
        for i = 1, 5 do
            local dot = create("Frame", {Parent = stage, Size = UDim2.fromOffset(4, 4), AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = ui.AccentColor, BackgroundTransparency = 0.18 + i * 0.15})
            ui:AddToRegistry(dot, {BackgroundColor3 = "AccentColor"})
            trails[i] = dot
        end
        for i = 1, 4 do
            local beam = create("Frame", {Parent = stage, Size = UDim2.new(0.34, 0, 0, 1), Position = UDim2.new(0.33, 0, 0.36 + i * 0.09, 0),
                BackgroundColor3 = ui.AccentColor, BackgroundTransparency = 0.28 + i * 0.13})
            ui:AddToRegistry(beam, {BackgroundColor3 = "AccentColor"})
            streaks[i] = beam
        end

        -- Status rows under the stage: accent key on the left, wrapped value on the right.
        local rowTop = 8 + STAGE_H + 8
        local rows = create("ScrollingFrame", {
            Parent = pane, Position = UDim2.fromOffset(8, rowTop), Size = UDim2.new(1, -16, 1, -rowTop - 6),
            BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            ScrollBarImageColor3 = ui.AccentColor,
        })
        ui:AddToRegistry(rows, {ScrollBarImageColor3 = "AccentColor"})
        create("UIListLayout", {Parent = rows, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5)})
        create("UIPadding", {Parent = rows, PaddingRight = UDim.new(0, 6)})
        local entries, order, status = {}, 0, {Mode = "Idle", GhostHeight = 0}
        function status:Set(key, value)
            local entry = entries[key]
            if not entry then
                order += 1
                local row = create("Frame", {Parent = rows, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 19),
                    AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1})
                create("UIListLayout", {Parent = row, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})
                local name = ui:CreateLabel({Parent = row, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 8), Text = key,
                    TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = ui.AccentColor})
                ui:AddToRegistry(name, {TextColor3 = "AccentColor"})
                entry = ui:CreateLabel({Parent = row, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 8),
                    AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
                    LineHeight = 1.3, Text = ""})
                ui:AddToRegistry(entry, {TextColor3 = "FontColor"})
                entries[key] = entry
            end
            local text = tostring(value)
            if entry.Text ~= text then entry.Text = text end
        end
        function status:SetGhostHeight(value)
            if type(value) == "number" and value == value and value >= 0 and value <= 1e37 then self.GhostHeight = value end
        end
        function status:SetAnimation(mode)
            if type(mode) ~= "string" or mode == "" then mode = "Idle" end
            if self.Mode == mode then return end
            self.Mode, modeText.Text = mode, "ROBOT / " .. string.upper(mode)
        end
        local captions = {
            ["Void TP"] = "TELEPORT / ROBOT RUN", ["Void Hide"] = "VOID / SIDE TO SIDE",
            Orbit = "ORBIT / TRACKED TARGET", Strafe = "STRAFE / SIDE TO SIDE", Jitter = "JITTER / RANDOM OFFSETS",
            ["Random sphere"] = "SPHERE / 3D PATH", Sphere = "SPHERE / 3D PATH", ["Lunar Riot"] = "LUNAR / ROTATION",
            Paused = "PAUSED / NO ACTIVE MOVEMENT",
        }
        -- Positions snap to a 2px grid so the robot moves like pixel art.
        local function snap(value) return math.floor(value / 2 + 0.5) * 2 end
        local function at(x, y) return UDim2.fromOffset(snap(x * STAGE_W), snap(y * STAGE_H)) end
        local clock, accumulated = 0, 0
        ui:_watch(RunService.Heartbeat, function(dt)
            if ui._unloaded or not window.Visible or window.Minimized or not stage.Parent then return end
            if type(dt) ~= "number" or dt ~= dt or dt <= 0 then return end
            accumulated += math.min(dt, 0.1)
            if accumulated < 1 / 30 then return end
            clock += math.min(accumulated, 0.08)
            accumulated = 0
            local mode, t = status.Mode, clock
            if mode == "Hybrid" then mode = math.floor(t / 2.5) % 2 == 0 and "Orbit" or "Void TP" end
            local active = mode ~= "Paused" and mode ~= "Idle"
            local x, y, size, rotation = 0.5, 0.55, 1, 0
            local pose = mode == "Orbit" and "split" or ((mode == "Void TP" or mode == "Void Hide" or mode == "Strafe") and "run" or "idle")
            local streakOn = mode == "Void TP" or mode == "Void Hide" or mode == "Jitter"
            if mode == "Jitter" then
                local step = math.floor(t * 14)
                x, y = 0.5 + 0.23 * math.sin(step * 6.7), 0.55 + 0.16 * math.cos(step * 4.3)
            elseif mode == "Strafe" then x, rotation = 0.5 + 0.30 * math.sin(t * 3), 10 * math.sin(t * 3)
            elseif mode == "Random sphere" or mode == "Sphere" then
                x, y, size = 0.5 + 0.27 * math.cos(t * 2.1), 0.56 + 0.25 * math.sin(t * 3.1), 0.8 + 0.15 * math.sin(t * 2.1)
            elseif mode == "Fake Position" then x, y = 0.5 + 0.14 * math.sin(t * 1.6), 0.64
            elseif mode == "Lunar Riot" then x, rotation = 0.5 + 0.16 * math.sin(t * 3), (t * 220) % 360
            else y = 0.55 + math.sin(t * 2) * 0.015 end
            local stageH, stageW = STAGE_H, STAGE_W
            local availableH = math.max(18, stageH - 45)
            local figureHeight = math.max(12, math.min(availableH * 0.90, 90) * size)
            local figureWidth = math.max(8, math.min(figureHeight * (pose == "split" and 1.02 or 0.62), stageW * 0.55))
            local leftRightRoom = math.max(0, 0.5 - (figureWidth / 2 + 7) / stageW)
            local minY, maxY = (22 + figureHeight / 2) / stageH, (stageH - 18 - figureHeight / 2) / stageH
            local centerY, roomY = (minY + maxY) * 0.5, math.max(0, (maxY - minY) * 0.45)
            if mode == "Orbit" then
                x, y = 0.5 + leftRightRoom * 0.84 * math.cos(t * 2.4), centerY + roomY * 0.9 * math.sin(t * 2.4)
            elseif mode == "Void Hide" then x, y = 0.5 + leftRightRoom * 0.92 * math.sin(t * 3.8), centerY
            elseif mode == "Void TP" then x, y = 0.5 + ((t * 2.8) % 2 < 1 and -1 or 1) * leftRightRoom * 0.88, centerY end
            x, y = math.clamp(x, 0.5 - leftRightRoom, 0.5 + leftRightRoom), math.clamp(y, math.min(minY, maxY), math.max(minY, maxY))
            mover.Position, mover.Size, mover.Rotation = at(x, y), UDim2.fromOffset(snap(figureWidth), snap(figureHeight)), rotation
            local ghostHeight = figureHeight * 0.72
            ghost.Size = UDim2.fromOffset(snap(figureWidth * 0.72), snap(ghostHeight))
            target.Size, target.Position = UDim2.fromOffset(snap(figureWidth * 0.62), snap(figureHeight * 0.62)), at(0.5, centerY)
            target.Visible = active and mode ~= "Fake Position" and mode ~= "Lunar Riot"
            ghost.Visible = mode == "Fake Position" or mode == "Void TP" or mode == "Jitter"
            local ghostY = y
            if mode == "Fake Position" then
                local lift = 0.12 + 0.20 * math.log10(1 + status.GhostHeight) / 37
                local minGhostY = (22 + ghostHeight / 2) / stageH
                local maxGhostY = (stageH - 18 - ghostHeight / 2) / stageH
                ghostY = math.clamp(y - lift, math.min(minGhostY, maxGhostY), math.max(minGhostY, maxGhostY))
            end
            ghost.Position = at(mode == "Fake Position" and x or (x < 0.5 and 0.79 or 0.21), ghostY)
            poseFigure(mover, pose, t)
            poseFigure(ghost, pose, t - 0.12)
            poseFigure(target, "idle", t)
            ring.Visible = mode == "Orbit" or mode == "Random sphere" or mode == "Sphere" or mode == "Lunar Riot"
            ring.Rotation = mode == "Lunar Riot" and (t * 80) % 360 or 0
            for i, dot in ipairs(trails) do
                dot.Visible = active
                if mode == "Orbit" then
                    dot.Position = at(0.5 + leftRightRoom * 0.84 * math.cos((t - i * 0.11) * 2.4), centerY + roomY * 0.9 * math.sin((t - i * 0.11) * 2.4))
                else dot.Position = at(math.clamp(x - i * 0.025, 0.05, 0.95), math.clamp(y + i * 0.012, 0.22, 0.82)) end
            end
            for i, beam in ipairs(streaks) do
                beam.Visible = streakOn
                beam.Size = UDim2.new(0.24 + 0.16 * math.abs(math.sin(t * 8 + i)), 0, 0, 1)
            end
            local text = mode == "Fake Position" and ("LOCAL GHOST / +" .. string.format("%.3g", status.GhostHeight) .. " STUDS") or captions[mode] or "LIVE / MOVEMENT PREVIEW"
            if foot.Text ~= text then foot.Text = text end
        end)
        return status
    end

    function ui:CreateWindow(title)
        local assets = {}
        pcall(function() assets = loadFrekksecAssets() end)
        self.Assets = assets
        if assets.Frost then
            Sakura:SetFrost(assets.Frost)
            assets:FetchFrost()
        end
        local window = Sakura:CreateWindow({
            Title = title,
            Logo = assets.Logo,
            LogoHeight = 22,
            Size = UDim2.fromOffset(1010, 590),
            ToggleKey = Enum.KeyCode.Insert,
            Footer = "frekksec lua  |  F6 helper  |  X fake position  |  End panic",
        })
        Sakura:SetNotifications({Side = "Left", Anchor = "Top"})
        self.Window, self.ScreenGui = window, Sakura:GetScreenGui()
        private.ScreenGui = self.ScreenGui
        private.Cleanup = function() self:Unload() end
        local mark = {text = "", visible = true}
        function mark:SetFields(values)
            local parts = {}
            for index, value in ipairs(values) do parts[index] = tostring(value) end
            self.text = table.concat(parts, " | ")
            if self.visible then Sakura:SetWatermark(self.text) end
        end
        function mark:SetVisible(value)
            self.visible = value == true
            if self.visible and self.text ~= "" then Sakura:SetWatermark(self.text) else Sakura:SetWatermark(false) end
        end
        self.Mark = mark
        self.Side = buildStatus(window)
        self:UpdateColorsUsingRegistry()
        local facade = {Holder = window.Instance, Background = window.Backdrop}
        function facade:AddTab(name)
            local actual = window:AddTab(name)
            local tab = surface(actual)
            function tab:AddSubTab(subName) return surface(actual:AddSubTab(subName)) end
            function tab:SetBuilder(builder) actual:SetBuilder(builder) end
            function tab:ShowTab() window:SelectTab(actual) end
            return tab
        end
        return facade
    end
    return ui
end

