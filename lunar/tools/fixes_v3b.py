"""Chams + animation player fixes for Frekks Hail v3 (applied after patch_v3.visuals)."""


def swap(text, old, new, count=1):
    assert text.count(old) == count, (text.count(old), old[:160])
    return text.replace(old, new)


def viewmodel_chams(text):
    # 1) Find arms / gun anywhere inside the first-person viewmodel, not only as direct
    #    children with fixed names, and include the player's Live rig for character chams.
    text = swap(text,
        """                local viewModels = Workspace:FindFirstChild('ViewModels')
                local firstPerson = viewModels and viewModels:FindFirstChild('FirstPerson') or nil
                for _, model in ipairs(firstPerson and firstPerson:GetChildren() or {}) do
                    if model:IsA('Model') then
                        visuals.AppendUniqueRoot(scopes.Item, seen.Item, model:FindFirstChild('ItemVisual'))
                        visuals.AppendUniqueRoot(scopes.Arms, seen.Arms, model:FindFirstChild('LeftArm'))
                        visuals.AppendUniqueRoot(scopes.Arms, seen.Arms, model:FindFirstChild('RightArm'))
                    end
                end
                return scopes""",
        """                local live = Workspace:FindFirstChild('Live')
                local liveRig = live and live:FindFirstChild(LP.Name) or nil
                if liveRig and liveRig:IsA('Model') then
                    visuals.AppendUniqueRoot(scopes.Character, seen.Character, liveRig)
                end

                local function isArmName(name)
                    local lower = string.lower(name)
                    if lower:find('charm', 1, true) then
                        return false
                    end
                    return lower:find('arm', 1, true) ~= nil or lower:find('hand', 1, true) ~= nil
                        or lower:find('glove', 1, true) ~= nil or lower:find('sleeve', 1, true) ~= nil
                end
                local viewModels = Workspace:FindFirstChild('ViewModels')
                local firstPerson = viewModels and viewModels:FindFirstChild('FirstPerson') or nil
                for _, model in ipairs(firstPerson and firstPerson:GetChildren() or {}) do
                    if model:IsA('Model') then
                        -- search the whole viewmodel: these can sit one or more levels down
                        local item = model:FindFirstChild('ItemVisual', true)
                        local left = model:FindFirstChild('LeftArm', true)
                        local right = model:FindFirstChild('RightArm', true)
                        visuals.AppendUniqueRoot(scopes.Item, seen.Item, item)
                        visuals.AppendUniqueRoot(scopes.Arms, seen.Arms, left)
                        visuals.AppendUniqueRoot(scopes.Arms, seen.Arms, right)
                        if not item or not (left or right) then
                            -- unknown layout: split the viewmodel's children by name
                            for _, child in ipairs(model:GetChildren()) do
                                if child ~= item and child ~= left and child ~= right
                                    and (child:IsA('BasePart') or child:IsA('Model') or child:IsA('Folder')) then
                                    if isArmName(child.Name) then
                                        if not (left or right) then
                                            visuals.AppendUniqueRoot(scopes.Arms, seen.Arms, child)
                                        end
                                    elseif not item then
                                        visuals.AppendUniqueRoot(scopes.Item, seen.Item, child)
                                    end
                                end
                            end
                        end
                    end
                end
                return scopes""")

    # 2) Remember the wanted look per part and re-apply it every frame (late in the
    #    frame), so the game's wrap / skin system can no longer paint over the chams.
    #    Follows the game's own visibility changes (reload, inspect) instead of
    #    forcing hidden parts visible.
    text = swap(text,
        """                    for _, descendant in ipairs(descendants) do
                        if descendant:IsA('BasePart') then
                            local snapshot = visuals.CaptureAppearance(descendant)
                            activeParts[descendant] = true
                            pcall(function() LPH_ATTRIBUTES(VM(NONE)); 
                                descendant.Material = material or snapshot.Material
                                descendant.Color = color
                                descendant.Transparency = snapshot.Transparency < 1 and transparency or snapshot.Transparency
                            end)
                        end
                    end""",
        """                    for _, descendant in ipairs(descendants) do
                        if descendant:IsA('BasePart') and not activeParts[descendant] then
                            local snapshot = visuals.CaptureAppearance(descendant)
                            activeParts[descendant] = true
                            local target = visuals.ChamTargets[descendant]
                            if not target then
                                target = {}
                                visuals.ChamTargets[descendant] = target
                            end
                            target.Material = material or snapshot.Material
                            target.Color = color
                            target.Transparency = transparency
                            visuals.EnforceCham(descendant, target)
                        end
                    end""")
    text = swap(text,
        """            function RivalsRuntimeBridge.ViewmodelVisuals.ApplyChamScope(roots, optionPrefix, activeParts, activeTextures) LPH_ATTRIBUTES(VM(NONE)); """,
        """            local function colorsDiffer(a, b)
                return math.abs(a.R - b.R) > 0.004 or math.abs(a.G - b.G) > 0.004 or math.abs(a.B - b.B) > 0.004
            end

            function RivalsRuntimeBridge.ViewmodelVisuals.EnforceCham(part, target)
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                pcall(function()
                    if part.Parent == nil then
                        return
                    end
                    if part.Material ~= target.Material then
                        part.Material = target.Material
                    end
                    if colorsDiffer(part.Color, target.Color) then
                        part.Color = target.Color
                    end
                    local snapshot = visuals.AppearanceSnapshots[part]
                    if snapshot and target.LastSet ~= nil and math.abs(part.Transparency - target.LastSet) > 0.001 then
                        -- the game changed this part's visibility itself (reload, inspect, hide): follow it
                        snapshot.Transparency = part.Transparency
                    end
                    local want = (snapshot and snapshot.Transparency >= 1) and snapshot.Transparency or target.Transparency
                    if math.abs(part.Transparency - want) > 0.001 then
                        part.Transparency = want
                    end
                    target.LastSet = part.Transparency
                end)
            end

            function RivalsRuntimeBridge.ViewmodelVisuals.EnforceAll()
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                for part, target in pairs(visuals.ChamTargets) do
                    visuals.EnforceCham(part, target)
                end
            end

            function RivalsRuntimeBridge.ViewmodelVisuals.AnyChamsOn()
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                return visuals.ReadToggle('P1S19T1') or visuals.ReadToggle('P1S20T1') or visuals.ReadToggle('P1S21T1')
            end

            function RivalsRuntimeBridge.ViewmodelVisuals.ApplyChamScope(roots, optionPrefix, activeParts, activeTextures) LPH_ATTRIBUTES(VM(NONE)); """)
    text = swap(text,
        """                AppearanceSnapshots = setmetatable({}, { __mode = 'k' }),
                TextureSnapshots = {},
                Highlights = {},""",
        """                AppearanceSnapshots = setmetatable({}, { __mode = 'k' }),
                ChamTargets = setmetatable({}, { __mode = 'k' }),
                EnforceBound = false,
                TextureSnapshots = {},
                Highlights = {},""")
    # forget parts that are no longer chammed
    text = swap(text,
        """                for part, snapshot in pairs(visuals.AppearanceSnapshots) do
                    if not activeParts[part] then
                        visuals.RestoreAppearance(part, snapshot)
                        visuals.AppearanceSnapshots[part] = nil
                    end
                end""",
        """                for part in pairs(visuals.ChamTargets) do
                    if not activeParts[part] then
                        visuals.ChamTargets[part] = nil
                    end
                end
                for part, snapshot in pairs(visuals.AppearanceSnapshots) do
                    if not activeParts[part] then
                        visuals.RestoreAppearance(part, snapshot)
                        visuals.AppearanceSnapshots[part] = nil
                    end
                end""")
    # faster reconcile while chams are on, plus a late render-step enforcer
    text = swap(text,
        """            function RivalsRuntimeBridge.ViewmodelVisuals.Update(deltaTime) LPH_ATTRIBUTES(VM(NONE)); 
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                if tick() - visuals.LastReconcileAt >= 0.25 then""",
        """            function RivalsRuntimeBridge.ViewmodelVisuals.Update(deltaTime) LPH_ATTRIBUTES(VM(NONE)); 
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                local chamsOn = visuals.AnyChamsOn()
                if chamsOn and not visuals.EnforceBound then
                    visuals.EnforceBound = true
                    pcall(function()
                        game:GetService('RunService'):BindToRenderStep('FrekksHailChamsEnforce', Enum.RenderPriority.Last.Value + 100, function()
                            pcall(visuals.EnforceAll)
                        end)
                    end)
                elseif not chamsOn and visuals.EnforceBound then
                    visuals.EnforceBound = false
                    pcall(function() game:GetService('RunService'):UnbindFromRenderStep('FrekksHailChamsEnforce') end)
                end
                if tick() - visuals.LastReconcileAt >= (chamsOn and 0.1 or 0.25) then""")
    text = swap(text,
        """            function RivalsRuntimeBridge.ViewmodelVisuals.Destroy()
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                visuals.RestoreNativeCrosshairs()""",
        """            function RivalsRuntimeBridge.ViewmodelVisuals.Destroy()
                local visuals = RivalsRuntimeBridge.ViewmodelVisuals
                if visuals.EnforceBound then
                    visuals.EnforceBound = false
                    pcall(function() game:GetService('RunService'):UnbindFromRenderStep('FrekksHailChamsEnforce') end)
                end
                visuals.ChamTargets = setmetatable({}, { __mode = 'k' })
                visuals.RestoreNativeCrosshairs()""")
    return text


def feedback_chams(text):
    # Hit / kill chams: clone non-archivable parts properly, sit slightly outside the
    # body (no z-fighting), and keep fading when the body is removed instead of vanishing.
    text = swap(text,
        """                        local ok, ghost = pcall(function()
                            return part:Clone()
                        end)""",
        """                        local ok, ghost = pcall(function()
                            local archivable = part.Archivable
                            part.Archivable = true
                            local copy = part:Clone()
                            part.Archivable = archivable
                            return copy
                        end)""")
    text = swap(text,
        """                        ghost.CFrame = part.CFrame
                        pcall(function()
                            ghost.MaterialVariant = ''
                        end)""",
        """                        ghost.CFrame = part.CFrame
                        pcall(function()
                            ghost.Size = part.Size * 1.04
                            for _, mesh in ipairs(ghost:GetDescendants()) do
                                if mesh:IsA('SpecialMesh') then mesh.Scale = mesh.Scale * 1.04 end
                            end
                        end)
                        pcall(function()
                            ghost.MaterialVariant = ''
                        end)""")
    text = swap(text,
        """                            if pair.Source and pair.Source.Parent and pair.Ghost and pair.Ghost.Parent then
                                pair.Ghost.CFrame = pair.Source.CFrame
                                pair.Ghost.Transparency = cham.Transparency + (1 - cham.Transparency) * progress
                            else
                                if pair.Ghost then
                                    pair.Ghost:Destroy()
                                end
                                table.remove(cham.Parts, partIndex)
                            end""",
        """                            if pair.Ghost and pair.Ghost.Parent then
                                if pair.Source and pair.Source.Parent then
                                    pair.Ghost.CFrame = pair.Source.CFrame
                                end
                                -- body removed (kill, ragdoll, despawn): the ghost stays where it was and fades out
                                pair.Ghost.Transparency = cham.Transparency + (1 - cham.Transparency) * progress
                            else
                                table.remove(cham.Parts, partIndex)
                            end""")
    # kills: fall back to the last character we hit when the eliminated one no longer resolves
    text = swap(text,
        """                feedback.ShowMessage('Hit', character, damage)""",
        """                feedback.LastHitCharacter = character
                feedback.LastHitAt = tick()
                feedback.ShowMessage('Hit', character, damage)""")
    text = swap(text,
        """                if feedback.ReadToggle('P1S16T3') then
                    local colorOption = Options and Options.P1S16C1""",
        """                if feedback.ReadToggle('P1S16T3') then
                    if (typeof(character) ~= 'Instance' or character.Parent == nil)
                        and feedback.LastHitCharacter and tick() - (feedback.LastHitAt or 0) < 3 then
                        character = feedback.LastHitCharacter
                    end
                    local colorOption = Options and Options.P1S16C1""")
    return text


def animation_player(text):
    text = swap(text,
        """    local animLanes = {}
    local disabledAnimate = {}""",
        """    local animLanes = {}
    local attemptedRigs = setmetatable({}, { __mode = 'k' })
    local disabledAnimate = {}""")
    text = swap(text,
        """        stripAnimateOnRig(char)

        local clientLane = buildLane(char, animPrimary, animJitter, doJitter, speed, looped)""",
        """        stripAnimateOnRig(char)

        attemptedRigs = setmetatable({ [char] = true }, { __mode = 'k' })
        local clientLane = buildLane(char, animPrimary, animJitter, doJitter, speed, looped)""")
    text = swap(text,
        """                if rig == char then continue end
                local lane = buildLane(rig, animPrimary, animJitter, doJitter, speed, looped)""",
        """                if rig == char then continue end
                attemptedRigs[rig] = true
                local lane = buildLane(rig, animPrimary, animJitter, doJitter, speed, looped)""")
    # cache downloaded animations so a rebuild does not re-download every time
    text = swap(text,
        """    local function deepDiveGetAnimObject(bundleId)
        bundleId = normalizeAnimId(bundleId)
        if bundleId == "" then return nil end
""",
        """    local animTemplates = {}
    local fetchAnimObject
    local function deepDiveGetAnimObject(bundleId)
        bundleId = normalizeAnimId(bundleId)
        if bundleId == "" then return nil end
        local template = animTemplates[bundleId]
        if not template then
            template = fetchAnimObject(bundleId)
            if not template then return nil end
            animTemplates[bundleId] = template
        end
        return template:Clone()
    end
    fetchAnimObject = function(bundleId)
""")
    # 'loop' off now really plays once
    text = swap(text,
        """    local function ironLockLane(lane, speed, activePrimary, activeJitter)""",
        """    local function ironLockLane(lane, speed, activePrimary, activeJitter, looped)""")
    text = swap(text,
        """                if activePrimary then
                    if not tracks[1].IsPlaying then""",
        """                if activePrimary then
                    if not tracks[1].IsPlaying and looped ~= false then""")
    text = swap(text,
        """                if activeJitter then
                    if not tracks[2].IsPlaying then""",
        """                if activeJitter then
                    if not tracks[2].IsPlaying and looped ~= false then""")
    # rebuild when the game swaps the rig / humanoid / animator under us, when our own
    # character has no lane, or when a new server rig shows up (was: animation silently stopped)
    text = swap(text,
        """        local needsInit = player.Command == "Play"
            or #animLanes == 0
""",
        """        local lanesHealthy = #animLanes > 0
        if lanesHealthy then
            local char = p.Character
            local covered = attemptedRigs
            for _, lane in ipairs(animLanes) do
                if not lane.rig or lane.rig.Parent == nil or not lane.hum or lane.hum.Parent == nil
                    or not lane.animator or lane.animator.Parent == nil or not lane.tracks[1] then
                    lanesHealthy = false
                end
            end
            if char and char.Parent and not covered[char] then
                lanesHealthy = false
            end
            if lanesHealthy and serverVisible then
                for _, rig in getServerRigs() do
                    if not covered[rig] then lanesHealthy = false break end
                end
            end
            if not lanesHealthy then
                local now = tick()
                if now - (player.LastRebuild or 0) < 2 then
                    lanesHealthy = true -- throttle rebuilds
                else
                    player.LastRebuild = now
                end
            end
        end

        local needsInit = player.Command == "Play"
            or #animLanes == 0
            or not lanesHealthy
""")
    text = swap(text,
        """        for _, lane in ipairs(animLanes) do
            if lane.rig and lane.rig.Parent then
                for _, track in pairs(lane.tracks) do track.Looped = looped end
                ironLockLane(lane, playSpeed, activePrimary or not lane.tracks[2], activeJitter and lane.tracks[2] ~= nil)
            end
        end""",
        """        for _, lane in ipairs(animLanes) do
            if lane.rig and lane.rig.Parent then
                -- one broken lane must not stop the others from being driven
                pcall(function()
                    for _, track in pairs(lane.tracks) do track.Looped = looped end
                    ironLockLane(lane, playSpeed, activePrimary or not lane.tracks[2], activeJitter and lane.tracks[2] ~= nil, looped)
                end)
            end
        end""")
    text = swap(text,
        """    player.Destroy = function() loadGeneration = loadGeneration + 1; clearAnims() end""",
        """    player.Destroy = function()
        loadGeneration = loadGeneration + 1
        clearAnims()
        for _, template in pairs(animTemplates) do pcall(function() template:Destroy() end) end
        table.clear(animTemplates)
    end""")
    return text


def apply(text):
    text = viewmodel_chams(text)
    text = feedback_chams(text)
    text = animation_player(text)
    return text
