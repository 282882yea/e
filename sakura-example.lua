-- Sakura UI example. Paste into your executor.
local Sakura = loadstring(game:HttpGet("https://raw.githubusercontent.com/282882yea/e/claude/executor-ui-tabs-pixeled-aww4ux/Sakura.lua"))()

local Window = Sakura:CreateWindow({
	Title = "sakura.hub",
	SubTitle = "tokyo build",
	Size = UDim2.fromOffset(920, 580),
	Theme = "Dusk", -- Dusk, Night or Day
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "SakuraHub",
})

Sakura:SetWatermark("sakura.hub | v1.0")

-- Tabs run along the top; each tab has its own row of sub-tabs ---------
local Main = Window:AddTab("main")

local Player = Main:AddSubTab("player")

local Movement = Player:AddLeftGroupbox("movement")

Movement:AddSlider({
	Name = "walk speed",
	Min = 16,
	Max = 200,
	Default = 16,
	Suffix = " studs/s",
	Flag = "WalkSpeed",
	Callback = function(value)
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = value
		end
	end,
})

Movement:AddSlider({
	Name = "jump power",
	Min = 50,
	Max = 300,
	Default = 50,
	Flag = "JumpPower",
	Callback = function(value)
		local character = game:GetService("Players").LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = value
		end
	end,
})

Movement:AddToggle({
	Name = "infinite jump",
	Default = false,
	Flag = "InfiniteJump",
	Callback = function(enabled)
		print("infinite jump:", enabled)
	end,
})

Movement:AddDivider()

Movement:AddKeybind({
	Name = "reset character",
	Default = Enum.KeyCode.K,
	Flag = "ResetKey",
	Callback = function()
		local character = game:GetService("Players").LocalPlayer.Character
		if character then
			character:BreakJoints()
		end
	end,
})

local Info = Player:AddLeftGroupbox("about")

Info:AddParagraph({
	Title = "welcome",
	Content = "Tabs and sub-tabs sit along the top. Groupboxes fill the columns below, and every Add* method works inside any groupbox.",
})

local Misc = Player:AddRightGroupbox("misc")

Misc:AddToggle({
	Name = "auto collect",
	Default = true,
	Flag = "AutoCollect",
	Callback = function(enabled)
		print("auto collect:", enabled)
	end,
})

Misc:AddDropdown({
	Name = "team",
	Options = { "Red", "Blue", "Green" },
	Default = "Red",
	Flag = "Team",
	Callback = function(value)
		print("team:", value)
	end,
})

Misc:AddDropdown({
	Name = "targets",
	Options = { "Players", "NPCs", "Bosses" },
	Default = { "Players" },
	Multi = true,
	Flag = "Targets",
	Callback = function(values)
		print("targets:", table.concat(values, ", "))
	end,
})

Misc:AddTextbox({
	Name = "message",
	Placeholder = "type here",
	Flag = "Message",
	Callback = function(text)
		print("message:", text)
	end,
})

Misc:AddButton({
	Name = "send notification",
	Callback = function()
		Sakura:Notify({
			Title = "hello",
			Content = "walk speed is " .. tostring(Sakura.Flags.WalkSpeed),
			Duration = 4,
		})
	end,
})

-- A second sub-tab under the same tab ---------------------------------
local World = Main:AddSubTab("world")

local Lighting = World:AddLeftGroupbox("lighting")

Lighting:AddToggle({
	Name = "fullbright",
	Flag = "Fullbright",
	Callback = function(enabled)
		print("fullbright:", enabled)
	end,
})

Lighting:AddSlider({
	Name = "time of day",
	Min = 0,
	Max = 24,
	Increment = 0.5,
	Default = 14,
	Suffix = "h",
	Flag = "ClockTime",
	Callback = function(value)
		game:GetService("Lighting").ClockTime = value
	end,
})

-- A tabbox: one groupbox with its own little tabs
local Extras = World:AddRightTabbox()
local Fog = Extras:AddTab("fog")
Fog:AddToggle({ Name = "no fog", Flag = "NoFog", Callback = print })
Fog:AddSlider({ Name = "fog distance", Min = 100, Max = 5000, Increment = 50, Default = 1500, Flag = "FogDistance" })
local Sky = Extras:AddTab("sky")
Sky:AddToggle({ Name = "always day", Flag = "AlwaysDay" })
Sky:AddColorPicker({ Name = "sky tint", Default = Color3.fromRGB(255, 190, 220), Flag = "SkyTint" })

-- Visuals tab: three columns -------------------------------------------
local Visuals = Window:AddTab("visuals")

local Esp = Visuals:AddSubTab({ Name = "esp", Columns = 3 })

local Boxes = Esp:AddGroupbox("boxes", 1)
Boxes:AddToggle({ Name = "enabled", Flag = "EspBoxes" })
Boxes:AddColorPicker({
	Name = "box colour",
	Default = Color3.fromRGB(255, 126, 182),
	Flag = "EspColor",
	Callback = function(color)
		print("esp colour:", color)
	end,
})

local Names = Esp:AddGroupbox("names", 2)
Names:AddToggle({ Name = "show names", Default = true, Flag = "EspNames" })
Names:AddToggle({ Name = "show distance", Flag = "EspDistance" })
Names:AddSlider({ Name = "max distance", Min = 100, Max = 5000, Increment = 50, Default = 1500, Flag = "EspRange" })

local Chams = Esp:AddGroupbox("chams", 3)
Chams:AddToggle({ Name = "enabled", Flag = "Chams" })
Chams:AddDropdown({ Name = "material", Options = { "Neon", "ForceField", "Glass" }, Default = "Neon", Flag = "ChamsMaterial" })

-- Settings tab: theme, glow (UIShadow), glass (UIBlur), petals, configs --
Window:AddSettingsTab()

Sakura:Notify({ Title = "sakura.hub", Content = "loaded. press RightShift to hide the window." })
