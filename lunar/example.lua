-- Lunar UI demo: rebuilds the reference layout. Paste into your executor.
local Lunar = loadstring(game:HttpGet("https://raw.githubusercontent.com/282882yea/e/ccr-85b7debf-yjg52n/lunar/Lunar.lua"))()

local Window = Lunar:CreateWindow({
	Title = "Lunar",
	ToggleKey = Enum.KeyCode.RightShift,
	Blur = "Auto", -- "Auto" | "UIBlur" | "Glass" | "Both" | false
})

-- Every control takes a Callback; these only print so you can see them fire.
local function log(name)
	return function(value)
		print(("[Lunar] %s = %s"):format(name, tostring(value)))
	end
end

-- Combat ---------------------------------------------------------------
local Combat = Window:AddTab({ Name = "Combat", Icon = "locate-fixed" })

local Main = Combat:AddModule({ Title = "Aimbot · Main", Description = "Core aim behavior", Icon = "circle-dot" })
Main:AddDropdown({ Name = "Quick Setup", Options = { "Custom", "Legit", "Semi-Rage", "Rage" }, Default = "Custom", Flag = "QuickSetup", Callback = log("Quick Setup") })
Main:AddToggle({ Name = "Enabled", Default = true, Flag = "AimEnabled", Callback = log("Enabled") })
Main:AddKeybind({ Name = "Hotkey", Default = Enum.UserInputType.MouseButton2, Flag = "AimKey", Callback = log("Hotkey") })
Main:AddDropdown({ Name = "Aim Type", Options = { "Mouse", "Camera" }, Default = "Mouse", Flag = "AimType", Callback = log("Aim Type") })
Main:AddDropdown({ Name = "Target Priority", Options = { "FOV Center", "Distance", "Lowest Health" }, Default = "FOV Center", Flag = "TargetPriority", Callback = log("Target Priority") })
Main:AddDropdown({ Name = "Hit Part", Options = { "Head", "Torso", "Closest" }, Default = "Head", Flag = "HitPart", Callback = log("Hit Part") })
Main:AddToggle({ Name = "Instant Snap", Default = false, Flag = "InstantSnap", Callback = log("Instant Snap") })

local Motion = Combat:AddModule({ Title = "Aimbot · Motion", Description = "Smoothing and tuning", Icon = "wave" })
Motion:AddToggle({ Name = "Sticky Aim", Default = false, Flag = "StickyAim", Callback = log("Sticky Aim") })
Motion:AddToggle({ Name = "Humanize", Default = false, Flag = "Humanize", Callback = log("Humanize") })
Motion:AddSlider({ Name = "X Smoothing", Min = 0, Max = 100, Default = 35, Flag = "SmoothX", Callback = log("X Smoothing") })
Motion:AddSlider({ Name = "Y Smoothing", Min = 0, Max = 100, Default = 35, Flag = "SmoothY", Callback = log("Y Smoothing") })
Motion:AddSlider({ Name = "Reaction Time", Min = 0, Max = 500, Default = 120, Flag = "ReactionTime", Callback = log("Reaction Time") })
Motion:AddSlider({ Name = "Hit Chance", Min = 0, Max = 100, Default = 75, Flag = "HitChance", Callback = log("Hit Chance") })
Motion:AddSlider({ Name = "Sticky FOV", Min = 0, Max = 100, Default = 15, Flag = "StickyFov", Callback = log("Sticky FOV") })
Motion:AddSlider({ Name = "Aim Strength", Min = 0, Max = 100, Default = 16, Flag = "AimStrength", Callback = log("Aim Strength") })

local Lead = Combat:AddModule({ Title = "Projectile Lead", Description = "Only for arrows, knives and other projectiles – leave off for guns", Icon = "timer" })
Lead:AddToggle({ Name = "Lead Projectiles", Default = true, Flag = "LeadProjectiles", Callback = log("Lead Projectiles") })
Lead:AddSlider({ Name = "Projectile Speed", Min = 50, Max = 1000, Step = 10, Default = 300, Flag = "ProjectileSpeed", Callback = log("Projectile Speed") })
Lead:AddSlider({ Name = "Gravity Scale", Min = 0, Max = 2, Step = 0.05, Default = 1, Flag = "GravityScale", Callback = log("Gravity Scale") })
Lead:AddDropdown({ Name = "Prediction", Options = { "Linear", "Quadratic" }, Default = "Linear", Flag = "Prediction", Callback = log("Prediction") })
Lead:AddSlider({ Name = "Max Lead Time", Min = 0, Max = 3, Step = 0.1, Default = 1.5, Suffix = "s", Flag = "MaxLeadTime", Callback = log("Max Lead Time") })
Lead:AddToggle({ Name = "Show Marker", Default = false, Flag = "LeadMarker", Callback = log("Show Marker") })

local Checks = Combat:AddModule({ Title = "Combat · Checks", Description = "Filtering rules for targets", Icon = "box" })
Checks:AddToggle({ Name = "Team Check", Default = true, Flag = "TeamCheck", Callback = log("Team Check") })
Checks:AddToggle({ Name = "Wall Check", Default = true, Flag = "WallCheck", Callback = log("Wall Check") })
Checks:AddToggle({ Name = "Alive Check", Default = true, Flag = "AliveCheck", Callback = log("Alive Check") })
Checks:AddToggle({ Name = "Friend Check", Default = false, Flag = "FriendCheck", Callback = log("Friend Check") })
Checks:AddToggle({ Name = "Visible Only", Default = false, Flag = "VisibleOnly", Callback = log("Visible Only") })
Checks:AddSlider({ Name = "Min Health", Min = 0, Max = 100, Default = 0, Flag = "MinHealth", Callback = log("Min Health") })
Checks:AddDropdown({ Name = "Ignore", Options = { "Friends", "Teammates", "Spectators" }, Default = { "Friends" }, Multi = true, Flag = "IgnoreList", Callback = function() end })

local Fov = Combat:AddModule({ Title = "Field of View", Description = "Where targets are picked up", Icon = "scan" })
Fov:AddToggle({ Name = "Show Circle", Default = true, Flag = "FovVisible", Callback = log("Show Circle") })
Fov:AddSlider({ Name = "Radius", Min = 10, Max = 600, Step = 5, Default = 120, Flag = "FovRadius", Callback = log("Radius") })
Fov:AddSlider({ Name = "Opacity", Min = 0, Max = 100, Default = 60, Suffix = "%", Flag = "FovOpacity", Callback = log("Opacity") })
Fov:AddSlider({ Name = "Thickness", Min = 1, Max = 6, Default = 2, Flag = "FovThickness", Callback = log("Thickness") })
Fov:AddDropdown({ Name = "Shape", Options = { "Circle", "Hexagon", "Square" }, Default = "Circle", Flag = "FovShape", Callback = log("Shape") })
Fov:AddToggle({ Name = "Filled", Default = false, Flag = "FovFilled", Callback = log("Filled") })
Fov:AddToggle({ Name = "Follow Mouse", Default = true, Flag = "FovFollow", Callback = log("Follow Mouse") })
Fov:AddSlider({ Name = "Sides", Min = 12, Max = 96, Step = 4, Default = 64, Flag = "FovSides", Callback = log("Sides") })

local Recoil = Combat:AddModule({ Title = "Recoil", Description = "Compensation while firing", Icon = "activity" })
Recoil:AddToggle({ Name = "Compensate", Default = false, Flag = "RecoilEnabled", Callback = log("Compensate") })
Recoil:AddSlider({ Name = "Vertical", Min = 0, Max = 100, Default = 50, Flag = "RecoilY", Callback = log("Vertical") })
Recoil:AddSlider({ Name = "Horizontal", Min = 0, Max = 100, Default = 25, Flag = "RecoilX", Callback = log("Horizontal") })
Recoil:AddSlider({ Name = "Smoothness", Min = 0, Max = 100, Default = 40, Flag = "RecoilSmooth", Callback = log("Smoothness") })
Recoil:AddDropdown({ Name = "Pattern", Options = { "Adaptive", "Fixed" }, Default = "Adaptive", Flag = "RecoilPattern", Callback = log("Pattern") })
Recoil:AddToggle({ Name = "Only While Aiming", Default = true, Flag = "RecoilAds", Callback = log("Only While Aiming") })
Recoil:AddSlider({ Name = "Start Delay", Min = 0, Max = 300, Step = 5, Default = 30, Suffix = "ms", Flag = "RecoilDelay", Callback = log("Start Delay") })
Recoil:AddToggle({ Name = "Randomize", Default = false, Flag = "RecoilRandom", Callback = log("Randomize") })

local Range = Combat:AddModule({ Title = "Range", Description = "Distance limits", Icon = "radar" })
Range:AddSlider({ Name = "Max Distance", Min = 50, Max = 2000, Step = 25, Default = 800, Flag = "MaxDistance", Callback = log("Max Distance") })
Range:AddSlider({ Name = "Min Distance", Min = 0, Max = 200, Step = 5, Default = 0, Flag = "MinDistance", Callback = log("Min Distance") })
Range:AddToggle({ Name = "Ignore Downed", Default = true, Flag = "IgnoreDowned", Callback = log("Ignore Downed") })
Range:AddToggle({ Name = "Prefer Closest", Default = false, Flag = "PreferClosest", Callback = log("Prefer Closest") })
Range:AddDropdown({ Name = "Units", Options = { "Studs", "Meters" }, Default = "Studs", Flag = "RangeUnits", Callback = log("Units") })
Range:AddSlider({ Name = "Falloff", Min = 0, Max = 100, Default = 20, Suffix = "%", Flag = "RangeFalloff", Callback = log("Falloff") })

local Indicators = Combat:AddModule({ Title = "Indicators", Description = "On-screen feedback", Icon = "sparkles" })
Indicators:AddToggle({ Name = "Target Line", Default = false, Flag = "TargetLine", Callback = log("Target Line") })
Indicators:AddToggle({ Name = "Hit Marker", Default = true, Flag = "HitMarker", Callback = log("Hit Marker") })
Indicators:AddToggle({ Name = "Target Name", Default = true, Flag = "TargetName", Callback = log("Target Name") })
Indicators:AddToggle({ Name = "Hit Sound", Default = false, Flag = "HitSound", Callback = log("Hit Sound") })
Indicators:AddDropdown({ Name = "Style", Options = { "Minimal", "Classic", "Bold" }, Default = "Minimal", Flag = "IndicatorStyle", Callback = log("Style") })
Indicators:AddSlider({ Name = "Size", Min = 8, Max = 32, Default = 14, Flag = "IndicatorSize", Callback = log("Size") })

-- Triggerbot -----------------------------------------------------------
local Trigger = Window:AddTab({ Name = "Triggerbot", Icon = "circle-dot" })

local TriggerMain = Trigger:AddModule({ Title = "Triggerbot", Description = "Fires when the crosshair is on target", Icon = "target" })
TriggerMain:AddToggle({ Name = "Enabled", Default = false, Flag = "TriggerEnabled", Callback = log("Triggerbot") })
TriggerMain:AddKeybind({ Name = "Hotkey", Default = Enum.KeyCode.E, Flag = "TriggerKey", Callback = log("Trigger Hotkey") })
TriggerMain:AddSlider({ Name = "Delay", Min = 0, Max = 500, Step = 5, Default = 60, Suffix = "ms", Flag = "TriggerDelay", Callback = log("Delay") })

local TriggerFilter = Trigger:AddModule({ Title = "Filters", Description = "What counts as a target", Icon = "shield" })
TriggerFilter:AddToggle({ Name = "Team Check", Default = true, Flag = "TriggerTeam", Callback = log("Trigger Team Check") })
TriggerFilter:AddDropdown({ Name = "Hit Parts", Options = { "Head", "Torso", "Arms", "Legs" }, Default = { "Head", "Torso" }, Multi = true, Flag = "TriggerParts", Callback = function() end })

-- Visuals --------------------------------------------------------------
local Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye" })

local Esp = Visuals:AddModule({ Title = "Players", Description = "Overlays drawn on other players", Icon = "eye" })
Esp:AddToggle({ Name = "Enabled", Default = false, Flag = "EspEnabled", Callback = log("ESP") })
Esp:AddToggle({ Name = "Boxes", Default = true, Flag = "EspBoxes", Callback = log("Boxes") })
Esp:AddToggle({ Name = "Names", Default = true, Flag = "EspNames", Callback = log("Names") })
Esp:AddSlider({ Name = "Max Distance", Min = 100, Max = 3000, Step = 50, Default = 1500, Flag = "EspDistance", Callback = log("ESP Distance") })

local World = Visuals:AddModule({ Title = "World", Description = "Lighting and atmosphere", Icon = "globe" })
World:AddToggle({ Name = "Fullbright", Default = false, Flag = "Fullbright", Callback = log("Fullbright") })
World:AddSlider({ Name = "Field of View", Min = 60, Max = 120, Default = 70, Flag = "CameraFov", Callback = log("Camera FOV") })

-- Movement -------------------------------------------------------------
local Movement = Window:AddTab({ Name = "Movement", Icon = "zap" })

local Speed = Movement:AddModule({ Title = "Speed", Description = "Walk and jump tuning", Icon = "gauge" })
Speed:AddToggle({ Name = "Enabled", Default = false, Flag = "SpeedEnabled", Callback = log("Speed") })
Speed:AddSlider({ Name = "Walk Speed", Min = 16, Max = 120, Default = 16, Flag = "WalkSpeed", Callback = log("Walk Speed") })
Speed:AddSlider({ Name = "Jump Power", Min = 50, Max = 200, Default = 50, Flag = "JumpPower", Callback = log("Jump Power") })

-- Player ---------------------------------------------------------------
local PlayerTab = Window:AddTab({ Name = "Player", Icon = "user" })

local Character = PlayerTab:AddModule({ Title = "Character", Description = "Local player options", Icon = "user" })
Character:AddToggle({ Name = "Anti AFK", Default = true, Flag = "AntiAfk", Callback = log("Anti AFK") })
Character:AddTextbox({ Name = "Nickname", Placeholder = "Display name", Flag = "Nickname", Callback = log("Nickname") })
Character:AddButton({ Name = "Respawn", Text = "Reset", Callback = function()
	Lunar:Notify({ Title = "Player", Content = "Respawn requested." })
end })

-- Settings -------------------------------------------------------------
Window:AddDivider()
local Settings = Window:AddTab({ Name = "Settings", Icon = "settings" })

local Interface = Settings:AddModule({ Title = "Interface", Description = "Window behaviour", Icon = "sliders-horizontal" })
Interface:AddKeybind({ Name = "Toggle Key", Default = Enum.KeyCode.RightShift, Flag = "ToggleKey", Callback = function(key)
	Window.ToggleKey = key
end })
Interface:AddDropdown({ Name = "Scale", Options = { "75%", "90%", "100%", "110%", "125%", "150%" }, Default = "100%", Flag = "UiScale", Callback = function(value)
	Window:SetScale(tonumber(string.match(value, "%d+")) / 100)
end })
Interface:AddButton({ Name = "Unload", Text = "Unload", Callback = function()
	Lunar:Unload()
end })

Lunar:Notify({ Title = "Lunar", Content = "Loaded. Press Right Shift to hide or show the window." })
