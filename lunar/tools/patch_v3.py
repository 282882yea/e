"""Applies the Lunar UI module and the visuals fixes to a Frekks Hail v3 build.

    python3 tools/patch_v3.py <input.lua> <output.lua>
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_frekks as bf  # noqa: E402
import fixes_v3b  # noqa: E402
import fixes_wire  # noqa: E402
import base64
SNOWBALL = base64.b64encode(open(os.path.join(HERE, '..', 'frekks', 'snowball.png'), 'rb').read()).decode()


def swap(text, old, new, count=1):
    assert text.count(old) == count, (text.count(old), old[:120])
    return text.replace(old, new)


def between(text, start, end, replacement):
    assert text.count(start) == 1, start[:120]
    a = text.index(start)
    b = text.index(end, a)
    return text[:a] + replacement + text[b:]


def visuals(text):
    # --- Third person: not cut off by the open menu or by the ragebot ----------
    text = swap(text,
        "        local function active(name)\n            if blocked() or not api.runtime or api.runtime.destroyed then return false end\n",
        "        local function active(name)\n"
        "            if name == 'ThirdPerson' then\n"
        "                -- camera only: the open menu and the ragebot must not switch it off\n"
        "                if not api.alive or not api.runtime or api.runtime.destroyed then return false end\n"
        "                local toggle, bind = T.P4S2T8, O.FrekksThirdKey\n"
        "                if not toggle or toggle.Value ~= true then return false end\n"
        "                if not bind then return true end\n"
        "                local mode = type(bind.GetMode) == 'function' and bind:GetMode() or bind.Mode\n"
        "                if mode == 'Always' or bind.Value == 'None' or bind.Value == 'Unknown' then return true end\n"
        "                return type(bind.GetState) == 'function' and bind:GetState() == true\n"
        "            end\n"
        "            if blocked() or not api.runtime or api.runtime.destroyed then return false end\n")

    # --- Wireframes: glowing flat lines, edge-detail control ------------------------
    text = swap(text,
        "                dep:AddSlider('FrekksWire'..scope..'Width',{Text=scope..' wireframe width',Default=0.0025,Min=0.001,Max=0.02,Rounding=4})\n",
        "                dep:AddSlider('FrekksWire'..scope..'Width',{Text=scope..' wireframe width',Default=0.004,Min=0.001,Max=0.03,Rounding=4})\n"
        "                dep:AddSlider('FrekksWire'..scope..'Crease',{Text='Edge detail',Default=35,Min=0,Max=89,Rounding=0,Suffix='°',\n"
        "                    Tooltip='Higher hides small creases and keeps only the outline edges.'})\n"
        "                dep:AddToggle('FrekksWire'..scope..'Glow',{Text='Glowing lines',Default=true})\n")
    text = swap(text,
        "                local width,color=num('FrekksWire'..scope..'Width',0.0025),value('FrekksWire'..scope..'Color',Color3.new(1,1,1))\n"
        "                for part in pairs(wanted) do\n"
        "                    local w=entries[part]\n"
        "                    if not w then w=self.runtime:MakeWire(part,width,color); entries[part]=w end\n"
        "                    if w._width~=width then w:SetWidth(width) end\n"
        "                    if w._color~=color then w:SetColor(color) end\n"
        "                end\n"
        "                for part,w in pairs(entries) do if not wanted[part] then self.runtime:RemoveWire(w); entries[part]=nil end end\n",
        "                local width,color=num('FrekksWire'..scope..'Width',0.004),value('FrekksWire'..scope..'Color',Color3.new(1,1,1))\n"
        "                local crease,glowing=num('FrekksWire'..scope..'Crease',35),value('FrekksWire'..scope..'Glow',true)~=false\n"
        "                self.wireLooks=self.wireLooks or setmetatable({},{__mode='k'})\n"
        "                local looks=self.wireLooks\n"
        "                for part in pairs(wanted) do\n"
        "                    local w=entries[part]\n"
        "                    if not w then w=self.runtime:MakeWire(part,width,color); entries[part]=w end\n"
        "                    if w._width~=width then w:SetWidth(width) end\n"
        "                    if w._creaseDegrees~=crease and w.SetCreaseDegrees then w:SetCreaseDegrees(crease) end\n"
        "                    if w._color~=color then w:SetColor(color) end\n"
        "                    -- flat, unlit lines instead of the textured surface\n"
        "                    if not looks[part] then pcall(function() looks[part]={Material=part.Material,TextureID=part.TextureID} end) end\n"
        "                    pcall(function()\n"
        "                        local m=glowing and Enum.Material.Neon or Enum.Material.SmoothPlastic\n"
        "                        if part.Material~=m then part.Material=m end\n"
        "                        if part.TextureID~='' then part.TextureID='' end\n"
        "                    end)\n"
        "                end\n"
        "                for part,w in pairs(entries) do\n"
        "                    if not wanted[part] then\n"
        "                        self.runtime:RemoveWire(w); entries[part]=nil\n"
        "                        local look=looks[part]\n"
        "                        if look then pcall(function() part.Material=look.Material; part.TextureID=look.TextureID end); looks[part]=nil end\n"
        "                    end\n"
        "                end\n")

    # --- Bloom: visible defaults, and catch game bloom in the camera too ---------
    text = swap(text,
        "                            Intensity = {'P1S6S1', 0.4}, -- Frekks's serialized default was erased; 0.4 is the explicit fallback.\n"
        "                            Size = {'P1S6S2', 24},\n"
        "                            Threshold = {'P1S6S3', 0.95},\n",
        "                            Intensity = {'P1S6S1', 1},\n"
        "                            Size = {'P1S6S2', 32},\n"
        "                            Threshold = {'P1S6S3', 0.6},\n")
    text = swap(text,
        "                    Text = 'Intensity', Default = 0.4, Min = 0, Max = 1, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepBloom:AddSlider('P1S6S2', {\n"
        "                    Text = 'Size', Default = 24, Min = 0, Max = 56, Rounding = 0, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepBloom:AddSlider('P1S6S3', {\n"
        "                    Text = 'Threshold', Default = 0.95, Min = 0, Max = 5, Rounding = 2, Compact = true,\n",
        "                    Text = 'Intensity', Default = 1, Min = 0, Max = 1, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepBloom:AddSlider('P1S6S2', {\n"
        "                    Text = 'Size', Default = 32, Min = 0, Max = 56, Rounding = 0, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepBloom:AddSlider('P1S6S3', {\n"
        "                    Text = 'Threshold', Default = 0.6, Min = 0, Max = 4, Rounding = 2, Compact = true,\n"
        "                    Tooltip = 'Lower = more of the screen glows. Around 0.4-0.8 is clearly visible.',\n")
    text = swap(text,
        "                for _, descendant in ipairs(world.Lighting:GetDescendants()) do\n"
        "                    if descendant.ClassName == className and descendant ~= owned then\n"
        "                        world.GuardNativeEffect(className, descendant)\n"
        "                    end\n"
        "                end\n",
        "                local scan = world.Lighting:GetDescendants()\n"
        "                local camera = Workspace.CurrentCamera\n"
        "                if camera then\n"
        "                    -- the game also keeps post effects on the camera; they stack with ours\n"
        "                    for _, descendant in ipairs(camera:GetChildren()) do scan[#scan + 1] = descendant end\n"
        "                end\n"
        "                for _, descendant in ipairs(scan) do\n"
        "                    if descendant.ClassName == className and descendant ~= owned then\n"
        "                        world.GuardNativeEffect(className, descendant)\n"
        "                    end\n"
        "                end\n"
        "                if owned and owned.Parent and not owned.Enabled then pcall(function() owned.Enabled = true end) end\n")

    # --- Snow: soft white balls, far more of them ---------------------------------
    old_snow = text[text.index("                    Snow = {\n                        {Texture = 'rbxassetid://119455261341623'"):]
    old_snow = old_snow[:old_snow.index("                    },\n") + len("                    },\n")]
    text = swap(text, old_snow,
        "                    Snow = {\n"
        "                        -- round white balls (Library.Assets.snowball), three depth layers\n"
        "                        {Texture = 'ball', BaseRate = 220, SpeedMin = 5, SpeedMax = 9, SizeStart = 0.16, SizeEnd = 0.16, TransparencyMax = 0.05, LifetimeMin = 6, LifetimeMax = 9, RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0, BaseSpread = 6, BaseAccelerationY = -1.5},\n"
        "                        {Texture = 'ball', BaseRate = 160, SpeedMin = 7, SpeedMax = 11, SizeStart = 0.26, SizeEnd = 0.26, TransparencyMax = 0.1, LifetimeMin = 5, LifetimeMax = 8, RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0, BaseSpread = 8, BaseAccelerationY = -2},\n"
        "                        {Texture = 'ball', BaseRate = 70, SpeedMin = 9, SpeedMax = 13, SizeStart = 0.4, SizeEnd = 0.4, TransparencyMax = 0.2, LifetimeMin = 4, LifetimeMax = 6, RotationMin = 0, RotationMax = 0, RotationSpeedMin = 0, RotationSpeedMax = 0, BaseSpread = 10, BaseAccelerationY = -2.5},\n"
        "                    },\n")
    text = swap(text,
        "                    emitter.Texture = spec.Texture\n",
        "                    if spec.Texture == 'ball' then\n"
        "                        emitter.Texture = world.SnowballTexture()\n"
        "                        emitter.Squash = NumberSequence.new(0)\n"
        "                    else\n"
        "                        emitter.Texture = spec.Texture\n"
        "                    end\n")
    text = swap(text,
        "            function RivalsRuntimeBridge.WorldVisuals.RebuildWeather(preset)\n",
        "            -- soft white ball for the snow particles, written once to the workspace\n"
        "            function RivalsRuntimeBridge.WorldVisuals.SnowballTexture()\n"
        "                local world = RivalsRuntimeBridge.WorldVisuals\n"
        "                if world.SnowballAsset then return world.SnowballAsset end\n"
        "                local fallback = 'rbxasset://textures/particles/sparkles_main.dds'\n"
        "                local ok, asset = pcall(function()\n"
        "                    local getasset = getcustomasset or getsynasset\n"
        "                    if type(getasset) ~= 'function' or type(writefile) ~= 'function' then return nil end\n"
        "                    local path = 'FrekksHail/snowball.png'\n"
        "                    if not (type(isfile) == 'function' and isfile(path)) then\n"
        "                        if type(makefolder) == 'function' and not (type(isfolder) == 'function' and isfolder('FrekksHail')) then pcall(makefolder, 'FrekksHail') end\n"
        "                        local data = '" + SNOWBALL + "'\n"
        "                        local map, out = {}, {}\n"
        "                        local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'\n"
        "                        for i = 1, 64 do map[alphabet:byte(i)] = i - 1 end\n"
        "                        for i = 1, #data, 4 do\n"
        "                            local a, b, c, d = data:byte(i, i + 3)\n"
        "                            local n = map[a] * 262144 + map[b] * 4096 + (map[c] or 0) * 64 + (map[d] or 0)\n"
        "                            out[#out + 1] = string.char(math.floor(n / 65536) % 256)\n"
        "                            if c ~= 61 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end\n"
        "                            if d ~= 61 then out[#out + 1] = string.char(n % 256) end\n"
        "                        end\n"
        "                        writefile(path, table.concat(out))\n"
        "                    end\n"
        "                    return getasset(path)\n"
        "                end)\n"
        "                world.SnowballAsset = ok and type(asset) == 'string' and asset ~= '' and asset or fallback\n"
        "                return world.SnowballAsset\n"
        "            end\n\n"
        "            function RivalsRuntimeBridge.WorldVisuals.RebuildWeather(preset)\n")
    text = swap(text,
        "                    Text = 'Intensity', Default = 1, Min = 0, Max = 2, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(WeatherSettings:AddSlider('P1S28S2', {\n"
        "                    Text = 'Rate', Default = 1, Min = 0, Max = 3, Rounding = 2, Compact = true,\n",
        "                    Text = 'Intensity', Default = 1, Min = 0, Max = 10, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(WeatherSettings:AddSlider('P1S28S2', {\n"
        "                    Text = 'Amount', Default = 1, Min = 0, Max = 25, Rounding = 1, Compact = true,\n"
        "                    Tooltip = 'How many particles fall. Snow at 25x is a total whiteout; high values cost FPS.',\n")
    text = swap(text,
        "                    Text = 'Size', Default = 1, Min = 0.5, Max = 2, Rounding = 2, Compact = true,\n",
        "                    Text = 'Size', Default = 1, Min = 0.2, Max = 4, Rounding = 2, Compact = true,\n")
    text = swap(text,
        "                    Text = 'Speed', Default = 1, Min = 0.5, Max = 3, Rounding = 2, Compact = true,\n",
        "                    Text = 'Speed', Default = 1, Min = 0.1, Max = 4, Rounding = 2, Compact = true,\n")
    text = swap(text, "                    part.Size = Vector3.new(140, 1, 140)\n", "                    part.Size = Vector3.new(180, 1, 180)\n")

    # --- Atmosphere: full ranges and nicer defaults --------------------------------
    text = swap(text,
        "                    Text = 'Glare', Default = 0, Min = 0, Max = 1, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepAtmosphere:AddSlider('P1S13S4', {\n"
        "                    Text = 'Haze', Default = 0, Min = 0, Max = 1, Rounding = 2, Compact = true,\n",
        "                    Text = 'Glare', Default = 0.8, Min = 0, Max = 10, Rounding = 2, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepAtmosphere:AddSlider('P1S13S4', {\n"
        "                    Text = 'Haze', Default = 1.8, Min = 0, Max = 10, Rounding = 2, Compact = true,\n")
    text = swap(text,
        "                    Text = 'Density', Default = 0.395, Min = 0, Max = 1, Rounding = 3, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepAtmosphere:AddSlider('P1S13S2', {\n"
        "                    Text = 'Offset', Default = 0, Min = 0, Max = 1, Rounding = 2, Compact = true,\n",
        "                    Text = 'Density', Default = 0.32, Min = 0, Max = 1, Rounding = 3, Compact = true,\n"
        "                }))\n"
        "                BindWorldVisualOption(DepAtmosphere:AddSlider('P1S13S2', {\n"
        "                    Text = 'Offset', Default = 0.25, Min = 0, Max = 1, Rounding = 2, Compact = true,\n")
    text = swap(text,
        "                    Density = world.ReadOption('P1S13S1', 0.395),\n"
        "                    Offset = world.ReadOption('P1S13S2', 0),\n"
        "                    Glare = world.ReadOption('P1S13S3', 0),\n"
        "                    Haze = world.ReadOption('P1S13S4', 0),\n",
        "                    Density = world.ReadOption('P1S13S1', 0.32),\n"
        "                    Offset = world.ReadOption('P1S13S2', 0.25),\n"
        "                    Glare = world.ReadOption('P1S13S3', 0.8),\n"
        "                    Haze = world.ReadOption('P1S13S4', 1.8),\n")
    # three new atmospheric themes
    text = swap(text,
        "            RivalsRuntimeBridge.WorldVisuals.WorldPresetOrder = {\n"
        "                'Game Default', 'Competitive Clarity', 'Sunny Day', 'Golden Hour',\n",
        "            RivalsRuntimeBridge.WorldVisuals.WorldPresetOrder = {\n"
        "                'Game Default', 'Competitive Clarity', 'Dreamy Haze', 'Sakura Sunset', 'Frozen Night', 'Sunny Day', 'Golden Hour',\n")
    # new themes are added after the WorldPresets table exists
    text = swap(text,
        "            function RivalsRuntimeBridge.WorldVisuals.ApplyWorldPreset(name)\n",
        "            RivalsRuntimeBridge.WorldVisuals.WorldPresets['Dreamy Haze'] = {\n"
        "                Toggles = { P1S4T2 = true, P1S4T3 = true, P1S4T4 = true, P1S4T5 = true, P1S4T7 = true,\n"
        "                    P1S6T1 = true, P1S7T1 = true, P1S10T1 = true, P1S13T1 = true },\n"
        "                Options = { P1S4S1 = 17.6, P1S4S2 = 2.2, P1S4S4 = 0.15, P1S6S1 = 0.8, P1S6S2 = 40, P1S6S3 = 0.7,\n"
        "                    P1S7S1 = 0.12, P1S7S2 = 0.03, P1S7S3 = 0.08, P1S10S1 = 0.18, P1S10S2 = 0.6,\n"
        "                    P1S13S1 = 0.34, P1S13S2 = 0.3, P1S13S3 = 1.6, P1S13S4 = 2.4 },\n"
        "                Colors = { P1S4C1 = {150, 120, 160}, P1S4C2 = {200, 160, 200}, P1S4C3 = {255, 200, 230}, P1S4C4 = {170, 140, 210},\n"
        "                    P1S7C1 = {255, 235, 245}, P1S13C1 = {255, 190, 225}, P1S13C2 = {150, 90, 160} },\n"
        "            }\n"
        "            RivalsRuntimeBridge.WorldVisuals.WorldPresets['Frozen Night'] = {\n"
        "                Toggles = { P1S4T2 = true, P1S4T3 = true, P1S4T4 = true, P1S4T5 = true, P1S4T7 = true,\n"
        "                    P1S6T1 = true, P1S7T1 = true, P1S13T1 = true },\n"
        "                Options = { P1S4S1 = 22, P1S4S2 = 1.4, P1S4S4 = 0.25, P1S6S1 = 0.7, P1S6S2 = 36, P1S6S3 = 0.65,\n"
        "                    P1S7S1 = -0.05, P1S7S2 = 0.02, P1S7S3 = 0.1, P1S13S1 = 0.38, P1S13S2 = 0.2, P1S13S3 = 0.6, P1S13S4 = 2 },\n"
        "                Colors = { P1S4C1 = {90, 110, 150}, P1S4C2 = {140, 165, 210}, P1S4C3 = {200, 225, 255}, P1S4C4 = {90, 110, 170},\n"
        "                    P1S7C1 = {225, 238, 255}, P1S13C1 = {190, 215, 255}, P1S13C2 = {80, 100, 150} },\n"
        "            }\n"
        "            RivalsRuntimeBridge.WorldVisuals.WorldPresets['Sakura Sunset'] = {\n"
        "                Toggles = { P1S4T2 = true, P1S4T3 = true, P1S4T4 = true, P1S4T5 = true, P1S4T7 = true,\n"
        "                    P1S6T1 = true, P1S7T1 = true, P1S10T1 = true, P1S13T1 = true },\n"
        "                Options = { P1S4S1 = 18.4, P1S4S2 = 2.6, P1S4S4 = 0.1, P1S6S1 = 0.9, P1S6S2 = 44, P1S6S3 = 0.55,\n"
        "                    P1S7S1 = 0.18, P1S7S2 = 0.02, P1S7S3 = 0.1, P1S10S1 = 0.3, P1S10S2 = 0.5,\n"
        "                    P1S13S1 = 0.3, P1S13S2 = 0.2, P1S13S3 = 2.2, P1S13S4 = 1.6 },\n"
        "                Colors = { P1S4C1 = {150, 100, 120}, P1S4C2 = {230, 160, 170}, P1S4C3 = {255, 180, 140}, P1S4C4 = {180, 110, 170},\n"
        "                    P1S7C1 = {255, 228, 228}, P1S13C1 = {255, 170, 150}, P1S13C2 = {180, 80, 120} },\n"
        "            }\n"
        "            function RivalsRuntimeBridge.WorldVisuals.ApplyWorldPreset(name)\n")
    return feedback_and_cosmetics(text)


PLAY_SOUND = r"""            -- Sounds are preloaded once per name and cloned per hit. A sound the game is not
            -- allowed to load (private audio) falls back to an engine sound instead of silence.
            function RivalsRuntimeBridge.CombatFeedback.PlaySound(name, volume, pitch)
                local feedback = RivalsRuntimeBridge.CombatFeedback
                local asset = feedback.ResolveSoundAsset(name)
                if not asset then
                    return
                end
                local soundService = game:GetService('SoundService')
                feedback.SoundTemplates = feedback.SoundTemplates or {}
                local function make(id)
                    local ok, sound = pcall(function()
                        local s = Instance.new('Sound')
                        s.Name = 'FrekksHailCombatFeedback'
                        s.SoundId = id
                        s.Parent = soundService
                        return s
                    end)
                    if not ok and type(__FrekksHailElevateIdentity) == 'function' then
                        pcall(__FrekksHailElevateIdentity)
                        ok, sound = pcall(function()
                            local s = Instance.new('Sound')
                            s.Name = 'FrekksHailCombatFeedback'
                            s.SoundId = id
                            s.Parent = soundService
                            return s
                        end)
                    end
                    return ok and sound or nil
                end
                local record = feedback.SoundTemplates[name]
                if not record or record.Asset ~= asset or not record.Sound or record.Sound.Parent == nil then
                    record = { Asset = asset, Sound = make(asset), Born = os.clock(), Failed = false }
                    feedback.SoundTemplates[name] = record
                end
                local template = record.Sound
                if template and not record.Failed and not template.IsLoaded and os.clock() - record.Born > 2.5 then
                    record.Failed = true
                    pcall(function()
                        Library:Notify('Hit sound "' .. tostring(name) .. '" could not be loaded in this game. Playing the default ping instead.', 5)
                    end)
                end
                if not template or record.Failed then
                    local fallback = feedback.SoundTemplates['\0fallback']
                    if not fallback or not fallback.Sound or fallback.Sound.Parent == nil then
                        fallback = { Sound = make('rbxasset://sounds/electronicpingshort.wav') }
                        feedback.SoundTemplates['\0fallback'] = fallback
                    end
                    template = fallback.Sound
                end
                if not template then
                    return
                end
                pcall(function()
                    local sound = template:Clone()
                    sound.Volume = math.max(0, tonumber(volume) or 1)
                    sound.PlaybackSpeed = math.max(0.01, tonumber(pitch) or 1)
                    sound.Parent = soundService
                    game:GetService('Debris'):AddItem(sound, 12)
                    sound:Play()
                end)
            end

"""


def feedback_and_cosmetics(text):
    # --- Hit sounds -----------------------------------------------------------------
    text = between(text,
        "            function RivalsRuntimeBridge.CombatFeedback.PlaySound(name, volume, pitch)\n",
        "            function RivalsRuntimeBridge.CombatFeedback.CreateChams(", PLAY_SOUND)
    text = swap(text,
        "                BuiltInSounds = {\n",
        "                BuiltInSounds = {\n"
        "                    -- engine sounds: always available, no asset permissions involved\n"
        "                    { name = 'Ping (always works)', soundId = 'rbxasset://sounds/electronicpingshort.wav' },\n"
        "                    { name = 'Snap (always works)', soundId = 'rbxasset://sounds/snap.mp3' },\n"
        "                    { name = 'Click (always works)', soundId = 'rbxasset://sounds/clickfast.wav' },\n"
        "                    { name = 'Bass (always works)', soundId = 'rbxasset://sounds/bass.wav' },\n"
        "                    { name = 'Classic Oof (always works)', soundId = 'rbxasset://sounds/uuhhh.mp3' },\n"
        "                    { name = 'Sword Slash (always works)', soundId = 'rbxasset://sounds/swordslash.wav' },\n")

    # --- Cosmetics window ----------------------------------------------------------
    text = swap(text,
        "    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global;\n    gui.Parent = coreGui;\n",
        "    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global;\n"
        "    pcall(function() gui.IgnoreGuiInset = true end);\n"
        "    do\n"
        "        -- parent like the menu does: hidden UI, then CoreGui with raised identity, then PlayerGui\n"
        "        local function try(getParent)\n"
        "            return pcall(function() gui.Parent = getParent() end) and gui.Parent ~= nil\n"
        "        end\n"
        "        local placed = type(gethui) == 'function' and try(gethui)\n"
        "        if not placed then placed = try(function() return coreGui end) end\n"
        "        if not placed and type(__FrekksHailElevateIdentity) == 'function' then\n"
        "            pcall(__FrekksHailElevateIdentity)\n"
        "            placed = try(function() return coreGui end)\n"
        "        end\n"
        "        if not placed then try(function() return ctx.player:FindFirstChildOfClass('PlayerGui') end) end\n"
        "    end\n")
    text = swap(text, "    outer.Draggable = true;\n", "")
    text = swap(text,
        "    title.Text = \"Frekks Hail v3 | Cosmetics\";\n    title.Parent = top;\n",
        "    title.Text = \"Frekks Hail v3 | Cosmetics\";\n    title.Parent = top;\n"
        "    do\n"
        "        -- drag by the title bar only, so lists and buttons do not move the window\n"
        "        local dragStart, dragOrigin\n"
        "        top.Active = true\n"
        "        top.InputBegan:Connect(function(input)\n"
        "            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then\n"
        "                dragStart, dragOrigin = input.Position, outer.Position\n"
        "            end\n"
        "        end)\n"
        "        local dragMove = userInput.InputChanged:Connect(function(input)\n"
        "            if not dragStart or resizing then return end\n"
        "            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then\n"
        "                local delta = input.Position - dragStart\n"
        "                outer.Position = UDim2.new(dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X, dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y)\n"
        "            end\n"
        "        end)\n"
        "        local dragEnd = userInput.InputEnded:Connect(function(input)\n"
        "            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end\n"
        "        end)\n"
        "        Library:GiveSignal(dragMove); Library:GiveSignal(dragEnd)\n"
        "        gui.Destroying:Connect(function() dragMove:Disconnect(); dragEnd:Disconnect() end)\n"
        "        -- rounded corners to match the menu\n"
        "        for frame, radius in pairs({ [outer] = 10, [inner] = 9, [panel] = 8, [top] = 8 }) do\n"
        "            local corner = Instance.new('UICorner'); corner.CornerRadius = UDim.new(0, radius); corner.Parent = frame\n"
        "        end\n"
        "        accentBar.Position = UDim2.new(0, 10, 0, 0); accentBar.Size = UDim2.new(1, -20, 0, 2)\n"
        "        local resizerCorner = Instance.new('UICorner'); resizerCorner.CornerRadius = UDim.new(0, 4); resizerCorner.Parent = resizer\n"
        "    end\n")
    text = swap(text,
        "        outer.BackgroundColor3 = Color3.new(0, 0, 0);\n        inner.BackgroundColor3 = main;\n",
        "        outer.BackgroundColor3 = accent:Lerp(outline, 0.55);\n        inner.BackgroundColor3 = main;\n")
    return text


def main():
    original = open(sys.argv[1], encoding="utf-8").read()
    text = visuals(original)  # the file's own UI module (with its edits) is kept as-is
    text = fixes_v3b.apply(text)
    text = fixes_wire.apply(text)
    open(sys.argv[2], "w", encoding="utf-8").write(text)
    print("in", len(original), "out", len(text))


if __name__ == "__main__":
    main()
