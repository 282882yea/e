"""Small edits to the script's own code that go with the Lunar port (exact-text replacements)."""

ESP_SCENE_NEW = r'''                    -- soft ground ring
                    for i = 1, 26 do
                        local a, b = (i - 1) * math.pi / 13, i * math.pi / 13
                        pinkDraw(i, Vector3.new(center.X + math.cos(a) * radius, floor, center.Z + math.sin(a) * radius),
                            Vector3.new(center.X + math.cos(b) * radius, floor, center.Z + math.sin(b) * radius), 0.42 + math.sin(t * 2) * 0.1, 0.6)
                    end
                    -- Electricity crawls over the body itself: short arcs wrap around the
                    -- torso, head and legs, crackle for a moment, then jump somewhere else.
                    local half = EspPreviewOrbit.ModelSize * 0.5
                    local cameraPosition = viewport.Camera.CFrame.Position
                    local frame = math.floor(t * 22)
                    local function surface(theta, y, push)
                        local taper = y > 0.62 and 0.42 or (y < -0.12 and 0.6 or 1)
                        local rx = (half.X * taper + 0.12) * push
                        local rz = (math.max(half.Z, 0.6) + 0.18) * push
                        return Vector3.new(center.X + math.cos(theta) * rx, center.Y + y * half.Y, center.Z + math.sin(theta) * rz)
                    end
                    local function facing(a, b, base)
                        -- arcs on the far side of the body are dimmed so they read as behind it
                        local mid = (a + b) * 0.5
                        return (mid - center):Dot(cameraPosition - center) < 0 and base * 0.22 or base
                    end
                    local rng = pinkScene.Random
                    for slot = 1, 10 do
                        local arc = pinkScene.Arcs[slot]
                        if not arc or t >= arc.Die then
                            local y0 = rng:NextNumber(-0.92, 0.92)
                            arc = {
                                Theta = rng:NextNumber(0, math.pi * 2), Y = y0,
                                Sweep = rng:NextNumber(0.5, 1.5) * (rng:NextNumber() < 0.5 and -1 or 1),
                                Rise = math.clamp(y0 + rng:NextNumber(-0.5, 0.5), -0.98, 0.98) - y0,
                                Born = t, Die = t + rng:NextNumber(0.1, 0.34),
                                Seed = rng:NextNumber(0, 1000), Branch = rng:NextNumber() < 0.5,
                            }
                            pinkScene.Arcs[slot] = arc
                        end
                        local life = (t - arc.Born) / (arc.Die - arc.Born)
                        local flicker = (0.55 + 0.45 * math.abs(math.noise(arc.Seed, frame * 0.9))) * (1 - life * life * 0.7)
                        local last, forkPoint, forkTheta, forkY
                        for point = 0, 6 do
                            local q = point / 6
                            local wobble = (point == 0 or point == 6) and 0 or 1
                            local theta = arc.Theta + arc.Sweep * q + math.noise(arc.Seed + point * 7.3, frame * 0.7) * 0.34 * wobble
                            local y = math.clamp(arc.Y + arc.Rise * q + math.noise(arc.Seed + point * 3.1 + 40, frame * 0.7) * 0.16 * wobble, -1, 1)
                            local p = surface(theta, y, 1 + math.sin(q * math.pi) * 0.07
                                + math.abs(math.noise(arc.Seed + point, frame * 0.5 + 9)) * 0.1 * wobble)
                            if last then pinkDraw(26 + (slot - 1) * 6 + point, last, p, facing(last, p, flicker), 0.75) end
                            if point == 3 then forkPoint, forkTheta, forkY = p, theta, y end
                            last = p
                        end
                        if slot <= 5 then
                            -- a short fork that leaps off the body
                            local index = 86 + (slot - 1) * 2
                            if arc.Branch and forkPoint then
                                local mid = surface(forkTheta + 0.12, math.clamp(forkY + 0.1, -1, 1), 1.22 + math.noise(arc.Seed, frame) * 0.08)
                                local tip = surface(forkTheta + 0.2 + math.noise(arc.Seed + 5, frame) * 0.2, math.clamp(forkY + 0.2, -1, 1), 1.42)
                                pinkDraw(index + 1, forkPoint, mid, facing(forkPoint, mid, flicker * 0.8), 0.6)
                                pinkDraw(index + 2, mid, tip, facing(mid, tip, flicker * 0.6), 0.5)
                            else
                                pinkHide(index + 1)
                                pinkHide(index + 2)
                            end
                        end
                    end
'''

HALO = r'''                backgroundCorner.Parent = backgroundFrame

                -- soft pink glow behind the character
                pcall(function()
                    local halo = Instance.new('Frame')
                    halo.Name = 'EspPreviewHalo'
                    halo.AnchorPoint = Vector2.new(0.5, 0.5)
                    halo.Position = UDim2.fromScale(0.5, 0.52)
                    halo.Size = UDim2.fromOffset(90, 190)
                    halo.BackgroundColor3 = Color3.fromRGB(255, 96, 170)
                    halo.BackgroundTransparency = 0.9
                    halo.BorderSizePixel = 0
                    halo.ZIndex = 0
                    local haloCorner = Instance.new('UICorner')
                    haloCorner.CornerRadius = UDim.new(1, 0)
                    haloCorner.Parent = halo
                    local haloGlow = Instance.new('UIShadow')
                    haloGlow.Color = Color3.fromRGB(255, 96, 170)
                    haloGlow.BlurRadius = UDim.new(0, 70)
                    haloGlow.Transparency = 0.5
                    pcall(function() haloGlow.Spread = UDim2.fromOffset(18, 18) end)
                    pcall(function() haloGlow.Offset = UDim2.fromOffset(0, 0) end)
                    haloGlow.Parent = halo
                    halo.Parent = backgroundFrame
                end)
'''


def between(text, start, end, replacement):
    a = text.index(start)
    b = text.index(end, a)
    assert text.count(start) == 1, start
    return text[:a] + replacement + text[b:]


def swap(text, old, new):
    assert text.count(old) == 1, (text.count(old), old)
    return text.replace(old, new)


def apply(text):
    # ESP preview: electricity on the body instead of orbiting pillars
    text = between(text,
        "                    for i = 1, 48 do\n                        local a, b = (i - 1) * math.pi / 24",
        "                    local size = backgroundFrame.AbsoluteSize\n                    for _, item in next, pinkScene.Grid do",
        ESP_SCENE_NEW)
    text = swap(text, "local pinkScene = {Time = 0, Accumulator = 0, Segments = {}, Grid = {}}",
        "local pinkScene = {Time = 0, Accumulator = 0, Segments = {}, Grid = {}, Arcs = {}, Random = Random.new()}")
    text = swap(text, "                local function pinkDraw(index, a, b, strength)\n",
        "                local function pinkHide(index)\n"
        "                    for _, line in ipairs(pinkScene.Segments[index]) do line.Visible = false end\n"
        "                end\n"
        "                local function pinkDraw(index, a, b, strength, scale)\n")
    text = swap(text, "line.Size = UDim2.fromOffset(delta.Magnitude + 1, i == 1 and 10 or i == 2 and 4 or 1.3)",
        "line.Size = UDim2.fromOffset(delta.Magnitude + 1, (i == 1 and 10 or i == 2 and 4 or 1.3) * (scale or 1))")
    # ESP preview: nicer backdrop
    text = swap(text, "backgroundGradient.Color = ColorSequence.new(Color3.fromRGB(42, 28, 40), Color3.fromRGB(20, 15, 23))",
        "backgroundGradient.Color = ColorSequence.new({\n"
        "                    ColorSequenceKeypoint.new(0, Color3.fromRGB(64, 34, 60)),\n"
        "                    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 16, 34)),\n"
        "                    ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 8, 17)),\n"
        "                })")
    text = swap(text, "                backgroundCorner.CornerRadius = UDim.new(0, 6)\n                backgroundCorner.Parent = backgroundFrame\n",
        "                backgroundCorner.CornerRadius = UDim.new(0, 12)\n" + HALO)
    text = swap(text, "                viewportCorner.CornerRadius = UDim.new(0, 6)\n", "                viewportCorner.CornerRadius = UDim.new(0, 12)\n")
    text = swap(text, "                        line.BackgroundTransparency = 0.94\n                        line.ZIndex = 0\n                        line.Parent = backgroundFrame",
        "                        line.BackgroundTransparency = 0.955\n                        line.ZIndex = 0\n                        line.Parent = backgroundFrame")
    return text


# --- Tracking curve: shapes the aim path, free points, nicer editor ---------------

CURVE_DATA_NEW = r'''        local CURVE_MIN, CURVE_MAX = -0.5, 1.5
        function api:CurveData()
            local option = O.FrekksTrackingCurve
            local encoded = option and option.Value or ''
            if encoded ~= self.curveEncoded then
                self.curveEncoded = encoded
                local ok, saved = pcall(http.JSONDecode,http,encoded)
                local points = {}
                for i=1,8 do
                    local y = ok and type(saved)=='table' and tonumber(saved[i]) or nil
                    if not y or y~=y or math.abs(y)==math.huge then y=(i-1)/7 end
                    points[i]=math.clamp(y,CURVE_MIN,CURVE_MAX)
                end
                points[1],points[8]=0,1
                self.curve=points
            end
            return self.curve
        end
        -- Catmull-Rom through the 8 points: free shapes, overshoot allowed.
        function api:Curve(t)
            local p = self:CurveData()
            t=math.clamp(tonumber(t) or 0,0,1)
            local i=math.clamp(math.floor(t*7)+1,1,7)
            local u=t*7-(i-1)
            local p0,p1,p2,p3=p[math.max(i-1,1)],p[i],p[i+1],p[math.min(i+2,8)]
            local u2,u3=u*u,u*u*u
            return 0.5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u2+(-p0+3*p1-3*p2+p3)*u3)
        end
'''

AIM_CURVE_NEW = r'''            local now = os.clock()
            if self.aimPart ~= part or now-(self.aimLast or 0) > 0.3 then
                self.aimPart, self.aimStart, self.curveFrom = part, now, nil
            end
            self.aimLast = now
            local speed = num('FrekksTracking'..mode..'Speed',mode=='Spring' and 1 or 0.1) * num('P2S2S1',35)/35
            local duration = math.max(num('FrekksTrackingCurveTime',0.5),0.01)
            local t = math.clamp((now-(self.aimStart or now))/duration,0,1)
            local screen = camera:WorldToViewportPoint(point)
            if screen.Z <= 0 then return true end
            local target = Vector2.new(screen.X,screen.Y)
            if on('FrekksTrackingUseCurve') and t < 1 then
                -- The curve is the path: at time t the aim sits (1 - curve) of the
                -- starting offset away from the target (overshoot when curve > 1).
                local rotation = controller.Rotation
                local direction = CFrame.fromOrientation(rotation.X,rotation.Y,0).LookVector
                local aimed = camera:WorldToViewportPoint(camera.CFrame.Position+direction*1000)
                local current = Vector2.new(aimed.X,aimed.Y)
                if not self.curveFrom then self.curveFrom = current-target end
                local desired = target+self.curveFrom*(1-self:Curve(t))
                local move = desired-current
                local scale = math.rad(camera.FieldOfView)/math.max(camera.ViewportSize.Y,1)
                controller:SetRotation(Vector2.new(rotation.X-move.Y*scale,rotation.Y-move.X*scale))
                return true
            end
            self.aim:Apply(target,math.max(dt,0.0001),{Type=mode,Speed=speed},true)
            return true
        end
'''

EDITOR_NEW = r'''            local chart = curve:AddLabel('')
            chart.Container.Size = UDim2.new(1,0,0,214)
            chart.Label.Visible = false
            local pink, soft, ink = Color3.fromRGB(255,126,182), Color3.fromRGB(255,190,222), Color3.fromRGB(20,10,24)
            local panel = Instance.new('Frame')
            panel.Position, panel.Size = UDim2.fromOffset(8,6), UDim2.new(1,-16,1,-12)
            panel.BackgroundColor3, panel.BorderSizePixel, panel.ClipsDescendants = Color3.new(1,1,1), 0, false
            panel.Parent = chart.Container
            local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0,12); corner.Parent = panel
            local fill = Instance.new('UIGradient'); fill.Rotation = 90
            fill.Color = ColorSequence.new(Color3.fromRGB(46,24,46),Color3.fromRGB(18,10,22)); fill.Parent = panel
            local border = Instance.new('UIStroke'); border.Color, border.Transparency = Color3.fromRGB(110,70,104), 0.1; border.Parent = panel
            local plot = Instance.new('Frame')
            plot.Position, plot.Size, plot.BackgroundTransparency = UDim2.fromOffset(44,14), UDim2.new(1,-58,1,-38), 1
            plot.Parent = panel
            local function label(text, y, color)
                local l = Instance.new('TextLabel')
                l.AnchorPoint, l.Position, l.Size = Vector2.new(1,0.5), UDim2.new(0,-8,y,0), UDim2.fromOffset(40,14)
                l.BackgroundTransparency, l.Text, l.TextSize, l.Font = 1, text, 11, Enum.Font.GothamMedium
                l.TextXAlignment, l.TextColor3 = Enum.TextXAlignment.Right, color
                l.Parent = plot
                return l
            end
            local function toY(v) return 1-(v-CURVE_MIN)/(CURVE_MAX-CURVE_MIN) end
            local function rule(y, color, alpha, thick)
                local g = Instance.new('Frame')
                g.Position, g.Size, g.BorderSizePixel = UDim2.fromScale(0,y), UDim2.new(1,0,0,thick or 1), 0
                g.BackgroundColor3, g.BackgroundTransparency = color, alpha
                g.Parent = plot
            end
            for i=1,7 do
                local g = Instance.new('Frame')
                g.Position, g.Size, g.BorderSizePixel = UDim2.fromScale(i/7,0), UDim2.new(0,1,1,0), 0
                g.BackgroundColor3, g.BackgroundTransparency = Color3.fromRGB(120,80,120), 0.86
                g.Parent = plot
            end
            for _, v in ipairs({-0.5,0.5,1.5}) do rule(toY(v), Color3.fromRGB(120,80,120), 0.86) end
            rule(toY(1), pink, 0.35, 1)
            rule(toY(0), soft, 0.65, 1)
            label('Target', toY(1), pink); label('Start', toY(0), soft)
            label('Over', toY(1.5), Color3.fromRGB(170,130,165)); label('Away', toY(-0.5), Color3.fromRGB(170,130,165))
            local axis = Instance.new('TextLabel')
            axis.AnchorPoint, axis.Position, axis.Size = Vector2.new(0.5,0), UDim2.new(0.5,0,1,4), UDim2.new(1,0,0,14)
            axis.BackgroundTransparency, axis.Text, axis.TextSize, axis.Font = 1, 'time  →', 11, Enum.Font.GothamMedium
            axis.TextColor3 = Color3.fromRGB(170,130,165)
            axis.Parent = plot
            local lines, glowLines, dots = {}, {}, {}
            local sampleCount=96
            for i=1,sampleCount do
                for layer=1,2 do
                    local line=Instance.new('Frame')
                    line.AnchorPoint,line.BorderSizePixel=Vector2.new(0.5,0.5),0
                    line.BackgroundColor3=layer==1 and pink or soft
                    line.BackgroundTransparency=layer==1 and 0.72 or 0
                    line.ZIndex=layer==1 and 2 or 3
                    local cap=Instance.new('UICorner'); cap.CornerRadius,cap.Parent=UDim.new(1,0),line
                    line.Parent=plot
                    if layer==1 then glowLines[i]=line else lines[i]=line end
                end
            end
            for i=1,8 do
                local dot = Instance.new('TextButton')
                dot.Name, dot.Text, dot.AutoButtonColor = 'Point'..i, '', false
                dot.AnchorPoint, dot.BorderSizePixel, dot.ZIndex = Vector2.new(0.5,0.5), 0, 5
                local fixed = i==1 or i==8
                dot.Size = fixed and UDim2.fromOffset(9,9) or UDim2.fromOffset(13,13)
                dot.BackgroundColor3 = fixed and soft or ink
                local c = Instance.new('UICorner'); c.CornerRadius, c.Parent = UDim.new(1,0), dot
                local s = Instance.new('UIStroke'); s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Color, s.Thickness = pink, fixed and 1 or 2; s.Parent = dot
                dot.Parent, dots[i] = plot, dot
                watch(dot.MouseEnter:Connect(function() if not fixed then s.Color = soft; dot.Size = UDim2.fromOffset(16,16) end end))
                watch(dot.MouseLeave:Connect(function() if not fixed then s.Color = pink; dot.Size = UDim2.fromOffset(13,13) end end))
                watch(dot.InputBegan:Connect(function(evt)
                    if fixed then return end
                    if evt.UserInputType==Enum.UserInputType.MouseButton1 or evt.UserInputType==Enum.UserInputType.Touch then self.drag={index=i,input=evt} end
                end))
            end
            local function redraw()
                local size = plot.AbsoluteSize
                if size.X < 2 or size.Y < 2 then return end
                local scale = 1
                local root = plot
                while root and not root:IsA('ScreenGui') do
                    local u = root:FindFirstChildOfClass('UIScale')
                    if u then scale = scale*u.Scale end
                    root = root.Parent
                end
                size = size/scale
                local pts = self:CurveData()
                for i=1,8 do
                    dots[i].Position = UDim2.fromOffset((i-1)/7*size.X, toY(pts[i])*size.Y)
                end
                local a=Vector2.new(0,toY(self:Curve(0))*size.Y)
                for i=1,sampleCount do
                    local t=i/sampleCount
                    local b=Vector2.new(t*size.X,toY(self:Curve(t))*size.Y)
                    local d,middle=b-a,(a+b)*0.5
                    local rot=math.deg(math.atan2(d.Y,d.X))
                    lines[i].Position,lines[i].Size,lines[i].Rotation=UDim2.fromOffset(middle.X,middle.Y),UDim2.fromOffset(d.Magnitude+1.5,2.5),rot
                    glowLines[i].Position,glowLines[i].Size,glowLines[i].Rotation=UDim2.fromOffset(middle.X,middle.Y),UDim2.fromOffset(d.Magnitude+4,8),rot
                    a=b
                end
            end
            encoded:OnChanged(redraw)
            watch(plot:GetPropertyChangedSignal('AbsoluteSize'):Connect(redraw))
            watch(input.InputChanged:Connect(function(evt)
                local drag = self.drag
                if not drag then return end
                if value('FrekksTrackingMode','Linear')=='Lock' or L.Unloaded or L.Toggled==false then self.drag=nil; return end
                if evt.UserInputType ~= Enum.UserInputType.MouseMovement and evt ~= drag.input then return end
                local y = (evt.Position.Y-plot.AbsolutePosition.Y)/math.max(plot.AbsoluteSize.Y,1)
                local points = table.clone(self:CurveData())
                points[drag.index]=math.clamp(CURVE_MIN+(1-y)*(CURVE_MAX-CURVE_MIN),CURVE_MIN,CURVE_MAX)
                encoded:SetValue(http:JSONEncode(points),true)
                redraw()
                if O.FrekksTrackingCurvePreset then O.FrekksTrackingCurvePreset:SetValue('Custom',true) end
            end))
            watch(input.InputEnded:Connect(function(evt)
                if evt.UserInputType==Enum.UserInputType.MouseButton1 or self.drag and evt==self.drag.input then self.drag=nil end
            end))
            curve:AddLabel('Drag the points: the line is where the aim is over time, from your crosshair (Start) to the target. Above Target overshoots, below Start pulls away first.',true)
            curve:AddDropdown('FrekksTrackingCurvePreset',{Text='Curve preset',Values={'Linear','Ease In','Ease Out','Smooth Step','Overshoot','Wind Up','Custom'},Default='Linear',NoSave=true,Callback=function(preset)
                if preset=='Custom' then return end
                local p={}
                for i=1,8 do
                    local t=(i-1)/7
                    p[i]=preset=='Ease In' and t*t or preset=='Ease Out' and 1-(1-t)^2 or preset=='Smooth Step' and t*t*(3-2*t)
                        or preset=='Overshoot' and 1+2.70158*(t-1)^3+1.70158*(t-1)^2
                        or preset=='Wind Up' and 2.70158*t^3-1.70158*t^2 or t
                end
                encoded:SetValue(http:JSONEncode(p))
            end})
'''


def apply_curve(text):
    text = between(text, "        function api:CurveData()\n", "        function api:Aim(controller, camera, point, dt, part)\n", CURVE_DATA_NEW)
    text = between(text, "            if self.aimPart ~= part then self.aimPart, self.aimStart = part, os.clock() end\n",
        "        function api:AddSilentUi(group)\n", AIM_CURVE_NEW)
    text = between(text, "            local chart = curve:AddLabel('')\n", "            curve:SetupDependencies({{O.FrekksTrackingMode,function(v)return v~='Lock' end}})\n", EDITOR_NEW)
    return text


_apply_base = apply


def apply(text):  # noqa: F811
    return apply_curve(_apply_base(text))
