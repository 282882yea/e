-- Nova UI example. Paste into your executor.
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/282882yea/e/ccr-27a76df9-ozgy38/Library.lua"))()

local Window = Nova:CreateWindow({
	Title = "Nova Hub",
	SubTitle = "v1.0.0",
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "NovaHub",
})

-- Main tab ---------------------------------------------------------
local Main = Window:AddTab("Main")

local Player = Main:AddSection("Player")

Player:AddSlider({
	Name = "Walk speed",
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

Player:AddToggle({
	Name = "Infinite jump",
	Default = false,
	Flag = "InfiniteJump",
	Callback = function(enabled)
		print("Infinite jump:", enabled)
	end,
})

Player:AddKeybind({
	Name = "Reset character",
	Default = Enum.KeyCode.K,
	Flag = "ResetKey",
	Callback = function()
		local character = game:GetService("Players").LocalPlayer.Character
		if character then
			character:BreakJoints()
		end
	end,
})

local Misc = Main:AddSection("Misc")

Misc:AddDropdown({
	Name = "Team",
	Options = { "Red", "Blue", "Green" },
	Default = "Red",
	Flag = "Team",
	Callback = function(value)
		print("Team:", value)
	end,
})

Misc:AddDropdown({
	Name = "Targets",
	Options = { "Players", "NPCs", "Bosses" },
	Default = { "Players" },
	Multi = true,
	Flag = "Targets",
	Callback = function(values)
		print("Targets:", table.concat(values, ", "))
	end,
})

Misc:AddTextbox({
	Name = "Message",
	Placeholder = "Type here",
	Flag = "Message",
	Callback = function(text)
		print("Message:", text)
	end,
})

Misc:AddButton({
	Name = "Send notification",
	Callback = function()
		Nova:Notify({
			Title = "Hello",
			Content = "Walk speed is " .. tostring(Nova.Flags.WalkSpeed),
			Duration = 4,
		})
	end,
})

-- Visuals tab ------------------------------------------------------
local Visuals = Window:AddTab("Visuals")

Visuals:AddParagraph({
	Title = "Elements without a section",
	Content = "Every Add* method works on a tab directly as well as inside a section.",
})

Visuals:AddColorPicker({
	Name = "ESP color",
	Default = Color3.fromRGB(104, 124, 255),
	Flag = "EspColor",
	Callback = function(color)
		print("ESP color:", color)
	end,
})

-- Settings tab: theme, toggle key, configs, unload -------------------
Window:AddSettingsTab()

Nova:Notify({ Title = "Nova Hub", Content = "Loaded. Press RightShift to toggle the UI." })
