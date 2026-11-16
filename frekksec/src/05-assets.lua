-- Images: the frekksec.lua logo (embedded, split into a white text layer and a white
-- glow layer so the glow can be recoloured) and the baked-blur "frost" backdrops that
-- stand in for UIBlur. Both need writefile + getcustomasset; without them the window
-- falls back to a text title and tinted panels.
local loadFrekksecAssets
do
    local LOGO_TEXT = "__LOGO_TEXT_B64__"
    local LOGO_GLOW = "__LOGO_GLOW_B64__"
    local FROST_URL = "https://raw.githubusercontent.com/282882yea/e/claude/executor-ui-tabs-pixeled-aww4ux/frekksec/assets/"
    local FOLDER = "frekksec/assets"
    local VERSION = "v1"

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local function decode(text)
        local value = {}
        for i = 1, 64 do value[string.byte(B64, i)] = i - 1 end
        local out, chunk = {}, {}
        local bits, count = 0, 0
        for i = 1, #text do
            local v = value[string.byte(text, i)]
            if v then
                bits = bits * 64 + v
                count = count + 6
                if count >= 8 then
                    count = count - 8
                    local p = 2 ^ count
                    local byte = math.floor(bits / p)
                    bits = bits - byte * p
                    chunk[#chunk + 1] = string.char(byte)
                    if #chunk >= 4096 then
                        out[#out + 1] = table.concat(chunk)
                        chunk = {}
                    end
                end
            end
        end
        out[#out + 1] = table.concat(chunk)
        return table.concat(out)
    end

    function loadFrekksecAssets()
        local function fn(value) return type(value) == "function" and value or nil end
        local writefile, isfile, makefolder, isfolder = fn(writefile), fn(isfile), fn(makefolder), fn(isfolder)
        local asset = fn(getcustomasset) or fn(getsynasset)
        local assets = {}
        if not (writefile and asset) then return assets end
        pcall(function()
            if makefolder and not (isfolder and isfolder("frekksec")) then makefolder("frekksec") end
            if makefolder and not (isfolder and isfolder(FOLDER)) then makefolder(FOLDER) end
        end)
        local function save(name, data)
            local path = FOLDER .. "/" .. name
            local ok, id = pcall(function()
                if not (isfile and isfile(path)) then writefile(path, data) end
                return asset(path)
            end)
            return ok and type(id) == "string" and id ~= "" and id or nil
        end

        local text = save("logo-text-" .. VERSION .. ".png", decode(LOGO_TEXT))
        local glow = save("logo-glow-" .. VERSION .. ".png", decode(LOGO_GLOW))
        if text and glow then
            assets.Logo = {Image = text, Glow = glow, Width = 448, Height = 110}
        end

        -- Frost images are fetched once in the background, then read from the cache.
        assets.Frost = {Width = 1006, Height = 586, ImageWidth = 252, ImageHeight = 147, Images = {}}
        function assets:FetchFrost(onReady)
            task.spawn(function()
                for _, scene in ipairs({"Dusk", "Night", "Day"}) do
                    local set = {}
                    for _, level in ipairs({"Light", "Medium", "Heavy"}) do
                        local file = ("frost-%s-%s.png"):format(scene:lower(), level:lower())
                        local path = FOLDER .. "/" .. VERSION .. "-" .. file
                        local cached = isfile and pcall(isfile, path) and isfile(path)
                        if not cached then
                            local ok, body = pcall(function() return game:HttpGet(FROST_URL .. file) end)
                            if ok and type(body) == "string" and body:sub(2, 4) == "PNG" then
                                pcall(writefile, path, body)
                                cached = true
                            end
                        end
                        if cached then
                            local ok, id = pcall(asset, path)
                            if ok and type(id) == "string" and id ~= "" then set[level] = id end
                        end
                    end
                    self.Frost.Images[scene] = set
                    if onReady then onReady() end
                end
            end)
        end
        return assets
    end
end
