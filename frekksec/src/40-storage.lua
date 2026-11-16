local function makeFrekksecStorage(schema, d)
    local S = {Root = "frekksec_lua", Preferences = {}}
    local definitions = {}
    for _, def in ipairs(schema) do definitions[def.key] = def end
    local function need(key)
        local fn = d[key]
        if type(fn) ~= "function" then error("Your executor does not provide " .. key .. ".", 0) end
        return fn
    end
    local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
    function S:Name(value)
        if type(value) ~= "string" then error("Enter or select a name first.", 0) end
        local name = value:match("^%s*(.-)%s*$")
        if name == "" or #name > 64 or name:find('[<>:"/\\|?*%c]') or name:sub(-1) == "."
            or name == "." or name == ".." then
            error("Use 1–64 characters without path separators or special filename characters.", 0)
        end
        local base = name:match("^[^.]+") or name
        if ({CON=true,PRN=true,AUX=true,NUL=true})[base:upper()]
            or base:upper():match("^COM[1-9]$") or base:upper():match("^LPT[1-9]$") then
            error("That filename is reserved. Choose another name.", 0)
        end
        return name
    end
    local function folder(kind)
        assert(kind == "configs" or kind == "themes", "Invalid storage category")
        return S.Root .. "/" .. kind
    end
    local function path(kind, name) return folder(kind) .. "/" .. S:Name(name) .. ".json" end
    local function ensure()
        local exists, mkdir = need("isfolder"), need("makefolder")
        for _, dir in ipairs({S.Root, folder("configs"), folder("themes")}) do
            if not exists(dir) then mkdir(dir) end
        end
    end
    local function decode(text)
        if type(text) ~= "string" or #text > 262144 then error("Config text is missing or exceeds 256 KB.", 0) end
        local ok, data = pcall(d.decode, text)
        if not ok or type(data) ~= "table" then error("Invalid JSON. Paste the full exported config.", 0) end
        return data
    end
    local function read(file)
        if not need("isfile")(file) then error("File not found: " .. file, 0) end
        return decode(need("readfile")(file))
    end
    local function write(file, data)
        local encoded = d.encode(data)
        ensure()
        need("writefile")(file, encoded)
    end
    function S:List(kind)
        local dir = folder(kind)
        if not need("isfolder")(dir) then return {} end
        local names, seen = {}, {}
        for _, file in ipairs(need("listfiles")(dir)) do
            local normalized = tostring(file):gsub("\\", "/")
            local name = normalized:match("([^/]+)%.json$")
            local ok, clean = pcall(self.Name, self, name)
            if ok and clean == name and need("isfile")(path(kind, clean)) and not seen[clean:lower()] then
                seen[clean:lower()] = true
                table.insert(names, clean)
            end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end
    function S:ValidateSettings(settings)
        if type(settings) ~= "table" then error("This is not a frekksec settings object.", 0) end
        for key in pairs(settings) do
            if not definitions[key] then error("Unknown frekksec setting: " .. tostring(key), 0) end
        end
        local modes={OrbitEnabled="Orbit",VoidTPEnabled="Void TP",VoidHideEnabled="Void Hide",
            JitterEnabled="Jitter",StrafeEnabled="Strafe",SphereEnabled="Random sphere"}
        local hasModeSwitch=false
        for key in pairs(modes) do if settings[key]~=nil then hasModeSwitch=true;break end end
        local clean = {}
        for _, def in ipairs(schema) do
            local value = settings[def.key]
            if value == nil then
                if hasModeSwitch and modes[def.key] then value=false else value=def.default end
            end
            if def.aliases and type(value)=="string" then value=def.aliases[value] or value end
            local valid = type(value) == type(def.default)
            if type(def.default) == "number" then
                valid = valid and finite(value) and value >= def.min and value <= def.max
            elseif type(def.default) == "string" then
                valid = valid and #value <= 80 and (not def.values or table.find(def.values, value) ~= nil)
                    and (not def.pattern or value:match(def.pattern)~=nil)
            end
            if not valid then error("Invalid value for " .. def.key .. "; no settings were loaded.", 0) end
            if def.fixed~=nil then value=def.fixed end
            clean[def.key] = value
        end
        if not hasModeSwitch then
            for key,mode in pairs(modes) do
                clean[key]=clean.Mode==mode or clean.Mode=="Hybrid" and (mode=="Orbit" or mode=="Void TP")
            end
        end
        clean.Enabled = false
        return clean
    end
    function S:DecodeConfig(text)
        local data = decode(text)
        if not ((data.Version == 2 and data.Script == "frekksec lua") or data.Version == 1) then
            error("Unsupported config. Use a frekksec lua config, not a Frekks Hail config.", 0)
        end
        return self:ValidateSettings(data.Settings)
    end
    function S:ReadConfig(name)
        local file = path("configs", name)
        if not need("isfile")(file) then error("Select an existing config.", 0) end
        return self:DecodeConfig(need("readfile")(file))
    end
    function S:SaveConfig(name, settings, overwrite)
        name = self:Name(name)
        local file = path("configs", name)
        local exists = need("isfile")(file)
        if exists and not overwrite then error("That config already exists. Use Save / overwrite config.", 0) end
        if overwrite and not exists then error("Select an existing config, or use Create config first.", 0) end
        write(file, {Script="frekksec lua", Version=2, Name=name, Settings=self:ValidateSettings(settings)})
        return name
    end
    function S:ExportConfig(name, current)
        local settings = name and self:ReadConfig(name) or self:ValidateSettings(current)
        return d.encode({Script="frekksec lua", Version=2, Name=name or "Exported config", Settings=settings})
    end
    function S:ImportConfig(name, text)
        return self:SaveConfig(name, self:DecodeConfig(text), false)
    end
    function S:ImportLegacy(name)
        local file = "frekksec_lua_config.json"
        if not need("isfile")(file) then error("No previous frekksec_lua_config.json found.", 0) end
        return self:ImportConfig(name, need("readfile")(file))
    end
    function S:SavePreferences(changes)
        local nextPrefs = table.clone(self.Preferences)
        for key, value in pairs(changes) do nextPrefs[key] = value end
        write(self.Root .. "/preferences.json", {Version=1, Preferences=nextPrefs})
        self.Preferences = nextPrefs
    end
    function S:GetAutoload()
        local name = self.Preferences.Autoload
        if type(name) ~= "string" or name == "" then return nil end
        local ok, exists = pcall(function() return need("isfile")(path("configs", name)) end)
        return ok and exists and name or nil
    end
    function S:SetAutoload(name)
        if name ~= nil then name = self:Name(name); self:ReadConfig(name) end
        self:SavePreferences({Autoload=name or ""})
    end
    function S:DeleteConfig(name)
        name = self:Name(name)
        local file = path("configs", name)
        if not need("isfile")(file) then error("Select an existing config.", 0) end
        local remove = need("delfile")
        if self.Preferences.Autoload == name then self:SetAutoload(nil) end
        remove(file)
    end
    function S:ValidateTheme(colors)
        if type(colors) ~= "table" then error("Invalid theme colors.", 0) end
        local clean = {}
        for _, key in ipairs({"MainColor","AccentColor","BackgroundColor","OutlineColor","FontColor","SurfaceGlowColor","ControlGlowColor","LogoGlowColor"}) do
            local rgb = colors[key]
            if rgb == nil and (key == "SurfaceGlowColor" or key == "ControlGlowColor") then rgb = colors.AccentColor end
            if rgb == nil and key == "LogoGlowColor" then rgb = {180, 124, 255} end
            if type(rgb) ~= "table" or #rgb ~= 3 then error("Theme is missing " .. key, 0) end
            clean[key] = {}
            for i=1,3 do
                if not finite(rgb[i]) or rgb[i] < 0 or rgb[i] > 255 then error("Invalid color: " .. key, 0) end
                clean[key][i] = math.floor(rgb[i] + 0.5)
            end
        end
        return clean
    end
    function S:ReadTheme(name)
        local data = read(path("themes", name))
        if data.Version ~= 1 or data.Script ~= "frekksec lua" then error("Unsupported theme.", 0) end
        return self:ValidateTheme(data.Colors)
    end
    function S:SaveTheme(name, colors, overwrite)
        name = self:Name(name)
        local file = path("themes", name)
        local exists = need("isfile")(file)
        if exists and not overwrite then error("That theme already exists. Use Overwrite theme.", 0) end
        if overwrite and not exists then error("Select an existing theme first.", 0) end
        write(file, {Script="frekksec lua", Version=1, Colors=self:ValidateTheme(colors)})
        return name
    end
    function S:DeleteTheme(name)
        name = self:Name(name)
        local file = path("themes", name)
        if not need("isfile")(file) then error("Select an existing theme first.", 0) end
        local remove = need("delfile")
        local default = self.Preferences.DefaultTheme
        if type(default) == "table" and default.Kind == "custom" and default.Name == name then
            self:SavePreferences({DefaultTheme=false})
        end
        remove(file)
    end
    local ok, result = pcall(function()
        local file = S.Root .. "/preferences.json"
        if type(d.isfile) ~= "function" or not d.isfile(file) then return {} end
        local data = read(file)
        if data.Version ~= 1 or type(data.Preferences) ~= "table" then error("Invalid saved UI preferences.", 0) end
        return data.Preferences
    end)
    if ok then S.Preferences = result else S.StartupWarning = tostring(result) end
    return S
end

