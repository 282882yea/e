---------------------------------------------------------------------
-- Library facade (Linoria / Obsidian compatible)
---------------------------------------------------------------------

Library.Theme = Theme
Library.Assets = Assets -- image ids, e.g. Library.Assets.snowball for the weather particles
Library.FontColor = BASE.font
Library.MainColor = BASE.main
Library.AccentColor = BASE.accent
Library.BackgroundColor = BASE.background
Library.OutlineColor = BASE.outline
Library.RiskColor = rgb(255, 90, 120)
Library.Black = BLACK
Library.AccentColorDark = BASE.accent:Lerp(BLACK, 0.28)

-- Some feature code reads Library.Scheme.*; keep it live.
Library.Scheme = setmetatable({}, {
	__index = function(_, key)
		if key == "MainColor" or key == "BackgroundColor" or key == "AccentColor" or key == "OutlineColor" or key == "FontColor" or key == "RiskColor" then
			return Library[key]
		end
		return nil
	end,
	__newindex = function(t, key, value)
		if key == "MainColor" or key == "BackgroundColor" or key == "AccentColor" or key == "OutlineColor" or key == "FontColor" or key == "RiskColor" then
			Library[key] = value
			Library:UpdateColorsUsingRegistry()
		else
			rawset(t, key, value)
		end
	end,
})

function Library:GetDarkerColor(color)
	local h, s, v = Color3.toHSV(color)
	return Color3.fromHSV(h, s, v / 1.45)
end

function Library:UpdateColorsUsingRegistry()
	local function c(value, fallback)
		return typeof(value) == "Color3" and value or fallback
	end
	self.AccentColorDark = self:GetDarkerColor(c(self.AccentColor, BASE.accent))
	Theme.Risk = c(self.RiskColor, Theme.Risk)
	setScheme({
		font = c(self.FontColor, BASE.font),
		main = c(self.MainColor, BASE.main),
		accent = c(self.AccentColor, BASE.accent),
		background = c(self.BackgroundColor, BASE.background),
		outline = c(self.OutlineColor, BASE.outline),
	})
	local window = self.ActiveWindow
	if window and window._alive then
		window:_refreshKeybinds()
		if window.Visible then
			window:_restartLoops()
		end
	end
end

function Library:SetNotifySide(side)
	self.NotifySide = tostring(side or "Right")
	if self.ActiveWindow and self.ActiveWindow._alive then
		self.ActiveWindow:SetNotifySide(self.NotifySide)
	end
end

function Library:Notify(message, duration, kind)
	local window = self.ActiveWindow
	if not window or not window._alive then
		return
	end
	return window:Notify(message, duration, kind)
end

function Library:GiveSignal(connection)
	if connection then
		table.insert(self.Signals, connection)
	end
	return connection
end

function Library:OnUnload(callback)
	if type(callback) == "function" then
		table.insert(self.UnloadSignals, callback)
	end
end

function Library:Toggle(value)
	local window = self.ActiveWindow
	if not window or not window._alive then
		return
	end
	if value == nil then
		window:Toggle()
	else
		window:SetVisible(value == true)
	end
end

function Library:SafeCallback(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local result = table.pack(pcall(fn, ...))
	if not result[1] then
		warn("[Lunar] callback error: " .. tostring(result[2]))
		return nil
	end
	return table.unpack(result, 2, result.n)
end

-- Rich-text title with one word in the accent colour (used by the cosmetics window).
function Library:SetAccentTitle(label, title, accentWord)
	if typeof(label) ~= "Instance" or not label:IsA("TextLabel") then
		return
	end
	title = tostring(title or label.Text)
	accentWord = tostring(accentWord or "")
	local accent = Theme.Accent
	local hex = string.format("#%02X%02X%02X", round(accent.R * 255), round(accent.G * 255), round(accent.B * 255))
	local function escape(text)
		return (string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
	end
	local text = escape(title)
	if accentWord ~= "" then
		local a, b = string.find(title, accentWord, 1, true)
		if a then
			text = escape(string.sub(title, 1, a - 1)) .. '<font color="' .. hex .. '">' .. escape(accentWord) .. "</font>" .. escape(string.sub(title, b + 1))
		end
	end
	label.RichText = true
	label.Text = text
	label.TextColor3 = Theme.Text
end

function Library:SetGlowStrength(value)
	self.GlowStrength = math.clamp(tonumber(value) or 0.2, 0, 1)
	if self.ActiveWindow and self.ActiveWindow._alive then
		self.ActiveWindow:SetGlowStrength(self.GlowStrength)
	else
		refreshGlows()
	end
end

function Library:Unload()
	if self.Unloaded then
		return
	end
	for _, callback in ipairs(self.UnloadSignals) do
		pcall(callback)
	end
	for _, connection in ipairs(self.Signals) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	for _, connection in ipairs(self._connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Signals)
	table.clear(self._connections)
	if self.ActiveWindow then
		self.ActiveWindow:Destroy()
	end
	self.Unloaded = true
	self.Toggled = false
end

function Library:SetDPIScale(value)
	local scale = tonumber(value)
	if scale and self.ActiveWindow then
		self.ActiveWindow:SetScale(scale > 5 and scale / 100 or scale)
	end
end
function Library:UpdateDependencyBoxes() end
function Library:UpdateDependencyGroupboxes() end
function Library:AttemptSave() end
function Library:SetWatermarkVisibility(value)
	if self.ActiveWindow then
		self.ActiveWindow:SetWatermarkVisible(value)
	end
end
function Library:SetWatermark(text)
	if self.ActiveWindow then
		self.ActiveWindow:SetWatermark(text)
	end
end

return Library
