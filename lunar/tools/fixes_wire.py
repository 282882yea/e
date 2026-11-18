"""Rebuilt wireframes for Frekks Hail v3: real 3D line wireframes for character, arms and gun."""

WIRE_LUA = r'''        -- Wireframes: real 3D line wireframes (WireframeHandleAdornment) built from each part's
        -- mesh edges. Works for the character, arms and gun and does not depend on the runtime.
        local WIRE_SCOPES = {'Character', 'Arms', 'Item'}
        local WIRE_LABEL = {Character = 'Character', Arms = 'Arms', Item = 'Gun'}
        local WIRE_MAX_LINES = 4000
        local WIRE_DEFAULT_COLOR = Color3.fromRGB(255, 120, 200)
        api.wf = { entries = {}, hidden = {}, cache = {}, pending = {}, root = nil }

        function api:AddWireUi(group)
            for _, scope in ipairs(WIRE_SCOPES) do
                local id = 'FrekksWire' .. scope
                group:AddToggle(id, {Text = WIRE_LABEL[scope] .. ' wireframe', Default = false})
                    :AddColorPicker(id .. 'Color', {Default = WIRE_DEFAULT_COLOR, Title = WIRE_LABEL[scope] .. ' wireframe color'})
                local dep = group:AddDependencyBox()
                dep:AddSlider(id .. 'Thickness', {Text = 'Line thickness', Default = 1.5, Min = 0.5, Max = 6, Rounding = 1})
                dep:AddSlider(id .. 'Crease', {Text = 'Edge detail', Default = 25, Min = 0, Max = 89, Rounding = 0, Suffix = '°',
                    Tooltip = '0 draws every triangle edge; higher keeps only the sharp outline edges.'})
                dep:AddToggle(id .. 'Glow', {Text = 'Glowing lines', Default = true})
                dep:AddToggle(id .. 'Rainbow', {Text = 'Rainbow lines', Default = false})
                if scope ~= 'Character' then
                    dep:AddToggle(id .. 'Hide', {Text = 'Hide solid model', Default = true,
                        Tooltip = 'Only the lines are drawn, like a real wireframe.'})
                end
                dep:SetupDependencies({{T[id], true}})
            end
        end

        local function wireRoot()
            local wf = api.wf
            if wf.root and wf.root.Parent then
                return wf.root
            end
            local folder = Instance.new('Folder')
            folder.Name = 'FrekksHailWireframes'
            local parented = pcall(function()
                folder.Parent = (gethui and gethui()) or game:GetService('CoreGui')
            end)
            if not parented or folder.Parent == nil then
                folder.Parent = workspace.CurrentCamera
            end
            wf.root = folder
            return folder
        end

        local function posKey(v)
            return string.format('%.3f,%.3f,%.3f', v.X, v.Y, v.Z)
        end

        local function readMesh(meshId)
            local mesh
            local previous
            pcall(function() previous = getthreadidentity and getthreadidentity() end)
            pcall(function() if setthreadidentity then setthreadidentity(8) end end)
            pcall(function()
                local ugc = game:GetService('UGCValidationService')
                if cloneref then ugc = cloneref(ugc) end
                local okData, data = pcall(ugc.GetMeshDataBinaryString, ugc, meshId)
                if okData and data then
                    local okMesh, result = pcall(ugc.CreateEditableMeshFromBinaryStringRobloxOnly, ugc, data)
                    if okMesh and result then mesh = result end
                end
            end)
            if not mesh then
                pcall(function()
                    mesh = game:GetService('AssetService'):CreateEditableMeshAsync(Content.fromUri(meshId))
                end)
            end
            if previous then pcall(setthreadidentity, previous) end
            return mesh
        end

        -- every unique edge of the mesh with the normals of the faces on both sides
        local function meshEdges(mesh)
            local faces = {}
            local low = Vector3.new(math.huge, math.huge, math.huge)
            local high = -low
            local counter = 0
            for _, faceId in ipairs(mesh:GetFaces()) do
                local verts = mesh:GetFaceVertices(faceId)
                if #verts >= 3 then
                    local points = {}
                    for i, vertexId in ipairs(verts) do
                        local p = mesh:GetPosition(vertexId)
                        points[i] = p
                        low = low:Min(p)
                        high = high:Max(p)
                    end
                    local normal = (points[2] - points[1]):Cross(points[3] - points[1])
                    if normal.Magnitude > 1e-9 then
                        faces[#faces + 1] = { points = points, normal = normal.Unit }
                    end
                end
                counter += 1
                if counter % 1500 == 0 then task.wait() end
            end
            local byKey, list = {}, {}
            for index, face in ipairs(faces) do
                local count = #face.points
                for i = 1, count do
                    local a, b = face.points[i], face.points[i % count + 1]
                    local ka, kb = posKey(a), posKey(b)
                    local edgeKey = ka < kb and (ka .. '|' .. kb) or (kb .. '|' .. ka)
                    local edge = byKey[edgeKey]
                    if not edge then
                        edge = { a = a, b = b, n1 = face.normal }
                        byKey[edgeKey] = edge
                        list[#list + 1] = edge
                    elseif not edge.n2 then
                        edge.n2 = face.normal
                    end
                end
                if index % 1500 == 0 then task.wait() end
            end
            if #list == 0 then
                return nil
            end
            return { list = list, center = (low + high) / 2, size = high - low }
        end

        local function ring(out, r1, r2, axis, at, segments)
            local function point(angle)
                local c, s = math.cos(angle), math.sin(angle)
                if axis == 'X' then return Vector3.new(at, c * r1, s * r2) end
                if axis == 'Y' then return Vector3.new(c * r1, at, s * r2) end
                return Vector3.new(c * r1, s * r2, at)
            end
            for i = 0, segments - 1 do
                out[#out + 1] = { point(i / segments * math.pi * 2), point((i + 1) / segments * math.pi * 2) }
            end
        end

        -- outline of the part's own shape, used for plain parts or when a mesh cannot be read
        local function shapeLines(part)
            local h = part.Size / 2
            local out = {}
            local shape = part:IsA('Part') and part.Shape or nil
            local special = part:FindFirstChildOfClass('SpecialMesh')
            local meshType = special and special.MeshType or nil
            if shape == Enum.PartType.Ball or meshType == Enum.MeshType.Sphere or meshType == Enum.MeshType.Head then
                ring(out, h.Y, h.Z, 'X', 0, 32); ring(out, h.X, h.Z, 'Y', 0, 32); ring(out, h.X, h.Y, 'Z', 0, 32)
            elseif shape == Enum.PartType.Cylinder or meshType == Enum.MeshType.Cylinder then
                ring(out, h.Y, h.Z, 'X', -h.X, 28); ring(out, h.Y, h.Z, 'X', h.X, 28)
                for k = 0, 3 do
                    local angle = k * math.pi / 2
                    local y, z = math.cos(angle) * h.Y, math.sin(angle) * h.Z
                    out[#out + 1] = { Vector3.new(-h.X, y, z), Vector3.new(h.X, y, z) }
                end
            elseif part:IsA('WedgePart') or meshType == Enum.MeshType.Wedge then
                local p = {
                    Vector3.new(-h.X, -h.Y, -h.Z), Vector3.new(h.X, -h.Y, -h.Z), Vector3.new(-h.X, -h.Y, h.Z),
                    Vector3.new(h.X, -h.Y, h.Z), Vector3.new(-h.X, h.Y, h.Z), Vector3.new(h.X, h.Y, h.Z),
                }
                for _, pair in ipairs({{1, 2}, {3, 4}, {1, 3}, {2, 4}, {5, 6}, {3, 5}, {4, 6}, {1, 5}, {2, 6}}) do
                    out[#out + 1] = { p[pair[1]], p[pair[2]] }
                end
            else
                local corners = {}
                for _, x in ipairs({-1, 1}) do
                    for _, y in ipairs({-1, 1}) do
                        for _, z in ipairs({-1, 1}) do
                            corners[#corners + 1] = Vector3.new(x * h.X, y * h.Y, z * h.Z)
                        end
                    end
                end
                for i = 1, 8 do
                    for j = i + 1, 8 do
                        local d = corners[i] - corners[j]
                        local axes = (math.abs(d.X) > 1e-6 and 1 or 0) + (math.abs(d.Y) > 1e-6 and 1 or 0) + (math.abs(d.Z) > 1e-6 and 1 or 0)
                        if axes == 1 then out[#out + 1] = { corners[i], corners[j] } end
                    end
                end
            end
            return out
        end

        local function meshSource(part)
            if part:IsA('MeshPart') then
                local id = part.MeshId
                if id == '' then
                    pcall(function() id = part.MeshContent.Uri or '' end)
                end
                return id ~= '' and id or nil, nil, nil
            end
            local special = part:FindFirstChildOfClass('SpecialMesh')
            if special and special.MeshType == Enum.MeshType.FileMesh and special.MeshId ~= '' then
                return special.MeshId, special.Scale, special.Offset
            end
            return nil
        end

        local function geometryKey(part, crease)
            local id, scale, offset = meshSource(part)
            return table.concat({ id or part.ClassName, tostring(part.Size), tostring(scale), tostring(offset),
                tostring(part:IsA('Part') and part.Shape or ''), tostring(crease) }, '|')
        end

        local function buildLines(part, crease)
            local wf = api.wf
            local lines
            pcall(function()
                local meshId, scale, offset = meshSource(part)
                if not meshId then return end
                local data = wf.cache[meshId]
                if data == nil then
                    if wf.pending[meshId] then
                        local started = os.clock()
                        repeat task.wait(0.1) until not wf.pending[meshId] or os.clock() - started > 10
                        data = wf.cache[meshId]
                    else
                        wf.pending[meshId] = true
                        local ok, result = pcall(function()
                            local mesh = readMesh(meshId)
                            if not mesh then return false end
                            local edges = meshEdges(mesh)
                            pcall(function() mesh:Destroy() end)
                            return edges or false
                        end)
                        data = ok and result or false
                        wf.cache[meshId] = data
                        wf.pending[meshId] = nil
                    end
                end
                if not data then return end
                local s = scale
                if not s then
                    local ms, ps = data.size, part.Size
                    s = Vector3.new(ms.X > 1e-6 and ps.X / ms.X or 1, ms.Y > 1e-6 and ps.Y / ms.Y or 1, ms.Z > 1e-6 and ps.Z / ms.Z or 1)
                end
                local o = offset or Vector3.zero
                local limit = crease <= 0 and 2 or math.cos(math.rad(crease)) -- 0 = every edge
                local picked = {}
                for _, edge in ipairs(data.list) do
                    local sharpness = edge.n2 and edge.n1:Dot(edge.n2) or -2 -- open edges always count
                    if sharpness < limit then
                        picked[#picked + 1] = { edge, sharpness }
                    end
                end
                if #picked > WIRE_MAX_LINES then
                    table.sort(picked, function(x, y) return x[2] < y[2] end)
                    for i = #picked, WIRE_MAX_LINES + 1, -1 do picked[i] = nil end
                end
                lines = table.create(#picked)
                for i, entry in ipairs(picked) do
                    local edge = entry[1]
                    lines[i] = { (edge.a - data.center) * s + o, (edge.b - data.center) * s + o }
                end
            end)
            if not lines or #lines == 0 then
                local ok, fallback = pcall(shapeLines, part)
                lines = ok and fallback or {}
            end
            return lines
        end

        local function makeAdornment(part, lines, layer)
            local adornment = Instance.new('WireframeHandleAdornment')
            adornment.Name = 'FrekksHailWire' .. layer
            adornment.Adornee = part
            adornment.AlwaysOnTop = false
            adornment.ZIndex = layer == 'Glow' and 0 or 1
            for i, line in ipairs(lines) do
                adornment:AddLine(line[1], line[2])
                if i % 1500 == 0 then task.wait() end
            end
            adornment.Parent = wireRoot()
            return adornment
        end

        local function setHidden(part, hide)
            local wf = api.wf
            if hide then
                wf.hidden[part] = true
                pcall(function() if part.LocalTransparencyModifier < 1 then part.LocalTransparencyModifier = 1 end end)
            elseif wf.hidden[part] then
                wf.hidden[part] = nil
                pcall(function() part.LocalTransparencyModifier = 0 end)
            end
        end

        function api:DropWire(part)
            local wf = self.wf
            local entry = wf.entries[part]
            if entry then
                entry.dead = true
                if entry.main then pcall(function() entry.main:Destroy() end) end
                if entry.glow then pcall(function() entry.glow:Destroy() end) end
                wf.entries[part] = nil
            end
            setHidden(part, false)
        end

        local function wireColor(id)
            if on(id .. 'Rainbow') then
                return Color3.fromHSV((os.clock() * 0.2) % 1, 0.75, 1)
            end
            local color = value(id .. 'Color', WIRE_DEFAULT_COLOR)
            return typeof(color) == 'Color3' and color or WIRE_DEFAULT_COLOR
        end

        function api:SyncWire(part, scope)
            local wf = self.wf
            local id = 'FrekksWire' .. scope
            local crease = num(id .. 'Crease', 25)
            local key = geometryKey(part, crease)
            local entry = wf.entries[part]
            if entry and (entry.key ~= key or entry.scope ~= scope) then
                self:DropWire(part)
                entry = nil
            end
            if not entry then
                entry = { scope = scope, key = key }
                wf.entries[part] = entry
                task.spawn(function()
                    local lines = buildLines(part, crease)
                    if entry.dead or wf.entries[part] ~= entry or #lines == 0 then return end
                    entry.lines = lines
                    entry.main = makeAdornment(part, lines, 'Main')
                    if entry.dead then pcall(function() entry.main:Destroy() end) end
                end)
            end
            local glow = on(id .. 'Glow')
            if entry.main and glow and not entry.glow and entry.lines then
                entry.glow = makeAdornment(part, entry.lines, 'Glow')
            elseif entry.glow and not glow then
                pcall(function() entry.glow:Destroy() end)
                entry.glow = nil
            end
            setHidden(part, scope ~= 'Character' and on(id .. 'Hide'))
        end

        -- per frame: colours, thickness, visibility and keeping hidden models hidden
        function api:RenderWires()
            local wf = self.wf
            for part, entry in pairs(wf.entries) do
                local id = 'FrekksWire' .. entry.scope
                local color = wireColor(id)
                local thickness = num(id .. 'Thickness', 1.5)
                -- the game hides your body in first person: hide its wireframe too
                local visible = part.Parent ~= nil
                if visible and entry.scope == 'Character' then
                    visible = part.LocalTransparencyModifier < 0.99
                end
                local scale = entry.scope == 'Character' and 1.012 or 1
                if entry.main then
                    entry.main.Visible = visible
                    entry.main.Color3 = color
                    entry.main.Thickness = thickness
                    entry.main.Transparency = 0
                    entry.main.Scale = Vector3.one * scale
                end
                if entry.glow then
                    entry.glow.Visible = visible
                    entry.glow.Color3 = color
                    entry.glow.Thickness = thickness * 3.5
                    entry.glow.Transparency = 0.8
                    entry.glow.Scale = Vector3.one * scale
                end
                if wf.hidden[part] and part.LocalTransparencyModifier < 1 then
                    pcall(function() part.LocalTransparencyModifier = 1 end)
                end
            end
        end

        function api:UpdateWires()
            local wf = self.wf
            local anyOn = on('FrekksWireCharacter') or on('FrekksWireArms') or on('FrekksWireItem')
            if not anyOn and next(wf.entries) == nil then return end
            local wanted = {}
            if anyOn then
                local scopes = B.ViewmodelVisuals.ResolveScopes()
                for _, scope in ipairs(WIRE_SCOPES) do
                    if on('FrekksWire' .. scope) then
                        for _, root in ipairs(scopes[scope] or {}) do
                            local parts = root:GetDescendants()
                            if root:IsA('BasePart') then parts[#parts + 1] = root end
                            for _, part in ipairs(parts) do
                                if part:IsA('BasePart') and not wanted[part] and part.Name ~= 'HumanoidRootPart'
                                    and (part.Transparency < 0.99 or wf.hidden[part]) then
                                    wanted[part] = scope
                                end
                            end
                        end
                    end
                end
            end
            for part, scope in pairs(wanted) do
                self:SyncWire(part, scope)
            end
            for part, entry in pairs(wf.entries) do
                if wanted[part] ~= entry.scope or part.Parent == nil then
                    self:DropWire(part)
                end
            end
        end

        function api:DestroyWires()
            for part in pairs(self.wf.entries) do
                self:DropWire(part)
            end
            for part in pairs(self.wf.hidden) do
                setHidden(part, false)
            end
            if self.wf.root then pcall(function() self.wf.root:Destroy() end) end
            self.wf.root = nil
        end

'''

WIRE_LOOP = r'''        local nextWire=0
        watch(run.RenderStepped:Connect(function()
            if not api.alive then return end
            local okRender, renderErr = pcall(function() api:RenderWires() end)
            if not okRender then report(renderErr) end
            if os.clock()<nextWire then return end
            nextWire=os.clock()+0.15
            local ok,err=xpcall(function() api:UpdateWires() end,function(e)return debug.traceback(tostring(e),2) end)
            if not ok then
                -- keep the toggles as they are; just log it and try again on the next pass
                report(err)
            end
        end))
'''


def between(text, start, end, replacement):
    assert text.count(start) == 1, start[:100]
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + replacement + text[b:]


def apply(text):
    text = between(text, "        function api:AddWireUi(group)\n", "        watch(run.Heartbeat:Connect(function(dt)\n", WIRE_LUA)
    text = between(text, "        local nextWire=0\n", "        function api:Destroy()\n", WIRE_LOOP)
    old = "            self.alive=false\n            for _,c in ipairs(self.connections) do c:Disconnect() end\n"
    assert text.count(old) == 1
    text = text.replace(old, "            self.alive=false\n            pcall(function() self:DestroyWires() end)\n            for _,c in ipairs(self.connections) do c:Disconnect() end\n")
    return text
