local function makeFrekksecSettings(helper, ui, private, window, store, d)
    local S = {Ready=false, Stopped=false, Controls={}, Toasts={}, Revision=0}
    local saved = type(store.Preferences.UI) == "table" and store.Preferences.UI or {}
    local defaults = {MenuKey="Insert",Opacity=72,Scale=100,Blur=false,Glow=60,HoverGlow=true,WindowGlow=35,WindowGlowWidth=24,
        Watermark=true,Keybinds=false,KeybindMode="Always",Notifications=true,LoadNotification=true,
        NotifySide="Left",NotifyDuration=4,BackgroundImage="",BackgroundOpacity=15,
        Scene="Dusk",Backdrop=true,Petals=true,PetalCount=16,PanelBlur="Medium",GlowPulse=true,LogoGlow=85,WindowWidth=1010,WindowHeight=590}
    local limits = {Opacity={15,100},Scale={60,120},Glow={0,100},WindowGlow={0,100},WindowGlowWidth={8,48},NotifyDuration={1,10},BackgroundOpacity={0,100},PetalCount={0,60},LogoGlow={0,100},WindowWidth={640,4000},WindowHeight={400,3000}}
    local P = table.clone(defaults)
    for key, fallback in pairs(defaults) do
        local value = saved[key]
        if type(value) == type(fallback) then
            if type(value) == "number" then
                if value == value and math.abs(value) < math.huge then P[key]=math.clamp(value,limits[key][1],limits[key][2]) end
            else P[key] = value end
        end
    end
    -- Style 5 is the Sakura UI: older saved looks (Crimson red, opaque panels) are replaced once.
    local refreshStyle=saved.StyleVersion~=5
    P.StyleVersion=5
    if refreshStyle then
        P.Opacity,P.Glow,P.WindowGlow,P.WindowGlowWidth,P.Blur=72,60,35,24,false
    end
    local function validKey(key)
        if type(key) ~= "string" or ({Unknown=true,F6=true,H=true,End=true,Escape=true})[key] then return false end
        local ok, code = pcall(function() return Enum.KeyCode[key] end)
        return ok and code ~= nil
    end
    if not validKey(P.MenuKey) then P.MenuKey=defaults.MenuKey end
    if not table.find({"Always","Toggled"},P.KeybindMode) then P.KeybindMode="Always" end
    if not table.find({"Left","Right"},P.NotifySide) then P.NotifySide="Left" end
    if not table.find({"Dusk","Night","Day"},P.Scene) then P.Scene=defaults.Scene end
    if not table.find({"Off","Light","Medium","Heavy"},P.PanelBlur) then P.PanelBlur=defaults.PanelBlur end
    if P.BackgroundImage ~= "" and not P.BackgroundImage:match("^%d+$") then P.BackgroundImage="" end
    S.Prefs=P
    local themeKeys={"MainColor","AccentColor","BackgroundColor","OutlineColor","FontColor","SurfaceGlowColor","ControlGlowColor","LogoGlowColor"}
    local builtins={
        ["Sakura Dusk"]={MainColor={54,30,72},AccentColor={255,126,182},BackgroundColor={35,19,48},OutlineColor={104,66,128},FontColor={255,236,245}},
        ["Sakura Night"]={MainColor={30,25,66},AccentColor={255,95,162},BackgroundColor={17,14,42},OutlineColor={66,56,120},FontColor={241,234,255}},
        ["Sakura Day"]={MainColor={255,216,233},AccentColor={255,92,157},BackgroundColor={255,245,250},OutlineColor={238,160,196},FontColor={92,40,74}},
        ["Frekksec"]={MainColor={26,24,25},AccentColor={255,49,56},BackgroundColor={18,17,18},OutlineColor={66,63,65},FontColor={233,229,229}},
        ["Violet"]={MainColor={23,24,33},AccentColor={158,121,255},BackgroundColor={16,17,24},OutlineColor={51,49,68},FontColor={237,233,248}},
        ["Midnight"]={MainColor={20,27,40},AccentColor={86,168,255},BackgroundColor={13,19,29},OutlineColor={38,60,83},FontColor={225,237,250}},
        ["Crimson"]={MainColor={32,22,27},AccentColor={250,94,121},BackgroundColor={23,15,21},OutlineColor={75,43,56},FontColor={250,231,238}},
        ["Mint"]={MainColor={21,31,29},AccentColor={92,225,176},BackgroundColor={13,22,20},OutlineColor={40,69,59},FontColor={226,247,239}},
        ["Amber"]={MainColor={33,28,22},AccentColor={255,185,77},BackgroundColor={23,20,15},OutlineColor={77,61,36},FontColor={248,238,222}},
    }
    local sceneFor={["Sakura Dusk"]="Dusk",["Sakura Night"]="Night",["Sakura Day"]="Day"}
    local colors=builtins["Sakura Dusk"]
    if not refreshStyle and type(saved.Colors)=="table" then
        local ok,clean=pcall(store.ValidateTheme,store,saved.Colors)
        if ok then colors=clean end
    end
    local defaultTheme=store.Preferences.DefaultTheme
    if type(defaultTheme)=="table" then
        if defaultTheme.Kind=="builtin" and builtins[defaultTheme.Name] then colors=builtins[defaultTheme.Name]
        elseif defaultTheme.Kind=="custom" then
            local ok,clean=pcall(store.ReadTheme,store,defaultTheme.Name)
            if ok then colors=clean else S.Warning="Default theme could not load: "..tostring(clean) end
        end
    end
    P.Colors=store:ValidateTheme(colors)
    local syncingColors=false
    local function applyColors()
        for _,key in ipairs(themeKeys) do ui[key]=Color3.fromRGB(table.unpack(P.Colors[key])) end
        ui.AccentColorDark=ui:GetDarkerColor(ui.AccentColor)
        ui:UpdateColorsUsingRegistry()
        if d.themeChanged then d.themeChanged() end
    end
    local function persist()
        if not S.Ready or S.Stopped then return end
        S.Revision=S.Revision+1
        local revision=S.Revision
        task.delay(0.4,function()
            if S.Stopped or S.Revision~=revision then return end
            S:Flush()
        end)
    end
    function S:Flush()
        if not self.Ready then return end
        local ok,err=pcall(store.SavePreferences,store,{UI=table.clone(P)})
        if not ok and not self.PreferenceError then
            self.PreferenceError=true
            d.notice("UI settings work this session, but could not be saved: "..tostring(err))
        elseif ok then self.PreferenceError=false end
        return ok
    end
    function S:Notify(text)
        if self.Stopped or not P.Notifications then return end
        ui:Notify(text,P.NotifyDuration)
    end
    local blur=Instance.new("BlurEffect")
    blur.Name="FrekksecMenuBlur";blur.Size=14;blur.Enabled=false
    blur.Parent=d.lighting
    helper:Track({Disconnect=function() blur:Destroy() end})
    local background=ui:Create("ImageLabel",{Name="FrekksecBackground",BackgroundTransparency=1,
        ImageTransparency=1,Size=UDim2.fromScale(1,1),Active=false,ScaleType=Enum.ScaleType.Crop,
        ZIndex=2,Parent=window.Background})
    background.ZIndex=2
    local keysLabel=ui:CreateLabel({Name="FrekksecKeybinds",BackgroundColor3=ui.BackgroundColor,
        BackgroundTransparency=0.12,Position=UDim2.new(0,16,0.5,-34),Size=UDim2.fromOffset(212,68),
        LineHeight=1.5,ZIndex=112,Visible=false,Parent=ui.ScreenGui})
    ui:Create("UIPadding",{Parent=keysLabel,PaddingLeft=UDim.new(0,8)})
    local keysEdge=ui:Create("UIStroke",{Parent=keysLabel,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=ui.AccentColor})
    ui:AddToRegistry(keysLabel,{BackgroundColor3="BackgroundColor"})
    ui:AddToRegistry(keysEdge,{Color="AccentColor"})
    ui:SurfaceShadow(keysLabel,10)
    ui:MakeDraggable(keysLabel,96)
    local bindButton
    function S:ApplyMenu()
        ui:SetMenuOpacity(window.Holder,P.Opacity)
        ui:SetButtonGlow(P.Glow/100,P.HoverGlow)
        ui:SetWindowGlow(P.WindowGlow/100,P.WindowGlowWidth)
        blur.Enabled=P.Blur and window.Holder.Visible
        ui:SetWatermark("frekksec lua | v"..helper.Version.." | "..tostring(d.playerName or "Player"))
        ui:SetWatermarkVisibility(P.Watermark)
        ui:SetNotificationSide(P.NotifySide)
        ui:SetScene(P.Scene)
        ui:SetBackdrop(P.Backdrop)
        ui:SetPetals(P.Petals,P.PetalCount)
        ui:SetPanelBlur(P.PanelBlur)
        ui:SetGlowPulse(P.GlowPulse)
        ui:SetLogoGlow(P.LogoGlow)
        ui:SetFrost(P.BackgroundImage=="")
        background.Image=P.BackgroundImage~="" and "rbxassetid://"..P.BackgroundImage or ""
        background.ImageTransparency=1-P.BackgroundOpacity/100
        background.Visible=P.BackgroundImage~=""
        if d.setScale then d.setScale(P.Scale/100) end
        if d.menuKeyChanged then d.menuKeyChanged(P.MenuKey) end
        if bindButton and not self.PickingKey then bindButton:SetText("Menu bind: "..P.MenuKey) end
        self:UpdateKeys()
    end
    function S:UpdateKeys()
        local active=helper:Get("Enabled")
        local hide=helper._uiHide==true or d.isHideDown()
        keysLabel.Visible=P.Keybinds and (P.KeybindMode=="Always" or active or hide)
        keysLabel.Text="  ["..P.MenuKey.."] Menu\n  [F6] Helper: "..(active and "ON" or "OFF")
            .."\n  [H] Hide: "..(hide and "ON" or "OFF").."\n  [End] Panic / return"
    end
    function S:ConsumeInput(input)
        if not self.PickingKey then return false end
        if input.UserInputType~=Enum.UserInputType.Keyboard then return true end
        local key=input.KeyCode.Name
        if key=="Escape" then
            self.PickingKey=false;ui:CaptureKeys(false);self:ApplyMenu();return true
        end
        if not validKey(key) then d.notice("Choose another key; F6, H and End are reserved.");return true end
        self.PickingKey=false;ui:CaptureKeys(false);P.MenuKey=key
        self:ApplyMenu();persist()
        return true
    end
    function S:Destroy()
        if self.Stopped then return end
        self.Stopped=true;self.Revision=self.Revision+1
        if self.Ready then self:Flush() end
        blur:Destroy()
        for _,frame in ipairs(self.Toasts) do frame:Destroy() end
        table.clear(self.Toasts)
    end
    helper.Settings=S
    local function action(fn)
        return function()
            local ok,err=pcall(fn)
            if not ok then d.notice(tostring(err)) end
        end
    end
    local function control(group,key,text,values)
        local id="frekksec_ui_"..key
        if type(P[key])=="boolean" then group:AddToggle(id,{Text=text,Default=P[key]})
        elseif type(P[key])=="number" then
            group:AddSlider(id,{Text=text,Default=P[key],Min=limits[key][1],Max=limits[key][2],Rounding=0})
        elseif values then group:AddDropdown(id,{Text=text,Values=values,Default=P[key]})
        else group:AddInput(id,{Text=text,Default=P[key],Finished=true}) end
        local item=private.Toggles[id] or private.Options[id]
        S.Controls[key]=item
        item:OnChanged(function()
            if not S.Ready then return end
            local value=item.Value
            if key=="BackgroundImage" then
                value=tostring(value or ""):match("^%s*(.-)%s*$")
                value=value:match("^rbxassetid://(%d+)$") or value
                if value~="" and not value:match("^%d+$") then d.notice("Use a Roblox image asset ID, or leave it empty.");return end
            end
            P[key]=value;S:ApplyMenu();persist()
        end)
        return item
    end
    local tab=window:AddTab("Settings")
    local look=tab:AddSubTab("interface")
    local themesPage=tab:AddSubTab("themes")
    local data=tab:AddSubTab("configs")
    local menuTabs=look:AddLeftTabbox("Menu settings")
    local menu=menuTabs:AddTab("Menu")
    local notifications=menuTabs:AddTab("Notifications")
    bindButton=menu:AddButton("Menu bind: "..P.MenuKey,function()
        S.PickingKey=true;ui:CaptureKeys(true);bindButton:SetText("Press a key (Esc cancels)")
    end)
    control(menu,"Opacity","Menu opacity (%)")
    control(menu,"Scale","Menu scale (%)")
    control(menu,"Blur","World blur (behind menu)")
    control(menu,"Keybinds","Keybind menu")
    control(menu,"KeybindMode","Keybind menu mode",{"Always","Toggled"})
    control(notifications,"Notifications","Notifications")
    control(notifications,"LoadNotification","Load notification")
    control(notifications,"NotifySide","Position",{"Left","Right"})
    control(notifications,"NotifyDuration","Duration (seconds)")
    notifications:AddButton("Test notification",function() d.notice("frekksec lua notifications are working.") end)
    local display=look:AddLeftGroupbox("UI settings")
    control(display,"WindowGlow","UIShadow window strength (%)")
    control(display,"WindowGlowWidth","UIShadow window blur (px)")
    control(display,"Glow","UIShadow button strength (%)")
    control(display,"HoverGlow","Glow on controls")
    control(display,"Watermark","Watermark")
    local sakura=look:AddRightGroupbox("Sakura look")
    control(sakura,"Scene","Backdrop scene",{"Dusk","Night","Day"})
    control(sakura,"Backdrop","Pixel backdrop")
    control(sakura,"Petals","Falling petals")
    control(sakura,"PetalCount","Petal amount")
    control(sakura,"PanelBlur","Panel blur",{"Off","Light","Medium","Heavy"})
    control(sakura,"GlowPulse","Glow pulse")
    control(sakura,"LogoGlow","Logo glow (%)")
    -- Window size: drag the bottom-right corner; it is remembered.
    if ui.Window then
        ui.Window:SetSize(P.WindowWidth,P.WindowHeight)
        ui.Window.OnResized=function(w,h) P.WindowWidth,P.WindowHeight=w,h;persist() end
    end
    sakura:AddButton("Reset window size",function()
        P.WindowWidth,P.WindowHeight=1010,590
        if ui.Window then ui.Window:SetSize(1010,590) end
        persist()
    end)

    local config=data:AddLeftGroupbox("Configuration")
    config:AddInput("frekksec_config_name",{Text="Config name",Default="",Finished=true})
    local configName=private.Options.frekksec_config_name
    local function list(kind)
        local ok,names=pcall(store.List,store,kind)
        if ok then return names end
        S.Warning=S.Warning or tostring(names)
        return {}
    end
    local names=list("configs")
    config:AddDropdown("frekksec_config_list",{Text="Config list",Values=names,Default=store:GetAutoload() or names[1],AllowNull=true})
    local configList=private.Options.frekksec_config_list
    config:AddToggle("frekksec_autoload",{Text="Autoload selected config",Default=false})
    local autoloadToggle=private.Toggles.frekksec_autoload
    local autoloadLabel=config:AddLabel("Current autoload: none").TextLabel
    local syncingAutoload=false
    local function syncAutoload()
        local name=store:GetAutoload()
        autoloadLabel.Text="Autoload: "..(name or "none")
        autoloadLabel.TextTruncate=Enum.TextTruncate.AtEnd
        syncingAutoload=true;autoloadToggle:SetValue(name~=nil and name==configList.Value);syncingAutoload=false
    end
    local function refreshConfigs(selected)
        local refreshed=store:List("configs")
        local current=selected or configList.Value
        configList.Values=refreshed;configList:SetValues()
        configList:SetValue(table.find(refreshed,current) and current or nil)
        syncAutoload()
    end
    local function applyConfig(name)
        local values=store:ReadConfig(name) -- Full validation happens before any mutation.
        helper:Set("Enabled",false)
        for _,def in ipairs(helper.Schema) do
            local accepted,err=helper:Set(def.key,values[def.key])
            if not accepted then error(err,0) end
        end
        helper._uiHide=false;helper:SetManualHide(false)
        return name
    end
    function helper:CreateConfig(name)
        local created=store:SaveConfig(name or configName.Value,self:GetConfig(),false)
        refreshConfigs(created);return created
    end
    function helper:SaveConfig(name)
        local written=store:SaveConfig(name or configList.Value,self:GetConfig(),true)
        refreshConfigs(written);return written
    end
    function helper:LoadConfig(name) return applyConfig(name or configList.Value) end
    function helper:DeleteConfig(name)
        store:DeleteConfig(name or configList.Value);refreshConfigs()
    end
    configList:OnChanged(syncAutoload)
    autoloadToggle:OnChanged(function()
        if syncingAutoload or not S.Ready then return end
        local ok,err=pcall(function()
            if autoloadToggle.Value then store:SetAutoload(store:Name(configList.Value)) else store:SetAutoload(nil) end
        end)
        syncAutoload()
        if not ok then d.notice(tostring(err)) end
    end)
    config:AddButton("Create config",action(function() d.notice("Created config: "..helper:CreateConfig()) end))
    config:AddButton("Save / overwrite config",action(function() d.notice("Saved config: "..helper:SaveConfig()) end))
    config:AddButton("Load config",action(function() d.notice("Loaded "..helper:LoadConfig()..". Enable when ready.") end))
    config:AddButton("Delete config",action(function() helper:DeleteConfig();d.notice("Config deleted.") end))
    config:AddButton("Refresh list",action(function() refreshConfigs();d.notice("Config list refreshed.") end))
    config:AddButton("Set autoload",action(function() store:SetAutoload(store:Name(configList.Value));syncAutoload();d.notice("Autoload set.") end))
    config:AddButton("Remove autoload",action(function() store:SetAutoload(nil);syncAutoload();d.notice("Autoload removed.") end))
    config:AddLabel("Loads settings; movement stays off.")
    local transfer=data:AddRightGroupbox("Import / export")
    transfer:AddInput("frekksec_config_json",{Text="Paste config JSON",Default="",Finished=true})
    transfer:AddButton("Import as new config",action(function()
        local name=store:ImportConfig(configName.Value,private.Options.frekksec_config_json.Value)
        refreshConfigs(name);d.notice("Imported config: "..name)
    end))
    transfer:AddButton("Copy selected config",action(function()
        if type(d.clipboard)~="function" then error("Your executor does not provide clipboard access.",0) end
        local name=store:Name(configList.Value)
        d.clipboard(store:ExportConfig(name));d.notice("Copied config: "..name)
    end))
    transfer:AddButton("Copy current settings",action(function()
        if type(d.clipboard)~="function" then error("Your executor does not provide clipboard access.",0) end
        d.clipboard(store:ExportConfig(nil,helper:GetConfig()));d.notice("Current settings copied.")
    end))
    transfer:AddButton("Import previous single config",action(function()
        local name=store:ImportLegacy(configName.Value);refreshConfigs(name);d.notice("Imported previous config: "..name)
    end))
    transfer:AddLabel("Use Config name for new imports.")

    local themeTabs=themesPage:AddLeftTabbox("Theme settings")
    local themes=themeTabs:AddTab("Themes")
    local backdrop=themeTabs:AddTab("Background")
    local names={SurfaceGlowColor="Window / HUD glow",ControlGlowColor="Button / control glow",LogoGlowColor="Logo glow"}
    for _,key in ipairs(themeKeys) do
        themes:AddLabel(names[key] or key:gsub("Color$"," color")):AddColorPicker("frekksec_color_"..key,{Default=Color3.fromRGB(table.unpack(P.Colors[key]))})
        local picker=private.Options["frekksec_color_"..key]
        picker:OnChanged(function()
            if not S.Ready or syncingColors then return end
            local c=picker.Value;P.Colors[key]={math.floor(c.R*255+0.5),math.floor(c.G*255+0.5),math.floor(c.B*255+0.5)}
            applyColors();persist()
        end)
    end
    local function setColors(value)
        P.Colors=store:ValidateTheme(value)
        syncingColors=true
        for _,key in ipairs(themeKeys) do private.Options["frekksec_color_"..key]:SetValueRGB(Color3.fromRGB(table.unpack(P.Colors[key]))) end
        syncingColors=false;applyColors();persist()
    end
    themes:AddDropdown("frekksec_builtin_theme",{Text="Theme list",Values={"Sakura Dusk","Sakura Night","Sakura Day","Frekksec","Violet","Midnight","Crimson","Mint","Amber"},Default="Sakura Dusk"})
    local builtin=private.Options.frekksec_builtin_theme
    -- The Sakura themes bring their own backdrop scene along.
    local function applyBuiltin(name)
        setColors(builtins[name])
        if sceneFor[name] and S.Controls.Scene then S.Controls.Scene:SetValue(sceneFor[name]) end
    end
    themes:AddButton("Apply theme",function() applyBuiltin(builtin.Value) end)
    themes:AddButton("Apply Frekks Hail style",function()
        store:SavePreferences({DefaultTheme={Kind="builtin",Name="Frekksec"}})
        for key,value in pairs({Glow=45,WindowGlow=35,WindowGlowWidth=18,Blur=false,Opacity=100}) do S.Controls[key]:SetValue(value) end
        setColors(builtins.Frekksec);S:ApplyMenu()
    end)
    themes:AddButton("Set as default theme",action(function()
        store:SavePreferences({DefaultTheme={Kind="builtin",Name=builtin.Value}})
        applyBuiltin(builtin.Value);d.notice("Default theme: "..builtin.Value)
    end))
    themes:AddButton("Reset default theme",action(function()
        store:SavePreferences({DefaultTheme=false});applyBuiltin("Sakura Dusk");d.notice("Default theme reset.")
    end))
    control(backdrop,"BackgroundImage","Background image ID")
    control(backdrop,"BackgroundOpacity","Image opacity (%)")
    backdrop:AddLabel("Use a Roblox image asset ID.")
    backdrop:AddLabel("Lower menu opacity to reveal it.")
    local custom=themesPage:AddRightGroupbox("Custom themes")
    custom:AddInput("frekksec_theme_name",{Text="Theme name",Default="",Finished=true})
    custom:AddDropdown("frekksec_custom_theme",{Text="Custom themes",Values=list("themes"),AllowNull=true})
    local customList=private.Options.frekksec_custom_theme
    local function refreshThemes(selected)
        local all=store:List("themes");local current=selected or customList.Value
        customList.Values=all;customList:SetValues();customList:SetValue(table.find(all,current) and current or nil)
    end
    custom:AddButton("Create theme",action(function()
        local name=store:SaveTheme(private.Options.frekksec_theme_name.Value,P.Colors,false)
        refreshThemes(name);d.notice("Created theme: "..name)
    end))
    custom:AddButton("Load theme",action(function() setColors(store:ReadTheme(customList.Value));d.notice("Theme loaded.") end))
    custom:AddButton("Overwrite theme",action(function() store:SaveTheme(customList.Value,P.Colors,true);d.notice("Theme saved.") end))
    custom:AddButton("Delete theme",action(function() store:DeleteTheme(customList.Value);refreshThemes();d.notice("Theme deleted.") end))
    custom:AddButton("Set custom default",action(function()
        local name=store:Name(customList.Value);local theme=store:ReadTheme(name)
        store:SavePreferences({DefaultTheme={Kind="custom",Name=name}});setColors(theme);d.notice("Default theme: "..name)
    end))
    custom:AddButton("Refresh themes",action(function() refreshThemes();d.notice("Theme list refreshed.") end))
    local utility=look:AddRightGroupbox("frekksec lua")
    utility:AddButton("Reset movement defaults",function()
        helper:Set("Enabled",false)
        for _,def in ipairs(helper.Schema) do helper:Set(def.key,def.default) end
        d.notice("Movement settings reset.")
    end)
    utility:AddButton("Save UI preferences",function() if S:Flush() then d.notice("UI preferences saved.") end end)
    utility:AddButton("Unload helper",function() helper:Destroy() end)
    utility:AddLabel("UI source bundled / editable")
    utility:AddLabel("Configs are separate from Frekks Hail.")
    S.Ready=true
    helper.Settings=S
    helper:Track(window.Holder:GetPropertyChangedSignal("Visible"):Connect(function()
        blur.Enabled=P.Blur and window.Holder.Visible
        if not window.Holder.Visible then S.PickingKey=false;ui:CaptureKeys(false);bindButton:SetText("Menu bind: "..P.MenuKey) end
    end))
    applyColors();S:ApplyMenu();syncAutoload()
    function S:LoadStartup()
        if store.StartupWarning then d.notice(store.StartupWarning) end
        if self.Warning then d.notice(self.Warning) end
        local autoload=store:GetAutoload()
        if autoload then
            local ok,err=pcall(applyConfig,autoload)
            if ok then
                if P.LoadNotification then d.notice("Autoloaded "..autoload..". Movement is off.") end
            else d.notice("Autoload failed: "..tostring(err)) end
        elseif P.LoadNotification then d.notice("frekksec lua loaded. "..P.MenuKey.." opens the menu.") end
    end
    return S
end

