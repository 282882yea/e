> **Lunar UI** — the plum glass UI with pixel-art flowers (UIBlur backdrop, UIShadow glow, embedded images) lives in [`lunar/`](lunar/). Paste [`lunar/standalone.lua`](lunar/standalone.lua) into your executor, or see [`lunar/README.md`](lunar/README.md).

# Nova UI

A single-file Roblox UI library for script executors. No image assets, no dependencies.

- Window with tabs, sections, dragging, minimise, toggle key, and a touch button on mobile
- Button, toggle, slider, dropdown (single and multi), textbox, keybind, colour picker, label, paragraph, divider
- Notifications
- Four built-in themes, live theme switching, custom themes
- Flag-based config save/load (uses the executor file API when present)
- Falls back cleanly: `gethui` → `CoreGui` → `PlayerGui`, so it also runs in Studio

## Loading

```lua
local Nova = loadstring(game:HttpGet("https://raw.githubusercontent.com/282882yea/e/ccr-27a76df9-ozgy38/Library.lua"))()
```

A full demo is in [`example.lua`](example.lua).

## Quick start

```lua
local Window = Nova:CreateWindow({
	Title = "My Hub",
	SubTitle = "v1.0",                  -- optional
	Size = UDim2.fromOffset(580, 420),  -- optional
	ToggleKey = Enum.KeyCode.RightShift,
	ConfigFolder = "MyHub",
})

local Tab = Window:AddTab("Main")
local Section = Tab:AddSection("Player")

Section:AddToggle({
	Name = "Fly",
	Default = false,
	Flag = "Fly",
	Callback = function(enabled) end,
})

Window:AddSettingsTab() -- theme picker, toggle key, configs, unload
```

Every `Add*` method works on a tab directly or on a section.

## Elements

| Method | Config fields | Value |
| --- | --- | --- |
| `AddButton` | `Name`, `Callback` | – |
| `AddToggle` | `Name`, `Default`, `Flag`, `Callback` | `boolean` |
| `AddSlider` | `Name`, `Min`, `Max`, `Default`, `Increment`, `Suffix`, `Flag`, `Callback` | `number` |
| `AddDropdown` | `Name`, `Options`, `Default`, `Multi`, `Flag`, `Callback` | `string?`, or `{string}` with `Multi` |
| `AddTextbox` | `Name`, `Default`, `Placeholder`, `Numeric`, `RequireEnter`, `Flag`, `Callback` | `string` |
| `AddKeybind` | `Name`, `Default`, `Flag`, `Callback` (key pressed), `ChangedCallback` (rebound) | KeyCode name, `"None"` if unbound |
| `AddColorPicker` | `Name`, `Default`, `Flag`, `Callback` | `Color3` |
| `AddLabel(text)` | | – |
| `AddParagraph` | `Title`, `Content` | – |
| `AddDivider()` | | – |

Each call returns an object:

```lua
local toggle = Section:AddToggle({ Name = "Fly", Flag = "Fly" })

toggle.Value                 -- current value
toggle:Set(true)             -- set and fire the callback
toggle:Set(true, true)       -- set silently
toggle:OnChanged(function(value) end)

dropdown:Refresh({ "A", "B" }) -- replace a dropdown's options
```

While rebinding a keybind, `Escape` or `Backspace` clears it.

## Flags

An element with a `Flag` is readable from anywhere and is included in configs:

```lua
Nova.Flags.Fly            -- value
Nova.Options.Fly:Set(true) -- element object
```

## Notifications

```lua
Nova:Notify({ Title = "Saved", Content = "Config written.", Duration = 4 })
```

## Themes

```lua
Nova:SetTheme("Midnight")            -- Dark, Midnight, Rose, Light
Nova:SetTheme({ Accent = Color3.fromRGB(255, 80, 80) }) -- missing keys fall back to Dark
Nova.Themes.Mine = { ... }           -- register one for the settings tab
```

Keys: `Background`, `Sidebar`, `Section`, `Element`, `ElementHover`, `Inset`, `Stroke`, `Accent`, `Text`, `SubText`.

## Configs

```lua
Nova:SaveConfig("default", "MyHub")  -- returns ok, err
Nova:LoadConfig("default", "MyHub")  -- fires each element's callback
Nova:ListConfigs("MyHub")
```

Files are written to `<folder>/<name>.json`. These return `false, reason` on executors without `writefile`/`readfile`.

## Window and teardown

```lua
Window:Toggle()
Window:SetVisible(false)
Window:SetMinimized(true)
Window:SelectTab(Tab)

Nova.OnUnload = function() end -- clean up your own loops here
Nova:Unload()
```
