local function makeFrekksec(d)
    local H = {Version = "1.8.0", Schema = {}, Destroyed = false, Status = "Disabled", Driver = "Idle", BackFacingStatus = "Off", _FrekksecId="frekksec.lua"}
    local C, S = {}, H.Schema
    local function option(tab, group, key, label, default, limits, help)
        local entry = {tab = tab, group = group, key = key, label = label, default = default, help = help}
        if type(default) == "number" then entry.min, entry.max, entry.decimals = limits[1], limits[2], limits[3] or 0
        elseif type(default) == "string" and limits then entry.values = limits end
        C[key] = default
        table.insert(S, entry)
    end
    option("Main", "Controller", "Enabled", "Enable helper", false)
    option("Main", "Controller", "Driver", "Controller", "Standalone", {"Standalone", "Auto", "Frekks"}, "Standalone runs independently. Auto optionally links to an active Frekks ragebot, otherwise runs standalone. Frekks requires a working link.")
    option("Main", "Controller", "MovementEnabled", "Movement master switch", true, nil, "Turn off movement while leaving Riot Abuser rotation and other independent features available.")
    option("Main", "Controller", "Mode", "Legacy movement mode", "Orbit", {"Orbit", "Void TP", "Void Hide", "Hybrid", "Jitter", "Strafe", "Random sphere"})
    option("Main", "Controller", "MatchOnly", "Match-only movement: always on", true)
    option("Main", "Controller", "NoTarget", "When target is missing", "Anchor", {"Anchor", "Pause"})
    option("Main", "Controller", "ReturnOnDisable", "Return when disabled", true)
    option("Main", "Compatibility", "YieldToMovement", "Pause when another mover conflicts", true, nil, "Stops Frekksec when another script overwrites its movement or rotation. Rotation-only mode still allows another script to move your position.")
    option("Main", "Compatibility", "ExecutorReferences", "Use executor instance references", false, nil, "Optional compatibility for scripts that block normal Instance reads. Off uses ordinary Roblox references.")
    option("Lunar Riot", "Perfect Block", "LunarCameraLink", "Optional camera integration", false, nil, "Enables optional runtime camera discovery for Perfect Block. Body rotation works without it.")
    option("Main", "Timing", "ShotGrace", "Pause after shot (seconds)", 0.025, {0, 0.5, 3}, "Native firing and reload plans always keep priority.")
    option("Main", "Timing", "BurstEnabled", "Burst teleport timing", false)
    option("Main", "Timing", "BurstCount", "Teleports per burst", 5, {1, 20, 0})
    option("Main", "Timing", "BurstRest", "Rest between bursts (seconds)", 0.08, {0, 1, 3})
    option("Main", "Timing", "HybridOrbitTime", "Orbit time when combined", 0.35, {0.05, 5, 2})
    option("Main", "Timing", "HybridVoidTime", "Void TP time when combined", 0.25, {0.05, 5, 2})
    option("Orbit", "Path", "OrbitEnabled", "Enable orbit", true)
    option("Orbit", "Path", "OrbitShape", "Orbit shape", "Circle", {"Circle", "Ellipse", "Figure 8", "Polygon"})
    option("Orbit", "Path", "OrbitRadius", "Distance (studs)", 22, {2, 500, 1})
    option("Orbit", "Path", "OrbitSpeed", "Orbit speed (degrees/sec)", 720, {0, 3600, 0})
    option("Orbit", "Path", "OrbitInterval", "TP interval (0 = each update)", 0.02, {0, 1, 3})
    option("Orbit", "Path", "OrbitDirection", "Direction", "Alternating", {"Clockwise", "Counterclockwise", "Alternating"})
    option("Orbit", "Path", "ReverseInterval", "Reverse every (seconds)", 0.45, {0.05, 5, 2})
    option("Orbit", "Path", "EllipseRatio", "Ellipse width ratio", 1.5, {0.2, 4, 2})
    option("Orbit", "Path", "PolygonSides", "Polygon sides", 6, {3, 16, 0})
    option("Orbit", "Offsets", "OrbitX", "X offset", 0, {-100, 100, 1})
    option("Orbit", "Offsets", "OrbitY", "Height offset", 4, {-100, 100, 1})
    option("Orbit", "Offsets", "OrbitZ", "Z offset", 0, {-100, 100, 1})
    option("Orbit", "Offsets", "OrbitTilt", "Plane tilt (degrees)", 0, {-90, 90, 0})
    option("Orbit", "Offsets", "RadiusJitter", "Distance variation (%)", 20, {0, 90, 0})
    option("Orbit", "Offsets", "AngleJitter", "Angle jitter (degrees)", 18, {0, 180, 0})
    option("Orbit", "Offsets", "VerticalWave", "Vertical wave amplitude", 3, {0, 100, 1})
    option("Orbit", "Offsets", "WaveSpeed", "Vertical wave cycles/sec", 2, {0, 20, 1})
    option("Void", "Teleport", "VoidTPEnabled", "Enable void teleport", false)
    option("Void", "Teleport", "VoidPattern", "Void pattern", "Cross", {"Ring", "Cross", "Sphere", "Box"})
    option("Void", "Teleport", "VoidAnchor", "Center on", "Anchor", {"Anchor", "Target", "Saved point"})
    option("Void", "Teleport", "VoidDistance", "Horizontal distance", 3000, {0, 1e37, 2})
    option("Void", "Teleport", "VoidDepth", "Vertical distance", 800, {0, 1e37, 2})
    option("Void", "Teleport", "VoidSide", "Vertical side", "Below", {"Below", "Above", "Alternating"})
    option("Void", "Teleport", "VoidInterval", "Void TP interval", 0.025, {0, 2, 3})
    option("Void", "Teleport", "VoidVariation", "Distance variation (%)", 40, {0, 90, 0})
    option("Void", "Teleport", "VoidX", "X offset", 0, {-10000, 10000, 0})
    option("Void", "Teleport", "VoidY", "Y offset", 0, {-10000, 10000, 0})
    option("Void", "Teleport", "VoidZ", "Z offset", 0, {-10000, 10000, 0})
    option("Void", "Hide", "VoidHideEnabled", "Enable void hide", false)
    option("Void", "Hide", "HideStyle", "Hide style", "Hold", {"Hold", "Pulse"})
    option("Void", "Hide", "HideDistance", "Hide distance", 4500, {0, 1e37, 2})
    option("Void", "Hide", "HideDepth", "Hide depth", 1200, {0, 1e37, 2})
    option("Void", "Hide", "HideInterval", "Shuffle hiding point every", 0.12, {0, 5, 3})
    option("Void", "Hide", "HideDuration", "Pulse: hidden seconds", 0.4, {0.02, 5, 2})
    option("Void", "Hide", "PeekDuration", "Pulse: orbit seconds", 0.08, {0.02, 3, 2})
    option("Void", "Hide", "HideOnDamage", "Hide after taking damage", true)
    option("Void", "Hide", "DamageHideTime", "Damage hide duration", 0.4, {0.05, 5, 2})
    option("Void", "Hide", "HideLowHealth", "Hide at low health", false)
    option("Void", "Hide", "HealthThreshold", "Low health threshold", 25, {1, 100, 0})
    option("Extra", "Extra patterns", "JitterEnabled", "Enable jitter", false)
    option("Extra", "Extra patterns", "StrafeEnabled", "Enable strafe", false)
    option("Extra", "Extra patterns", "SphereEnabled", "Enable random sphere", false)
    option("Extra", "Extra patterns", "ExtraInterval", "Extra mode TP interval", 0.025, {0, 2, 3})
    option("Extra", "Extra patterns", "JitterDistance", "Jitter distance", 35, {1, 1000, 1})
    option("Extra", "Extra patterns", "JitterHeight", "Jitter height", 12, {0, 500, 1})
    option("Extra", "Extra patterns", "StrafeDistance", "Strafe sideways distance", 18, {1, 500, 1})
    option("Extra", "Extra patterns", "StrafeBehind", "Strafe behind distance", 8, {0, 500, 1})
    option("Extra", "Extra patterns", "StrafeHeight", "Strafe height", 3, {-100, 100, 1})
    option("Extra", "Extra patterns", "SphereRadius", "Random sphere radius", 100, {2, 20000, 0})
    option("Extra", "Facing", "Facing", "Facing direction", "Target", {"Target", "Travel", "Spin", "Keep"})
    option("Extra", "Facing", "SpinSpeed", "Spin degrees/sec", 1440, {-3600, 3600, 0})
    option("Extra", "Facing", "Pitch", "Pitch offset", 0, {-89, 89, 0})
    option("Extra", "Facing", "YawOffset", "Yaw offset", 0, {-180, 180, 0})
    option("Extra", "Facing", "RespectFloor", "Respect local destroy height", true, nil, "Clamps low points if Roblox has a finite destruction height. Does not prevent server kill zones.")
    option("Extra", "Facing", "FloorMargin", "Destroy height clearance", 32, {8, 500, 0})
    option("Extra", "Riot Abuser", "BackFacing", "Riot Abuser", false, nil, "Turns your back toward an opponent in 3D without Frekks. Aim is an estimate, not bullet tracking; cannot guarantee back hits. Linked mode preserves Frekks shot/reload priority.")
    option("Extra", "Riot Abuser", "BackTargetMode", "Threat selection", "Aim only", {"Aim only", "Auto", "Nearest opponent"}, "Aim only requires the enemy's estimated aim to point at your position. Nearest opponent ignores their aim direction. Auto uses aimed threats, with a positional fallback when aim data is missing.")
    option("Extra", "Riot Abuser", "BackPose", "Pose", "Auto", {"Auto", "Upright", "Upside down"}, "Auto chooses the nearer upright or inverted pose as the threat moves. Upside down forces the inverted pose.")
    option("Extra", "Riot Abuser", "BackRange", "Threat range (0 = unlimited)", 0, {0, 10000, 0}, "0 removes the threat distance cutoff, including enemies in the void. Their character position must still be available to your client.")
    option("Extra", "Riot Abuser", "BackAimRadius", "Aim-line tolerance (studs)", 6, {0.5, 30, 1}, "Aim only / Auto: smaller values require the aim line to pass closer to you. Nearest opponent ignores this setting.")
    option("Extra", "Riot Abuser", "BackHoldTime", "Hold direction (seconds)", 0.15, {0, 1, 2})
    option("Extra", "Riot Abuser", "BackTurnSpeed", "Turn speed (0 = instant)", 0, {0, 3600, 0})
    option("Targets", "Selection", "TargetMode", "Standalone movement target", "Nearest", {"Nearest", "Lowest health", "Crosshair", "Manual"}, "Frekks driver uses its existing ragebot target. Riot Abuser selects threats separately.")
    option("Targets", "Selection", "ManualTarget", "Manual player name", "")
    option("Targets", "Selection", "StickyTarget", "Keep selected target", true)
    option("Targets", "Selection", "TeamCheck", "Current-match enemies only", true, nil, "Always excludes teammates, other matches, and unconfirmed opponents.")
    option("Targets", "Selection", "MaxDistance", "Maximum target distance", 0, {0, 1e37, 2}, "Unlimited removes the distance filter. The right end selects Unlimited; exact input accepts 0, inf, or unlimited. Invalid or unreplicated positions are held by enemy identity until usable again.")
    option("Targets", "Selection", "Prediction", "Target prediction (seconds)", 0.04, {0, 0.3, 3})
    option("Targets", "Selection", "MaxPrediction", "Maximum prediction offset", 20, {0, 100, 1})
    option("Targets", "Display", "ShowHud", "Show live status", true)
    option("Targets", "Display", "ShowMarker", "Show requested position marker", false, nil, "A local marker, not confirmation of the server position.")
    addFrekksecExtraOptions(option)
    local byKey = {}
    for _, item in ipairs(S) do byKey[item.key] = item end
    byKey.Driver.aliases = {Character="Standalone"}
    byKey.Mode.hidden=true -- Kept for older configs and callers; the visible controls are independent.
    byKey.FakeGhostColor.pattern="^#?%x%x%x%x%x%x$"
    byKey.FakeHeight.exactNumber=true
    byKey.MatchOnly.fixed=true
    byKey.TeamCheck.fixed=true
    local movementModes={{"OrbitEnabled","Orbit"},{"VoidTPEnabled","Void TP"},{"VoidHideEnabled","Void Hide"},
        {"JitterEnabled","Jitter"},{"StrafeEnabled","Strafe"},{"SphereEnabled","Random sphere"}}
    local movementKeys={}
    for _,item in ipairs(movementModes) do movementKeys[item[1]]=true end
    for _,key in ipairs({"VoidDistance","VoidDepth","HideDistance","HideDepth","MaxDistance","FakeHeight"}) do
        byKey[key].wideDistance=true
        byKey[key].unlimited=key=="MaxDistance"
        if key~="MaxDistance" and key~="FakeHeight" then byKey[key].help="Logarithmic slider: 0 to 1e37 studs. Exact input accepts scientific notation, e.g. 1e8. Infinity and 1e272 cannot be used as Roblox positions." end
    end
    local st = {connections = {}, now = d.now(), started = d.now(), nextMove = 0, count = 0,
        burst = 0, shotUntil = 0, damageUntil = 0, manualHide = false, nextScan = 0, link = nil,
        lastNative = 0, forced = {}, errors = 0, host = nil}
    H.Stats = {Teleports = 0, ShotPasses = 0, ReloadPasses = 0, Clamped = 0, Errors = 0}
    local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
    local validVector=FrekksecSpace.Vector
    local function validFrame(cf) return typeof(cf) == "CFrame" and validVector(cf.Position) end
    local function clone(t) local copy = {}; for k, v in pairs(t) do copy[k] = v end; return copy end
    local function activeHost()
        local host = d.host()
        return host and not host.Unloaded and host or nil
    end
    local function hostRageOn(host)
        local toggle = host and host.Toggles and host.Toggles.P8S4T1
        return toggle and toggle.Value == true or false
    end
    local function restoreHost()
        for _, item in ipairs(st.forced) do
            if item.control.Value == item.forced then pcall(item.control.SetValue, item.control, item.original) end
        end
        st.forced = {}
    end
    local function forceSetting(control, value)
        if not control or type(control.SetValue) ~= "function" then return end
        local found
        for _, entry in ipairs(st.forced) do if entry.control == control then found = entry; break end end
        if not found then table.insert(st.forced, {control = control, original = control.Value, forced = value})
        elseif control.Value ~= value then found.original = control.Value end
        if control.Value ~= value then control:SetValue(value) end
    end
    local function clearDefenseAngles()
        local owner=st.defenseOwner
        st.defenseOwner=nil
        if owner then
            local driver=owner.controller._viewAngleDriver
            local slots=driver and driver._payloadBySlot
            if type(slots)=="table" and slots[20]==owner.payload then
                pcall(owner.controller.SendViewAngles,owner.controller,20,nil)
            end
        end
        H.DefenseViewAngles=nil
    end
    local function releaseLink()
        clearDefenseAngles()
        if d.resetExtras then d.resetExtras(true) end
        local link = st.link
        st.link = nil
        if link then
            link.retired=true
            local owned=rawget(link.engine, "_Plan") == link.wrapper
            if owned then rawset(link.engine, "_Plan", link.rawPlan) end
            if owned and st.wroteNative and not link.runtime.destroyed then
                local inner = link.engine._innerContext
                if inner and inner.CharacterController then
                    pcall(inner.CharacterController.SetServerCFrame, inner.CharacterController, nil)
                end
            end
        end
        st.wroteNative = false
        H.DefenseViewAngles = nil
        H.BackFacingStatus = C.BackFacing and "Waiting for opponent" or "Off"
        if d.setRotation then d.setRotation(false) end
        if d.resetDefense then d.resetDefense() end
        restoreHost()
    end
    local function resetMotion()
        clearDefenseAngles()
        if d.setRotation then d.setRotation(false) end
        if d.resetExtras then d.resetExtras(true) end
        st.cached, st.cachedBase, st.cachedMode, st.targetName = nil, nil, nil, nil
        st.targetIdentity = nil
        st.nextMove, st.burst, st.count, st.shotUntil = 0, 0, 0, 0
        st.damageUntil, st.manualHide, st.lastHealth = 0, false, nil
        st.started = d.now()
        H.DefenseViewAngles = nil
        H.BackFacingStatus = C.BackFacing and "Waiting for movement" or "Off"
        if d.resetDefense then d.resetDefense() end
    end
    function H:Get(key) return C[key] end
    function H:GetConfig() return clone(C) end
    function H:Set(key, value)
        if self.Destroyed then return false, "This Frekksec instance has been unloaded" end
        local def = byKey[key]
        if not def then return false, "Unknown setting: " .. tostring(key) end
        if def.fixed~=nil and value~=def.fixed then return false,"Match and enemy checks are always enabled" end
        if def.aliases and type(value)=="string" then value=def.aliases[value] or value end
        if type(def.default) == "number" then
            if def.unlimited and (value==math.huge or type(value)=="string" and table.find({"inf","infinity","unlimited"},value:lower():match("^%s*(.-)%s*$"))) then value=0 end
            if type(value) ~= "number" and type(value) ~= "string" then return false, "A finite number is required" end
            value = tonumber(value)
            if not finite(value) then return false, "A finite number is required" end
            if def.wideDistance and (value<def.min or value>def.max) then return false,"Enter a distance from 0 to 1e37 studs" end
            value = math.clamp(value, def.min, def.max)
            local places = 10 ^ def.decimals
            if not def.exactNumber and math.abs(value)<1e12 then value = math.floor(value * places + 0.5) / places end
        elseif type(def.default) == "boolean" then
            if type(value) ~= "boolean" then return false, "A boolean is required" end
        elseif type(value) ~= "string" then return false, "Text is required"
        elseif def.values and not table.find(def.values, value) then return false, "Unknown option"
        else value = value:sub(1, 80) end
        if key=="FakeGhostColor" and not value:match("^#?%x%x%x%x%x%x$") then return false,"Use a six-digit hex color, such as #00A2FF" end
        if C[key] == value and key~="Mode" then return true end
        C[key] = value
        st.nextMove, st.cached = 0, nil
        if key:sub(1,4)=="Back" then
            clearDefenseAngles()
            if d.setRotation then d.setRotation(false) end
            self.BackFacingStatus = C.BackFacing and "Waiting for movement" or "Off"
            if d.resetDefense then d.resetDefense() end
        end
        if key=="FakeEnabled" and not value and d.stopFake then d.stopFake() end
        if key=="LunarMode" or key=="LunarPriority" then
            clearDefenseAngles()
            if d.resetLunar then d.resetLunar() end
            if d.setRotation then d.setRotation(false) end
        end
        if key == "Enabled" then
            if value then
                resetMotion(); st.nextScan = 0; st.refreshAnchor = true
                if d.forgetMovement then d.forgetMovement() end
                self.Status = "Waiting for controller"
            else
                local canReturn=not d.canReturn or d.canReturn()
                releaseLink()
                if canReturn and C.ReturnOnDisable and st.movedDirect and st.anchor and st.character == d.character() then
                    pcall(d.move, st.anchor)
                end
                st.movedDirect = false
                self._uiHide = false
                resetMotion()
                self.Driver, self.Status = "Idle", "Disabled"
                self.TargetName, self.LastDestination = nil, nil
                if d.forgetMovement then d.forgetMovement() end
            end
        elseif key == "Driver" then
            releaseLink(); resetMotion(); st.nextScan = 0
            if d.forgetMovement then d.forgetMovement() end
        elseif key == "MovementEnabled" then
            restoreHost(); resetMotion(); st.movedDirect=false; st.refreshAnchor=true
            if d.forgetMovement then d.forgetMovement() end
        elseif key == "Mode" then
            -- An explicit legacy mode selection is a preset; individual switches never change each other.
            for _,item in ipairs(movementModes) do
                self:Set(item[1],value==item[2] or value=="Hybrid" and (item[2]=="Orbit" or item[2]=="Void TP"))
            end
            st.started, st.burst = d.now(), 0
        elseif movementKeys[key] then
            st.started, st.burst, st.cachedMode = d.now(), 0, nil
        end
        if self.OnConfigChanged then self.OnConfigChanged(key, value) end
        return true
    end
    function H:ApplyPreset(name)
        local presets = {
            Aggressive = {Mode="Hybrid", OrbitRadius=22, OrbitSpeed=1440, OrbitInterval=0,
                OrbitDirection="Alternating", ReverseInterval=0.3, RadiusJitter=35, AngleJitter=40,
                VoidDistance=5000, VoidDepth=1200, VoidInterval=0, VoidPattern="Cross", VoidVariation=55,
                HybridOrbitTime=0.25, HybridVoidTime=0.2, BurstEnabled=false, ShotGrace=0.015},
            Balanced = {Mode="Orbit", OrbitRadius=22, OrbitSpeed=540, OrbitInterval=0.04,
                OrbitDirection="Clockwise", RadiusJitter=15, AngleJitter=10, VoidDistance=2000,
                VoidDepth=600, VoidInterval=0.08, BurstEnabled=false, ShotGrace=0.04},
            Wide = {Mode="Void TP", VoidPattern="Sphere", VoidDistance=12000, VoidDepth=3000,
                VoidInterval=0.02, VoidVariation=40, OrbitRadius=70, OrbitSpeed=720,
                BurstEnabled=true, BurstCount=6, BurstRest=0.12},
            Orbit = {Mode="Orbit", OrbitShape="Figure 8", OrbitRadius=30, OrbitSpeed=720,
                OrbitInterval=0.02, RadiusJitter=10, AngleJitter=0, VerticalWave=5, BurstEnabled=false},
        }
        local preset = presets[name]
        if not preset then return false, "Unknown preset" end
        for key, value in pairs(preset) do self:Set(key, value) end
        return true
    end
    function H:SetManualHide(value) st.manualHide = value == true; st.nextMove = 0 end
    function H:CaptureAnchor()
        local cf = d.clientFrame(st.link and st.link.engine)
        if not validFrame(cf) then return false, "No valid character position" end
        st.saved = cf
        st.savedCharacter = d.character()
        st.savedEnvironment = d.environment and d.environment() or nil
        if not st.movedDirect then st.anchor = cf end
        return true
    end
    function H:Panic()
        local shouldReturn = st.movedDirect and (not d.canReturn or d.canReturn())
        self:Set("Enabled", false)
        if shouldReturn and not C.ReturnOnDisable and st.anchor and st.character == d.character() then
            pcall(d.move, st.anchor)
        end
        self.Status = "Stopped / position restored"
    end
    function H:Suspend(reason)
        st.movedDirect=false
        if d.resetExtras then d.resetExtras(false) end
        if d.forgetMovement then d.forgetMovement() end
        self:Set("Enabled",false)
        self.Status="Paused: "..tostring(reason)
        self.LastError=tostring(reason)
        d.report(self.Status)
    end
    local function observe(ctx)
        if ctx.character ~= st.character or ctx.environmentId ~= st.environment then
            st.character = ctx.character
            st.environment = ctx.environmentId
            st.anchor = ctx.localFrame
            if st.savedCharacter ~= ctx.character or st.savedEnvironment ~= ctx.environmentId then st.saved = nil end
            st.movedDirect = false
            resetMotion()
            if d.forgetMovement then d.forgetMovement() end
        elseif not st.anchor and validFrame(ctx.localFrame) then st.anchor = ctx.localFrame end
        if st.refreshAnchor and validFrame(ctx.localFrame) then st.anchor = ctx.localFrame; st.refreshAnchor = false end
        if finite(ctx.health) then
            if st.lastHealth and ctx.health < st.lastHealth then st.damageUntil = d.now() + C.DamageHideTime end
            st.lastHealth = ctx.health
        end
    end
    local function hidden(ctx, now, selectedMode)
        if st.manualHide then return true, "Manual hide" end
        if C.VoidHideEnabled and C.HideOnDamage and now < st.damageUntil then return true, "Damage hide" end
        if C.VoidHideEnabled and C.HideLowHealth and ctx.health and ctx.health > 0 and ctx.health <= C.HealthThreshold then return true, "Low health hide" end
        if selectedMode == "Void Hide" then
            if C.HideStyle == "Pulse" and (now - st.started) % (C.HideDuration + C.PeekDuration) >= C.HideDuration then
                return false, "Peek"
            end
            return true, "Void hide"
        end
        return false
    end
    local function selectedMode(elapsed)
        local total=0
        for _,item in ipairs(movementModes) do
            if C[item[1]] then
                total+=item[2]=="Orbit" and C.HybridOrbitTime or item[2]=="Void TP" and C.HybridVoidTime
                    or item[2]=="Void Hide" and C.HideDuration or 0.25
            end
        end
        if total==0 then return nil end
        local position=elapsed%total
        for _,item in ipairs(movementModes) do
            if C[item[1]] then
                local duration=item[2]=="Orbit" and C.HybridOrbitTime or item[2]=="Void TP" and C.HybridVoidTime
                    or item[2]=="Void Hide" and C.HideDuration or 0.25
                if position<duration then return item[2] end
                position-=duration
            end
        end
        return nil
    end
    local function movementActive()
        if not C.MovementEnabled then return false end
        if st.manualHide then return true end
        for _,item in ipairs(movementModes) do if C[item[1]] then return true end end
        return false
    end
    local function unitSphere()
        local y, a = d.random(-1, 1), d.random(0, math.pi * 2)
        local r = math.sqrt(math.max(0, 1 - y * y))
        return Vector3.new(r * math.cos(a), y, r * math.sin(a))
    end
    local function centerFor(ctx, isVoid)
        local base = st.anchor or ctx.localFrame
        if isVoid and C.VoidAnchor == "Saved point" then base = st.saved or base
        elseif (not isVoid or C.VoidAnchor == "Target") and validFrame(ctx.targetFrame) then
            base = ctx.targetFrame
            local velocity = ctx.targetVelocity
            if validVector(velocity) then
                local speed,direction=FrekksecSpace.Delta(velocity,Vector3.zero)
                local prediction=direction*math.min(speed*C.Prediction,C.MaxPrediction)
                base = base + prediction
            end
        end
        return base
    end
    local function orbitPoint(center, elapsed)
        local t = elapsed
        if C.OrbitDirection == "Alternating" then
            local period = C.ReverseInterval
            local section = math.floor(elapsed / period)
            t = section % 2 == 0 and elapsed % period or period - elapsed % period
        elseif C.OrbitDirection == "Counterclockwise" then t = -t end
        local angle = math.rad(C.OrbitSpeed) * t + math.rad(d.random(-C.AngleJitter, C.AngleJitter))
        local radius = C.OrbitRadius * (1 + d.random(-1, 1) * C.RadiusJitter / 100)
        local x, z = radius * math.cos(angle), radius * math.sin(angle)
        if C.OrbitShape == "Ellipse" then x = x * C.EllipseRatio
        elseif C.OrbitShape == "Figure 8" then z = radius * math.sin(angle * 2) * 0.65
        elseif C.OrbitShape == "Polygon" then
            local step = 2 * math.pi / C.PolygonSides
            local edge = (angle % (2 * math.pi)) / step
            local a, alpha = math.floor(edge) * step, edge % 1
            x = radius * (math.cos(a) * (1-alpha) + math.cos(a+step) * alpha)
            z = radius * (math.sin(a) * (1-alpha) + math.sin(a+step) * alpha)
        end
        local wave = C.VerticalWave * math.sin(elapsed * math.pi * 2 * C.WaveSpeed)
        local offset = CFrame.Angles(math.rad(C.OrbitTilt), 0, 0):VectorToWorldSpace(Vector3.new(x, wave, z))
        return center.Position + offset + Vector3.new(C.OrbitX, C.OrbitY, C.OrbitZ)
    end
    local function voidPoint(center, hide)
        local distance = hide and C.HideDistance or C.VoidDistance
        local depth = hide and C.HideDepth or C.VoidDepth
        distance = distance * (1 + d.random(-1, 1) * C.VoidVariation / 100)
        local angle = d.random(0, math.pi * 2)
        local side = C.VoidSide == "Above" and 1 or -1
        if C.VoidSide == "Alternating" then side = st.count % 2 == 0 and 1 or -1 end
        local x, z, y = math.cos(angle)*distance, math.sin(angle)*distance, side*depth
        if not hide and C.VoidPattern == "Cross" then
            local a = (st.count % 4) * math.pi / 2
            x, z = math.cos(a)*distance, math.sin(a)*distance
        elseif not hide and C.VoidPattern == "Sphere" then
            local u = unitSphere()
            x, z, y = u.X*distance, u.Z*distance, side*(depth + math.abs(u.Y)*distance)
        elseif not hide and C.VoidPattern == "Box" then
            x, z = d.random(-distance, distance), d.random(-distance, distance)
        end
        return center.Position + Vector3.new(x+C.VoidX, y+C.VoidY, z+C.VoidZ)
    end
    local function facing(position, ctx, elapsed)
        local result = CFrame.new(position)
        local aim
        if C.Facing == "Target" and validFrame(ctx.targetFrame) then aim = ctx.targetFrame.Position
        elseif C.Facing == "Travel" and st.cached then
            local _,direction=FrekksecSpace.Delta(position,st.cached.Position)
            result=FrekksecSpace.Face(position,direction)
        elseif C.Facing == "Keep" then result = CFrame.new(position) * (ctx.localFrame - ctx.localFrame.Position)
        elseif C.Facing == "Spin" then result = result * CFrame.Angles(0, math.rad(elapsed*C.SpinSpeed), 0) end
        if aim and validVector(aim) then
            local distance,direction=FrekksecSpace.Delta(Vector3.new(aim.X,position.Y,aim.Z),position)
            if distance>0.01 then result=FrekksecSpace.Face(position,direction) end
        end
        return result * CFrame.Angles(math.rad(C.Pitch), math.rad(C.YawOffset), 0)
    end
    local function backFacing(frame,ctx,moving)
        H.DefenseViewAngles = nil
        local extra=d.extra and d.extra(frame,C,ctx,moving==true) or {}
        if extra.frame then
            if not validFrame(extra.frame) then error("Invalid extra-mode destination") end
            frame=extra.frame
        end
        if C.RespectFloor then
            local floor=d.floorHeight()
            if finite(floor) and frame.Position.Y<floor+C.FloorMargin then
                frame=CFrame.new(frame.Position.X,floor+C.FloorMargin,frame.Position.Z)*(frame-frame.Position)
            end
        end
        H.FrameMoves=moving==true or extra.moves==true
        H.ReturnMovement=moving==true or extra.returnToAnchor==true
        H.FrameRotation=extra.active==true
        local usedLunar=extra.lunarActive==true
        if not C.BackFacing then H.BackFacingStatus="Off"
        elseif not d.defense then H.BackFacingStatus="Enemy reader unavailable"
        else
            local rotated,status,angles=d.defense(frame,C,ctx)
            H.BackFacingStatus=status
            if rotated and validFrame(rotated) and not (extra.lunarActive and C.LunarPriority=="Lunar mode") then
                frame,H.DefenseViewAngles=rotated,angles
                H.FrameRotation=true;usedLunar=false
            elseif rotated and extra.lunarActive and C.LunarPriority=="Lunar mode" then
                H.BackFacingStatus="Paused for Lunar rotation"
            end
        end
        if usedLunar then H.DefenseViewAngles=extra.angles end
        if d.commitExtras then d.commitExtras(frame,C,ctx,extra,usedLunar) end
        return frame
    end
    local function rotationFallback(ctx,frame)
        if not ctx.alive or C.MatchOnly and not ctx.inMatch or not validFrame(frame) then return nil end
        if not C.BackFacing and not C.FakeEnabled and C.LunarMode=="Off" then return nil end
        local rotated=backFacing(frame,ctx,false)
        return (H.FrameRotation or H.FrameMoves) and rotated or nil
    end
    function H:Destination(ctx)
        observe(ctx)
        self.DefenseViewAngles = nil
        self.FrameMoves,self.FrameRotation,self.ReturnMovement=false,false,false
        self.BackFacingStatus = C.BackFacing and "Waiting for movement" or "Off"
        if not ctx.alive then
            if d.resetExtras then d.resetExtras(false) end
            self.TargetName,self.LastDestination=nil,nil
            self.Status = "Waiting for character"; return nil
        end
        if C.MatchOnly and not ctx.inMatch then
            if d.resetExtras then d.resetExtras(true) end
            self.TargetName,self.LastDestination=nil,nil
            self.Status = "Waiting for match"; return nil
        end
        local now=d.now()
        local mode=C.MovementEnabled and selectedMode(now-st.started) or nil
        if not C.MovementEnabled or not mode and not st.manualHide then
            self.LastDestination=nil
            self.TargetName=ctx.targetName
            local frame=ctx.rotationFrame or ctx.localFrame
            if not validFrame(frame) then self.Status="Waiting for valid position";return nil end
            local rotated=backFacing(frame,ctx,false)
            self.Status=self.FrameMoves and "Extra movement" or self.FrameRotation and "Rotation only"
                or not C.MovementEnabled and "Movement disabled" or "No movement modes enabled"
            return (self.FrameRotation or self.FrameMoves) and rotated or nil
        end
        local elapsed=now-st.started
        local hide, why = hidden(ctx, now, mode)
        if hide then mode = "Void Hide"
        elseif mode == "Void Hide" then
            if C.OrbitEnabled then mode="Orbit"
            else
                st.cached, st.cachedBase, st.cachedMode, st.nextMove = nil, nil, nil, 0
                local anchor = st.anchor
                if not validFrame(anchor) then
                    self.LastDestination=nil
                    self.Status="Void hide pulse: waiting for anchor"
                    return nil
                end
                local peek = backFacing(anchor,ctx,true)
                self.LastDestination=peek
                self.Status="Void hide pulse: peek"
                return peek
            end
        end
        local isVoid = mode == "Void TP" or mode == "Void Hide"
        if ctx.targetIdentity ~= st.targetIdentity then
            st.targetIdentity = ctx.targetIdentity
            st.cached, st.nextMove, st.burst = nil, 0, 0
        end
        if ctx.targetPending then
            self.TargetName=ctx.targetName
            if not isVoid or C.VoidAnchor=="Target" then
                st.cached,st.nextMove,st.burst=nil,0,0
                self.LastDestination=nil
                self.Status=ctx.targetReason or "Tracking enemy; waiting for position"
                return nil
            end
        end
        if C.TeamCheck and ctx.targetAllowed == false then
            self.TargetName = nil
            if not isVoid or C.VoidAnchor == "Target" then
                st.cached, st.nextMove, st.burst = nil, 0, 0
                self.LastDestination = nil
                self.Status = ctx.targetReason or "Waiting for a match opponent"
                return nil
            end
        end
        if not hide and (not isVoid or C.VoidAnchor == "Target") and C.NoTarget == "Pause" and not validFrame(ctx.targetFrame) then
            self.LastDestination=nil
            self.Status = "Waiting for target"; return nil
        end
        if st.cachedMode ~= mode then st.nextMove = 0; st.burst = 0 end
        if st.cached and now < st.nextMove then
            st.cached=backFacing(st.cachedBase or st.cached,ctx,true)
            self.LastDestination=st.cached
            return st.cached
        end
        local center = centerFor(ctx, isVoid)
        if not validFrame(center) then self.LastDestination=nil;self.Status = "Waiting for valid position"; return nil end
        local position, interval
        if mode == "Orbit" then position, interval = orbitPoint(center, elapsed), C.OrbitInterval
        elseif isVoid then position, interval = voidPoint(center, mode=="Void Hide"), mode=="Void Hide" and C.HideInterval or C.VoidInterval
        elseif mode == "Jitter" then
            position = center.Position + Vector3.new(d.random(-C.JitterDistance,C.JitterDistance), d.random(-C.JitterHeight,C.JitterHeight),d.random(-C.JitterDistance,C.JitterDistance))
            interval = C.ExtraInterval
        elseif mode == "Strafe" then
            position = center:PointToWorldSpace(Vector3.new((st.count%2==0 and 1 or -1)*C.StrafeDistance,C.StrafeHeight,C.StrafeBehind))
            interval = C.ExtraInterval
        else position, interval = center.Position + unitSphere()*C.SphereRadius, C.ExtraInterval end
        if not validVector(position) then self.LastDestination=nil;self.Status = "Rejected invalid destination"; return nil end
        local floorClamped = false
        if C.RespectFloor then
            local floor = d.floorHeight()
            if finite(floor) and position.Y < floor+C.FloorMargin then
                position = Vector3.new(position.X, floor+C.FloorMargin, position.Z)
                self.Stats.Clamped = self.Stats.Clamped+1
                floorClamped = true
            end
        end
        if not validVector(position) then self.LastDestination=nil;self.Status = "Rejected invalid destroy height"; return nil end
        local baseFrame = facing(position, ctx, elapsed)
        local cf = backFacing(baseFrame,ctx,true)
        if not validFrame(cf) then self.LastDestination=nil;self.Status = "Rejected invalid rotation"; return nil end
        st.cached, st.cachedMode = cf, mode
        st.cachedBase = baseFrame
        st.count, st.burst = st.count+1, st.burst+1
        st.nextMove = now + interval
        if C.BurstEnabled and st.burst >= C.BurstCount then
            st.nextMove, st.burst = now+math.max(interval,C.BurstRest), 0
        end
        self.Stats.Teleports = self.Stats.Teleports+1
        self.LastDestination, self.TargetName = cf, ctx.targetName or "Anchor"
        self.Status = (why or mode)..(floorClamped and " / floor limit" or "")
        return cf
    end
    local function onError(err)
        H.Stats.Errors = H.Stats.Errors+1
        H.LastError = tostring(err)
        H:Set("Enabled", false)
        H.Status = "Stopped: " .. tostring(err):sub(1,150)
        d.report(H.Status)
    end
    local function bind(runtime, host)
        local engine = runtime.engine
        if type(engine._Plan) ~= "function" then return false end
        resetMotion()
        local link = {runtime=runtime, engine=engine, host=host, original=engine._Plan, rawPlan=rawget(engine,"_Plan")}
        local function planOnce(self, dt, action, target, root, client, mode, canAttack)
            local plan=link.original(self,dt,action,target,root,client,mode,canAttack)
            if type(plan)~="table" then return plan end
            if link.retired or not C.Enabled or H.Destroyed or runtime.destroyed or not runtime.enabled then return plan end
            local ok, replacement = pcall(function()
                H.DefenseViewAngles=nil
                local ctx = d.nativeContext(self, target, client, C)
                observe(ctx)
                st.lastNative = d.now()
                if ctx.reloading then
                    if d.pauseExtras then d.pauseExtras() end
                    H.Stats.ReloadPasses = H.Stats.ReloadPasses+1
                    H.Status = "Frekks reload protection"
                    H.BackFacingStatus=C.BackFacing and "Paused for reload" or "Off"
                    return plan
                end
                if plan.WeaponAction ~= nil or plan.IsAimPose then
                    if d.notifyShot then d.notifyShot(C) end
                    if d.pauseExtras then d.pauseExtras() end
                    st.shotUntil = d.now()+C.ShotGrace
                    H.Stats.ShotPasses = H.Stats.ShotPasses+1
                    H.Status = "Frekks shot priority"
                    H.BackFacingStatus=C.BackFacing and "Paused for your shot" or "Off"
                    return plan
                end
                if d.now() < st.shotUntil then
                    if d.pauseExtras then d.pauseExtras() end
                    H.Status = "Shot recovery"
                    H.BackFacingStatus=C.BackFacing and "Paused for shot recovery" or "Off"
                    return plan
                end
                if not movementActive() and validFrame(plan.CFrame) then ctx.rotationFrame=plan.CFrame end
                local destination = H:Destination(ctx)
                if not destination then
                    destination=rotationFallback(ctx,validFrame(plan.CFrame) and plan.CFrame or ctx.localFrame)
                end
                if not destination then return plan end
                if d.validateFrame then
                    local allowed,reason=d.validateFrame(destination)
                    if not allowed then
                        if d.resetExtras then d.resetExtras(false) end
                        H.LastDestination=nil;H.Status="Movement paused: "..reason
                        return plan
                    end
                end
                local copy = clone(plan)
                copy.CFrame, copy.ShouldSkipDefense = destination, true
                if H.DefenseViewAngles then
                    copy.ViewAngles=H.DefenseViewAngles
                    local inner=self._innerContext
                    if inner and inner.CharacterController then
                        st.defenseOwner={controller=inner.CharacterController,payload=copy.ViewAngles}
                    end
                end
                st.wroteNative = true
                return copy
            end)
            if not ok then onError(replacement); return plan end
            return replacement
        end
        link.wrapper=function(self,dt,action,target,root,client,mode,canAttack)
            if link.inPlan then return {CFrame=client,ShouldSkipDefense=false} end
            link.inPlan=true
            local ok,plan=pcall(planOnce,self,dt,action,target,root,client,mode,canAttack)
            link.inPlan=false
            if not ok then error(plan,0) end
            return plan
        end
        rawset(engine,"_Plan",link.wrapper)
        st.link = link
        if movementActive() then
            forceSetting(host.Toggles and host.Toggles.FrekksExtremeHvhHelper, false)
            forceSetting(host.Options and host.Options.P8S4D2, "Random")
        end
        H.Driver = "Frekks linked"
        return true
    end
    function H:Rescan() releaseLink(); st.nextScan = 0 end
    function H:Step()
        if self.Destroyed or not C.Enabled then return end
        local host, now = C.Driver~="Standalone" and activeHost() or nil, d.now()
        if st.link and rawget(st.link.engine,"_Plan") ~= st.link.wrapper then
            releaseLink();st.nextScan=math.huge
            self:Suspend("Another script replaced the linked planner; retry the optional link when ready")
            return
        elseif st.link and (st.link.runtime.destroyed or host ~= st.link.host) then
            releaseLink(); st.nextScan = 0
        end
        if C.Driver~="Standalone" then
            if st.link and (not hostRageOn(host) or not st.link.runtime.enabled) then releaseLink() end
            local reason=not host and "Optional Frekks link unavailable" or "Frekks ragebot inactive"
            if hostRageOn(host) and not st.link and now >= st.nextScan then
                st.nextScan = math.huge
                local runtime,detail = d.findRuntime()
                reason=detail or "Waiting for active Frekks runtime"
                if runtime and runtime.enabled and not runtime.destroyed then bind(runtime,host) end
            end
            if st.link then
                self.Driver = "Frekks linked"
                if movementActive() then
                    forceSetting(host.Toggles and host.Toggles.FrekksExtremeHvhHelper,false)
                    forceSetting(host.Options and host.Options.P8S4D2,"Random")
                end
                if now-st.lastNative > 1 then self.Status = "Linked / waiting for movement plan" end
                return
            elseif C.Driver=="Frekks" then
                if d.setRotation then d.setRotation(false) end
                if d.resetExtras then d.resetExtras(true) end
                self.Driver,self.Status="Waiting",reason
                return
            end
        end
        if st.link then releaseLink() end
        if self.Driver~="Standalone" then resetMotion() end
        self.Driver = "Standalone"
        local ctx = d.directContext(C, st.anchor)
        if ctx.alive and ctx.inMatch and d.beforeMove then
            local allowed,reason=d.beforeMove()
            if not allowed then self:Suspend(reason);return end
        end
        local destination = self:Destination(ctx)
        if not destination then
            destination=rotationFallback(ctx,ctx.localFrame)
        end
        if destination and d.validateFrame then
            local allowed,reason=d.validateFrame(destination)
            if not allowed then
                if d.resetExtras then d.resetExtras(false) end
                self.LastDestination=nil;self.Status="Movement paused: "..reason;destination=nil
            end
        end
        if d.setRotation then d.setRotation(destination~=nil and self.FrameRotation==true) end
        if destination then
            local moved,reason
            if self.FrameMoves then
                moved,reason=d.move(destination)
                if moved~=false and self.ReturnMovement then st.movedDirect = true end
            elseif d.rotate then moved,reason=d.rotate(destination) end
            if moved==false and reason then
                self.LastDestination=nil;self.Status="Movement paused: "..reason
                if d.setRotation then d.setRotation(false) end
            end
        end
    end
    function H:Tick()
        if self._stepping or self.Destroyed then return end
        self._stepping=true
        local ok, err = pcall(self.Step,self)
        self._stepping=false
        if not ok then onError(err) end
    end
    function H:Destroy()
        if self.Destroyed then return end
        pcall(self.Set,self,"Enabled",false)
        pcall(releaseLink)
        self.Destroyed = true
        for _, connection in ipairs(st.connections) do pcall(connection.Disconnect,connection) end
        st.connections = {}
        if self.OnDestroy then
            local ok,err=pcall(self.OnDestroy)
            if not ok then d.report("Cleanup error: "..tostring(err)) end
        end
    end
    function H:Track(connection)
        if self.Destroyed then pcall(connection.Disconnect,connection)
        else table.insert(st.connections,connection) end
        return connection
    end
    return H
end

