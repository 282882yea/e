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
