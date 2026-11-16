local function startFrekksec(makeController, loadUI)
    local env = type(getgenv)=="function" and getgenv() or _G
    local helper
    local access = makeFrekksecAccess(env, function(name)
        if name=="getgc" then return getgc end
        if name=="cloneref" then return cloneref end
        if name=="clonereference" then return clonereference end
        if name=="filtergc" then return filtergc end
        if name=="getupvalues" then return getupvalues or debug and debug.getupvalues end
    end,function() return helper~=nil and helper:Get("ExecutorReferences")==true end)
    local Players = game:GetService("Players")
    local RunService = access:Service("RunService")
    local UIS = access:Service("UserInputService")
    local Http = access:Service("HttpService")
    local player = Players.LocalPlayer
    assert(player, "frekksec lua must run on the client")
    local previous = env.frekksec
    if previous~=nil then
        local owned=type(previous)=="table" and (rawget(previous,"_FrekksecId")=="frekksec.lua"
            or type(rawget(previous,"GetMatchInfo"))=="function" and type(rawget(previous,"NotifyShot"))=="function" and type(rawget(previous,"Schema"))=="table")
        assert(owned and type(previous.Destroy)=="function","The frekksec global is already used by another script")
        local cleaned,problem=pcall(previous.Destroy,previous)
        assert(cleaned,"Previous Frekksec instance could not unload: "..tostring(problem))
    end
    local rng, selected = Random.new(), nil
    local uiEnv = {}
    local ui, marker, hud, statusLabel, settingsUI
    local currentRuntime, runtimeHost
    local fake,lunar,perfect
    local motion=makeFrekksecMotionGuard({now=os.clock})
    local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
    local valid=FrekksecSpace.Vector
    local function host()
        local session = env.__FrekksHailSession or _G.__FrekksHailSession
        return type(session)=="table" and session.ready and session.library or nil
    end
    local function fightersRegistry()
        if not helper or helper.Driver~="Frekks linked" or helper:Get("Driver")=="Standalone" then return nil end
        if not currentRuntime or currentRuntime.destroyed or host()~=runtimeHost then return nil end
        local context=currentRuntime.context
        return context and context._fighters or nil
    end
    local matchCheck=makeFrekksecMatchCheck({player=player,players=Players,
        attribute=function(instance,name) return access:Attribute(instance,name) end,
        registry=fightersRegistry})
    local threatReader=makeFrekksecThreatReader({now=os.clock,player=player,players=Players,access=access,
        load=require,spawn=task.spawn,cancel=task.cancel,
        allowed=function(other) return matchCheck:Classify(other) end})
    local defense=makeFrekksecBackFacing({now=os.clock,registry=fightersRegistry,
        candidates=function() return threatReader:Candidates() end,
        allowed=function(other,state) return matchCheck:Classify(other,state) end})
    local function localData()
        local char = player.Character
        local root = char and access:Find(char,"HumanoidRootPart")
        local humanoid = char and access:FindClass(char,"Humanoid")
        return char, root, humanoid
    end
    local function baseContext(client)
        local char, root, humanoid = localData()
        local environmentId = matchCheck:Environment(player)
        return {
            character=char, localFrame=client or (fake and fake:Surface()) or (root and root.CFrame),
            alive=root~=nil and root.Parent~=nil and humanoid~=nil and humanoid.Health>0,
            health=humanoid and humanoid.Health or 0,
            inMatch=environmentId~=nil,
            environmentId=environmentId,
        }
    end
    local function findRuntime()
        currentRuntime,runtimeHost=nil,nil
        local result, best = nil, -1
        local ok,reason=access:Scan(function(object)
            if type(object)=="table" and rawget(object,"destroyed")==false
                and type(rawget(object,"Step"))=="function" and type(rawget(object,"Pause"))=="function" then
                local engine, context = rawget(object,"engine"),rawget(object,"context")
                if type(engine)=="table" and type(context)=="table"
                    and rawget(engine,"_playerContext")==context
                    and type(rawget(engine,"_spatialLimitGate"))=="table"
                    and type(rawget(engine,"_projectileBreakerTeleport"))=="table" then
                    local hits = rawget(engine,"_hitscanStrategy")
                    local compatible = type(hits)=="table" and type(hits.ResolveHeadPart)=="function"
                    if compatible and type(engine._Plan)=="function" then
                        local score = (object.enabled and 4 or 0)+(engine._innerContext and 2 or 0)
                        if score>best then best,result=score,object end
                    end
                end
            end
        end)
        if not ok then return nil,reason end
        if result then currentRuntime,runtimeHost=result,host() end
        return result,"Waiting for the updated Frekks ragebot runtime"
    end
    local function nativeContext(engine,target,client,config)
        local ctx=baseContext(client)
        ctx.nativeDriver=true
        local inner=engine._innerContext
        if inner and inner.FighterState then
            if inner.FighterState.IsSpectating then ctx.inMatch=false end
        end
        ctx.targetAllowed=false
        ctx.targetReason="Waiting for a match opponent"
        ctx.reloading=engine._reloadGun~=nil
        if not ctx.reloading and inner and inner.ItemBehaviors then
            local gun=inner.ItemBehaviors:EquippedItemAsGun()
            ctx.reloading=gun~=nil and gun:IsReloading()
        end
        if target then
            local fighter=target.FighterState
            local state=target.AliveState
            local model=state and state.Model
            local other=fighter and fighter.Player or (model and Players:GetPlayerFromCharacter(model))
            local allowed,reason=matchCheck:Classify(other,fighter)
            if not allowed then ctx.targetReason=reason;return ctx end
            if not model or not model.Parent or other.Character~=model or state.Alive==false then
                ctx.targetReason="Waiting for the opponent to respawn";return ctx
            end
            local cf=target.RootCFrame
            if typeof(cf)=="CFrame" and valid(cf.Position) then ctx.targetFrame=cf
            elseif valid(target.RootPosition) then ctx.targetFrame=CFrame.new(target.RootPosition) end
            ctx.targetVelocity=state and state.Velocity or Vector3.zero
            if ctx.targetFrame then
                ctx.targetAllowed=true
                ctx.targetIdentity=other or model or target
                ctx.targetName=other and other.Name or model and model.Name or "Frekks target"
            else
                ctx.targetIdentity,ctx.targetName=other,other.Name
                ctx.targetPending=true
                ctx.targetReason="Tracking enemy; position unavailable"
            end
        end
        return ctx
    end
    local function targetInfo(other,config,origin,keepIdentity)
        if other==player or other.Parent~=Players then return nil end
        if not matchCheck:Classify(other) then return nil end
        if config.TargetMode=="Manual" then
            local query=config.ManualTarget:lower():gsub("^%s+",""):gsub("%s+$","")
            if query=="" or (other.Name:lower()~=query and other.DisplayName:lower()~=query and tostring(other.UserId)~=query) then return nil end
        end
        local char=other.Character
        local root=char and access:Find(char,"HumanoidRootPart")
        local hum=char and access:FindClass(char,"Humanoid")
        if hum and hum.Health<=0 then return nil end
        if not char or not char.Parent or not root or not root.Parent or not hum or not valid(root.Position) then
            if keepIdentity and config.MaxDistance==0 then return {player=other,pending=true,score=math.huge} end
            return nil
        end
        local distance=FrekksecSpace.Delta(root.Position,origin)
        if config.MaxDistance>0 and distance>config.MaxDistance then return nil end
        local score=distance
        if config.TargetMode=="Lowest health" then score=hum.Health
        elseif config.TargetMode=="Crosshair" then
            local camera=workspace.CurrentCamera
            if not camera then return nil end
            local point,visible=camera:WorldToViewportPoint(root.Position)
            if not visible or point.Z<=0 or not valid(point) then
                if not keepIdentity then return nil end
                score=math.huge
            else score=(Vector2.new(point.X,point.Y)-camera.ViewportSize/2).Magnitude end
        end
        return {player=other,frame=root.CFrame,velocity=root.AssemblyLinearVelocity,score=score,distance=distance}
    end
    local function directContext(config,anchor)
        local ctx=baseContext()
        ctx.targetAllowed=false
        ctx.targetReason="Waiting for a living match opponent"
        if not ctx.alive then selected=nil; return ctx end
        local origin=anchor and anchor.Position or ctx.localFrame.Position
        local winner=config.StickyTarget and selected and targetInfo(selected,config,origin,true) or nil
        local pending
        if not winner then
            for _,other in ipairs(Players:GetPlayers()) do
                local candidate=targetInfo(other,config,origin)
                if candidate and (not winner or candidate.score<winner.score or candidate.score==winner.score and candidate.distance<winner.distance) then winner=candidate end
                if not candidate and config.TargetMode~="Crosshair" then
                    local unavailable=targetInfo(other,config,origin,true)
                    if unavailable and unavailable.pending and not pending then pending=unavailable end
                end
            end
        end
        winner=winner or pending
        selected=winner and winner.player or nil
        if winner then
            ctx.targetFrame,ctx.targetVelocity,ctx.targetName=winner.frame,winner.velocity,winner.player.Name
            ctx.targetAllowed,ctx.targetIdentity=not winner.pending,winner.player
            ctx.targetPending=winner.pending==true
            if winner.pending then ctx.targetReason="Tracking enemy; position unavailable" end
        end
        return ctx
    end
    local function lunarTarget(origin,preferred)
        local function candidate(other)
            local item=targetInfo(other,{MatchOnly=true,TeamCheck=true,MaxDistance=0,TargetMode="Nearest"},origin)
            if not item or access:FindClass(other.Character,"ForceField") then return nil end
            local head=access:Find(other.Character,"Head")
            item.headLook=head and head:IsA("BasePart") and head.CFrame:VectorToWorldSpace(Vector3.new(0,0,-1)) or nil
            return item
        end
        if preferred then return candidate(preferred) end
        local best
        for _,other in ipairs(Players:GetPlayers()) do
            local item=candidate(other)
            if item and (not best or item.score<best.score) then best=item end
        end
        return best
    end
    local rotationOwner
    local function releaseRotation()
        local owner=rotationOwner
        rotationOwner=nil
        if owner then
            pcall(function()
                if owner.humanoid.Parent and owner.humanoid.AutoRotate==false then
                    owner.humanoid.AutoRotate=owner.original
                end
            end)
        end
    end
    local function setRotation(active)
        local _,root,humanoid=localData()
        if not active or not root or not root.Parent or root.Anchored or not humanoid or humanoid.Health<=0 then
            releaseRotation();return
        end
        if not rotationOwner or rotationOwner.humanoid~=humanoid then
            releaseRotation()
            rotationOwner={humanoid=humanoid,original=humanoid.AutoRotate}
        end
        humanoid.AutoRotate=false
    end
    local writing=false
    local function place(cf,rotationOnly,preserveVelocity)
        if writing then return false,"Movement update already in progress" end
        local char,root,humanoid=localData()
        if not char or not char.Parent or not root or not root.Parent or not humanoid or humanoid.Health<=0 or root.Anchored then return false end
        local allowed,reason=motion:Frame(cf)
        if not allowed then return false,reason end
        if not motion:Frame(root.CFrame) then return false,"Character frame unavailable" end
        local velocity,angular=root.AssemblyLinearVelocity,root.AssemblyAngularVelocity
        if rotationOnly then cf=CFrame.new(root.Position)*(cf-cf.Position) end
        writing=true
        local ok,problem=pcall(function()
            local rootToPivot=root.CFrame:ToObjectSpace(char:GetPivot())
            local pivot=cf*rootToPivot
            local validPivot,detail=motion:Frame(pivot)
            if not validPivot then error(detail,0) end
            char:PivotTo(pivot)
            root.AssemblyLinearVelocity=(rotationOnly or preserveVelocity) and velocity or Vector3.zero
            root.AssemblyAngularVelocity=preserveVelocity and angular or Vector3.zero
            motion:Record(root,root.CFrame,not rotationOnly)
        end)
        writing=false
        if not ok then return false,tostring(problem) end
        return true
    end
    local function move(cf)
        local preserve=helper and helper:Get("FakeEnabled") and not helper:Get("FakeZeroVelocity")
        return place(cf,false,preserve)
    end
    fake=makeFrekksecFakePosition({now=os.clock,random=function(a,b) return rng:NextNumber(a,b) end,
        character=localData,camera=function() return workspace.CurrentCamera end,
        terrain=function() return workspace.Terrain end,visualParent=function() return ui and ui.ScreenGui end,
        validFrame=function(frame) return motion:Frame(frame) end,
        ownsPosition=function(root) return motion:OwnsPosition(root) end,
        restore=function(cf)
            local _,root=localData()
            if not motion:OwnsPosition(root) then return false end
            return place(cf,false,helper and not helper:Get("FakeZeroVelocity"))
        end})
    lunar=makeFrekksecLunar({now=os.clock,random=function(a,b) return rng:NextNumber(a,b) end,target=lunarTarget})
    perfect=makeFrekksecPerfectLink({now=os.clock,functionFor=function(name) return access:Function(name) end})
    local function resetExtras(restore)
        fake:Release(restore);lunar:Reset();perfect:Clear()
        if helper then helper.FakePositionStatus,helper.LunarStatus="Off","Off" end
    end
    helper=makeController({
        now=os.clock, random=function(a,b) return rng:NextNumber(a,b) end,
        host=host, character=function() return player.Character end,
        environment=function() return matchCheck:Environment(player) end,
        findRuntime=findRuntime, nativeContext=nativeContext, directContext=directContext,
        defense=function(frame,config,ctx) return defense:Apply(frame,config,ctx) end,
        resetDefense=function() defense:Reset() end,
        extra=function(frame,config,ctx,moving)
            if not motion:Frame(frame) then return {frame=frame} end
            local result=lunar:Apply(frame,config,ctx)
            if not motion:Frame(result.frame) then return result end
            local transformed,fakeActive=fake:Apply(result.frame,config,ctx,moving or result.moves)
            if result.active then transformed=CFrame.new(transformed.Position)*(result.frame-result.frame.Position) end
            helper.FakePositionStatus,helper.LunarStatus=fake.Status,lunar.Status
            return {frame=transformed,active=result.active or fakeActive,moves=result.moves or fakeActive,
                returnToAnchor=result.moves,lunarActive=result.active,angles=result.angles,cameraRotation=result.cameraRotation}
        end,
        commitExtras=function(frame,config,ctx,extra,usedLunar)
            fake:Commit(frame)
            if config.LunarCameraLink and usedLunar and extra.cameraRotation and not ctx.nativeDriver then
                perfect:Set(extra.cameraRotation)
                helper.LunarStatus=lunar.Status.." / "..perfect.Status
            else perfect:Clear() end
        end,
        resetExtras=resetExtras,stopFake=function() fake:Release(true);helper.FakePositionStatus="Off" end,
        resetLunar=function() lunar:Reset();perfect:Clear();helper.LunarStatus="Off" end,
        notifyShot=function(config) fake:NotifyShot(config) end,pauseExtras=function()
            perfect:Clear()
            fake:Release(false)
            helper.FakePositionStatus=helper:Get("FakeEnabled") and "Paused for native plan" or "Off"
        end,
        move=move,rotate=function(cf) return place(cf,true) end,setRotation=setRotation,
        validateFrame=function(frame) return motion:Frame(frame) end,
        beforeMove=function()
            if not helper:Get("YieldToMovement") then return true end
            local _,root=localData()
            return motion:Check(root)
        end,
        canReturn=function() local _,root=localData();return motion:OwnsPosition(root) end,
        forgetMovement=function() motion:Forget() end,
        floorHeight=function() return workspace.FallenPartsDestroyHeight end,
        clientFrame=function(engine)
            local inner=engine and engine._innerContext
            if inner and inner.CharacterController then return inner.CharacterController:GetClientCFrame() end
            local _,root=localData(); return fake:Surface() or (root and root.CFrame)
        end,
        report=function(message) warn("[frekksec lua] "..tostring(message)) end,
    })
    env.frekksec=helper
    helper.Version="1.8.0"
    helper.FakePositionStatus,helper.LunarStatus="Off","Off"
    function helper:NotifyShot()
        if self.Destroyed or not self:Get("Enabled") then return end
        fake:NotifyShot(self:GetConfig())
    end
    function helper:SetFakePositionHeight(value)
        local accepted, message = self:Set("FakeHeight", value)
        if accepted then fake:Refresh(self:GetConfig()) end
        return accepted, message
    end
    function helper:GetFakePosition()
        -- Returns the local virtual CFrame and its independent surface anchor.
        return fake:Virtual(), fake:Surface()
    end
    function helper:GetMatchInfo()
        local info=matchCheck:Roster()
        info.CheckEnabled=self:Get("TeamCheck")
        return info
    end
    local function notice(text)
        helper.Message=tostring(text)
        helper.MessageUntil=os.clock()+5
        print("[frekksec lua] "..tostring(text))
        if settingsUI then settingsUI:Notify(text) end
    end
    local storage=makeFrekksecStorage(helper.Schema,{
        readfile=readfile,writefile=writefile,isfile=isfile,isfolder=isfolder,
        makefolder=makefolder,listfiles=listfiles,delfile=delfile,
        encode=function(data) return Http:JSONEncode(data) end,
        decode=function(text) return Http:JSONDecode(text) end,
    })
    helper.OnDestroy=function()
        for _,cleanup in ipairs({
            function() resetExtras(true) end,function() perfect:Destroy() end,releaseRotation,
            function() threatReader:Destroy() end,
            function() if helper.Settings then helper.Settings:Destroy() end end,
            function() if marker then marker:Destroy();marker=nil end end,
            function() if hud then hud:Destroy();hud=nil end end,
            function()
                if ui then ui:Unload() elseif uiEnv.Cleanup then uiEnv.Cleanup()
                elseif uiEnv.ScreenGui then uiEnv.ScreenGui:Destroy() end
            end,
        }) do
            local cleaned,problem=pcall(cleanup)
            if not cleaned then warn("[frekksec lua] Cleanup: "..tostring(problem)) end
        end
        if env.frekksec==helper then env.frekksec=nil end
    end
    local ok,problem=xpcall(function()
        ui=loadUI(uiEnv,access)
        helper._ui,helper._uiEnv=ui,uiEnv -- internals, for debugging and tests
        local window=ui:CreateWindow("frekksec lua  |  v"..helper.Version)
        local controls,exactControls,tabs,groups,live,extras={},{},{},{},{},{}
        -- Where each group of controls lives: tab -> sub-tabs -> left / right groupboxes.
        local PAGES={
            Main={{"control",{"Controller","Compatibility"},{"Actions","Presets"}},{"timing",{"Timing"},{"Live status"}}},
            Orbit={{"orbit",{"Path"},{"Offsets"}}},
            Void={{"void",{"Teleport"},{"Hide"}}},
            Extra={{"extra",{"Extra patterns"},{"Facing","Riot Abuser"}}},
            Targets={{"targets",{"Selection"},{"Display","Current match"}}},
            ["Fake Position"]={{"underground",{"Underground"},{"Visuals"}},{"jitter & angles",{"Jitter"},{"Angles"}}},
            ["Lunar Riot"]={{"lunar",{"Controller","Riot Bypass","Perfect Block"},{"Riot Abuser V1","Riot Abuser V2"}}},
        }
        local TAB_ORDER={"Main","Orbit","Void","Extra","Targets","Fake Position","Lunar Riot"}
        for _,tabName in ipairs(TAB_ORDER) do tabs[tabName]=window:AddTab(tabName) end
        local firstPage={}
        local function groupFor(def)
            local group=groups[def.tab][def.group]
            if not group then -- a group the page table does not know: put it in the first page
                group=firstPage[def.tab]:AddRightGroupbox(def.group)
                groups[def.tab][def.group]=group
            end
            return group
        end
        local building=true
        local function syncControl(key)
            local oldBuilding=building
            building=true
            local control,exact=controls[key],exactControls[key]
            local value=helper:Get(key)
            if control and control.Value~=value then control:SetValue(value) end
            if exact then exact:SetValue(key=="MaxDistance" and value==0 and "unlimited" or tostring(value)) end
            building=oldBuilding
        end
        -- Runs the first time a tab is opened.
        local function buildControls(tabName)
            local wasBuilding=building
            building=true
            groups[tabName]={}
            for _,page in ipairs(PAGES[tabName]) do
                local sub=tabs[tabName]:AddSubTab(page[1])
                firstPage[tabName]=firstPage[tabName] or sub
                for _,name in ipairs(page[2]) do groups[tabName][name]=sub:AddLeftGroupbox(name) end
                for _,name in ipairs(page[3]) do groups[tabName][name]=sub:AddRightGroupbox(name) end
            end
            for _,def in ipairs(helper.Schema) do
                if def.tab~=tabName or def.hidden then continue end
            local key,id=def.key,"frekksec_"..def.key
            local group=groupFor(def)
            if def.fixed~=nil then
                group:AddLabel(def.label)
            elseif type(def.default)=="boolean" then
                group:AddToggle(id,{Text=def.label,Default=helper:Get(key),Tooltip=def.help})
                controls[key]=uiEnv.Toggles[id]
            elseif type(def.default)=="number" then
                local info={Text=def.label,Default=helper:Get(key),Min=def.min,Max=def.max,Rounding=def.decimals,Tooltip=def.help}
                if def.wideDistance then
                    info.Format=function(value) return FrekksecSpace.Format(value,def.unlimited)..(def.unlimited and value==0 and "" or " studs") end
                    info.ToFraction=function(value) return FrekksecSpace.ToSlider(value,def.unlimited)/1000 end
                    info.FromFraction=function(value) return FrekksecSpace.FromSlider(value*1000,def.unlimited) end
                end
                group:AddSlider(id,info)
                controls[key]=uiEnv.Options[id]
                if def.wideDistance then
                    group:AddInput(id.."_exact",{Text=def.unlimited and "Exact range / unlimited" or "Exact studs (0 to 1e37)",Default=def.unlimited and helper:Get(key)==0 and "unlimited" or tostring(helper:Get(key)),Finished=true,Tooltip=def.help})
                    local exact=uiEnv.Options[id.."_exact"]
                    exactControls[key]=exact
                    exact:OnChanged(function()
                        if building then return end
                        local accepted,err=helper:Set(key,exact.Value)
                        if not accepted then notice(err) end
                        syncControl(key)
                    end)
                end
            elseif def.values then
                group:AddDropdown(id,{Text=def.label,Default=helper:Get(key),Values=def.values,Multi=false,Tooltip=def.help})
                controls[key]=uiEnv.Options[id]
            else
                group:AddInput(id,{Text=def.label,Default=helper:Get(key),Finished=true,Tooltip=def.help})
                controls[key]=uiEnv.Options[id]
            end
            if controls[key] then controls[key]:OnChanged(function()
                if not building then
                    local accepted,err=helper:Set(key,controls[key].Value)
                    if not accepted then notice(err) end
                    syncControl(key)
                end
            end) end
            end
            building=wasBuilding
            if tabName=="Void" then
                local note=groups.Void.Teleport:AddLabel("No finite coordinate is infinity.\nExtreme distances lose precision.").TextLabel
                note.TextWrapped=true
            elseif tabName=="Targets" then
                groups.Targets.Selection:AddButton("Unlimited target distance",function() helper:Set("MaxDistance",0);syncControl("MaxDistance") end)
            end
            if extras[tabName] then extras[tabName]() end
            for _,def in ipairs(helper.Schema) do if def.tab==tabName then syncControl(def.key) end end
            if helper.Settings then helper.Settings:ApplyMenu() end
        end
        -- Hand-made groupboxes that sit beside the generated controls.
        extras.Main=function()
            local fastHit, fastHitButton
            fastHitButton = groups.Main.Controller:AddButton("Melee Fast Hit", function()
                if fastHit and fastHit.running then
                    fastHit:Stop()
                    fastHit = nil
                    fastHitButton:SetText("Melee Fast Hit")
                    notice("Melee Fast Hit disabled.")
                else
                    fastHit = startFastHit(player, env)
                    fastHitButton:SetText("Melee Fast Hit [ON]")
                    notice("Melee Fast Hit enabled.")
                end
            end)
            helper:Track({Disconnect=function() if fastHit then fastHit:Stop() end end})
            local actions=groups.Main.Actions
            actions:AddButton("PANIC / RETURN [End]",function() helper:Panic() end)
            actions:AddButton("Capture anchor",function()
                local saved,err=helper:CaptureAnchor(); notice(saved and "Anchor saved." or err)
            end)
            actions:AddButton("Retry optional Frekks link",function()
                helper:Rescan()
                notice(helper:Get("Driver")=="Standalone" and "Select Auto or Frekks to opt into linking." or "Retrying the optional link on the next update.")
            end)
            actions:AddButton("Hide now / release [H]",function()
                helper._uiHide=not helper._uiHide
                helper:SetManualHide(helper._uiHide)
            end)
            actions:AddLabel("F6: enable / disable")
            actions:AddLabel("Enable modes separately in Orbit, Void, and Extra.")
            live.menuHint=actions:AddLabel("Insert: show / hide menu").TextLabel
            local presets=groups.Main.Presets
            for _,name in ipairs({"Aggressive","Balanced","Wide","Orbit"}) do
                presets:AddButton(name,function() helper:ApplyPreset(name); notice(name.." preset applied.") end)
            end
            local info=groups.Main["Live status"]
            live.driver=info:AddLabel("Driver: waiting").TextLabel
            live.mode=info:AddLabel("State: disabled").TextLabel
            live.target=info:AddLabel("Target: none").TextLabel
            live.count=info:AddLabel("Requested points: 0").TextLabel
            live.back=info:AddLabel("Riot Abuser: off").TextLabel
            live.fake=info:AddLabel("Fake position: off").TextLabel
            live.lunar=info:AddLabel("Lunar: off").TextLabel
            for _,label in ipairs({live.mode,live.target,live.back,live.fake,live.lunar}) do label.TextWrapped=true end
            info:AddLabel("Standalone by default")
            info:AddLabel("Frekks link is optional")
            info:AddLabel("Conflicting movement pauses helper.")
            info:AddLabel("0 interval = once per update")
        end
        extras.Targets=function()
            local matchGroup=groups.Targets["Current match"]
            live.match=matchGroup:AddLabel("Match: waiting").TextLabel
            live.opponents=matchGroup:AddLabel("Opponents: none").TextLabel
            live.teammates=matchGroup:AddLabel("Teammates excluded: none").TextLabel
            live.check=matchGroup:AddLabel("Opponent check: on").TextLabel
            for _,label in ipairs({live.match,live.opponents,live.teammates,live.check}) do label.TextWrapped=true end
        end
        for _,name in ipairs(TAB_ORDER) do
            tabs[name]:SetBuilder(function() buildControls(name) end)
        end
        tabs.Main:ShowTab()
        building=false
        local syncRender=function() end
        helper.OnConfigChanged=function(key,value)
            syncControl(key)
            if key=="FakeHeight" or key=="FakeGhost" or key=="FakeGhostColor" then fake:Refresh(helper:GetConfig()) end
            if key=="Enabled" or key=="FakeEnabled" or key=="FakeCamera" or key=="LunarMode" or key=="LunarCameraLink" then syncRender() end
        end
        hud=ui:Create("Frame",{Name="FrekksecStatus",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-72),
            Size=UDim2.new(1,-28,0,46),BackgroundColor3=ui.BackgroundColor,BackgroundTransparency=0.1,
            ClipsDescendants=true,ZIndex=100,Parent=ui.ScreenGui})
        ui:AddToRegistry(hud,{BackgroundColor3="BackgroundColor"})
        ui:MakeDraggable(hud,true)
        ui:Create("UISizeConstraint",{Parent=hud,MaxSize=Vector2.new(520,46)})
        local hudEdge=ui:Create("UIStroke",{Parent=hud,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=ui.AccentColor})
        ui:AddToRegistry(hudEdge,{Color="AccentColor"})
        ui:SurfaceShadow(hud,14)
        local hudLine=ui:Create("Frame",{Parent=hud,Size=UDim2.new(1,0,0,2),ZIndex=101,BackgroundColor3=ui.AccentColor})
        ui:AddToRegistry(hudLine,{BackgroundColor3="AccentColor"})
        statusLabel=ui:CreateLabel({Parent=hud,Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-20,1,-8),
            LineHeight=1.5,TextYAlignment=Enum.TextYAlignment.Center,ZIndex=101})
        ui:AddToRegistry(statusLabel,{TextColor3="FontColor"})
        local menuButton=ui:Create("TextButton",{Name="FrekksecMenuButton",AnchorPoint=Vector2.new(1,0),
            Position=UDim2.new(1,-12,0,12),Size=UDim2.fromOffset(0,24),AutomaticSize=Enum.AutomaticSize.X,
            BackgroundColor3=ui.MainColor,Text="frekksec [Insert]",Font=Enum.Font.Arcade,TextSize=8,
            TextColor3=ui.FontColor,AutoButtonColor=false,ZIndex=110,Parent=ui.ScreenGui})
        ui:Create("UIPadding",{Parent=menuButton,PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)})
        local menuEdge=ui:Create("UIStroke",{Parent=menuButton,ApplyStrokeMode=Enum.ApplyStrokeMode.Border,Thickness=1,Color=ui.OutlineColor})
        ui:AddToRegistry(menuEdge,{Color="OutlineColor"})
        ui:AddToRegistry(menuButton,{BackgroundColor3="MainColor",TextColor3="FontColor"})
        ui:SurfaceShadow(menuButton,8)
        ui:AttachButtonGlow(menuButton)
        settingsUI=makeFrekksecSettings(helper,ui,uiEnv,window,storage,{
            notice=notice,lighting=access:Service("Lighting"),playerName=player.Name,
            clipboard=setclipboard or toclipboard,isHideDown=function() return UIS:IsKeyDown(Enum.KeyCode.H) end,
            setScale=function(value) ui:SetScale(value*100) end,
            menuKeyChanged=function(key)
                menuButton.Text="frekksec ["..key.."]";ui:SetToggleKey(key)
                if live.menuHint then live.menuHint.Text=key..": show / hide menu" end
            end,
            themeChanged=function() if marker then marker.Color=ui.AccentColor end end,
        })
        ui:SetOpen(true)
        settingsUI:ApplyMenu()
        helper:Track(menuButton.Activated:Connect(function() ui:SetOpen(not ui:IsOpen()) end))
        helper:Track(UIS.InputBegan:Connect(function(input,processed)
            if settingsUI:ConsumeInput(input) then return end
            if processed or UIS:GetFocusedTextBox() then return end
            if input.UserInputType==Enum.UserInputType.MouseButton1 then helper:NotifyShot() end
            if input.KeyCode==Enum.KeyCode.F6 then helper:Set("Enabled",not helper:Get("Enabled"))
            elseif input.KeyCode==Enum.KeyCode.End then helper._uiHide=false; helper:Panic()
            elseif input.KeyCode==Enum.KeyCode.H then helper:SetManualHide(true)
            elseif helper:Get("FakeKey")~="None" and input.KeyCode.Name==helper:Get("FakeKey") then
                helper:Set("FakeEnabled",not helper:Get("FakeEnabled"))
            end
        end))
        helper:Track(UIS.InputEnded:Connect(function(input)
            if input.KeyCode==Enum.KeyCode.H then helper:SetManualHide(helper._uiHide==true) end
        end))
        helper:Track(UIS.WindowFocusReleased:Connect(function() helper._uiHide=false; helper:SetManualHide(false) end))
        local renderPrefix="Frekksec_"..Http:GenerateGUID(false)
        local bound,renderConnection={},nil
        local function stopRender()
            for suffix in pairs(bound) do pcall(RunService.UnbindFromRenderStep,RunService,renderPrefix..suffix) end
            table.clear(bound)
            if renderConnection then renderConnection:Disconnect();renderConnection=nil end
        end
        local function protectedUpdate(fn)
            local running=false
            return function(...)
                if running or helper.Destroyed then return end
                running=true
                local succeeded,err=pcall(fn,...)
                if not succeeded then
                    stopRender()
                    helper.Stats.Errors+=1
                    local stopped=pcall(helper.Suspend,helper,tostring(err))
                    if not stopped then pcall(helper.Destroy,helper) end
                end
                running=false
            end
        end
        helper:Track({Disconnect=stopRender})
        syncRender=function()
            local c=helper:GetConfig()
            local camera=c.Enabled and c.FakeEnabled and c.FakeCamera
            local block=c.Enabled and c.LunarCameraLink and c.LunarMode=="Perfect Block"
            if not camera then fake:BeforeCamera() end
            if not block then perfect:Clear() end
            if type(RunService.BindToRenderStep)=="function" then
                local callbacks={
                    BeforeCamera={active=camera,priority=199,run=function() fake:BeforeCamera() end},
                    Camera={active=camera,priority=201,run=function() fake:AfterCamera(helper:GetConfig()) end},
                    Block={active=block,priority=299,run=function() perfect:Update() end},
                }
                for suffix,item in pairs(callbacks) do
                    if item.active and not bound[suffix] then
                        bound[suffix]=true
                        RunService:BindToRenderStep(renderPrefix..suffix,item.priority,protectedUpdate(item.run))
                    elseif not item.active and bound[suffix] then
                        RunService:UnbindFromRenderStep(renderPrefix..suffix);bound[suffix]=nil
                    end
                end
            elseif (camera or block) and not renderConnection then
                renderConnection=RunService.RenderStepped:Connect(protectedUpdate(function()
                    fake:BeforeCamera();fake:AfterCamera(helper:GetConfig());perfect:Update()
                end))
            elseif not camera and not block then stopRender() end
        end
        syncRender()
        local toolConnections={}
        local function bindTools()
            for _,connection in pairs(toolConnections) do connection:Disconnect() end
            table.clear(toolConnections)
            local char=player.Character
            if not char then return end
            local function watch(item)
                if item:IsA("Tool") and not toolConnections[item] then
                    toolConnections[item]=item.Activated:Connect(function() helper:NotifyShot() end)
                end
            end
            for _,item in ipairs(char:GetChildren()) do watch(item) end
            toolConnections.added=char.ChildAdded:Connect(watch)
            toolConnections.removed=char.ChildRemoved:Connect(function(item)
                if toolConnections[item] then toolConnections[item]:Disconnect();toolConnections[item]=nil end
            end)
        end
        bindTools()
        helper:Track(player.CharacterAdded:Connect(bindTools))
        helper:Track({Disconnect=function() for _,connection in pairs(toolConnections) do connection:Disconnect() end;table.clear(toolConnections) end})
        local nextDisplay,nextRoster,nextWatermark=0,0,0
        local averageFrame=1/60
        helper:Track(RunService.Heartbeat:Connect(protectedUpdate(function(dt)
            if dt>0 then averageFrame+=(dt-averageFrame)*0.08 end
            if helper:Get("Enabled") then
                local _,root,humanoid=localData()
                if not root or not humanoid or humanoid.Health<=0 then resetExtras(false)
                elseif helper:Get("MatchOnly") and not matchCheck:Environment(player) then resetExtras(true) end
            end
            helper:Tick()
            if helper.Destroyed or os.clock()<nextDisplay then return end
            nextDisplay=os.clock()+0.12
            settingsUI:UpdateKeys()
            if live.match and os.clock()>=nextRoster then
                nextRoster=os.clock()+0.35
                local roster=helper:GetMatchInfo()
                live.match.Text="Match: "..(roster.EnvironmentId or "not in a match")
                live.opponents.Text="Opponents: "..(#roster.Opponents>0 and table.concat(roster.Opponents,", ") or "none confirmed")
                live.teammates.Text="Teammates: "..(#roster.Teammates>0 and table.concat(roster.Teammates,", ") or "none")
                live.check.Text="Opponent check: "..(roster.CheckEnabled and "ON" or "OFF")..(roster.Unresolved>0 and " | waiting: "..roster.Unresolved or "")
            end
            local message=helper.MessageUntil and os.clock()<helper.MessageUntil and helper.Message or helper.Status
            ui.Side:Set("Driver",helper.Driver)
            ui.Side:Set("State",message)
            -- The scene tracks the currently reported mode; it never drives game movement.
            local sceneMode = "Idle"
            if helper:Get("Enabled") then
                local state = tostring(helper.Status or ""):lower()
                if state:find("void hide", 1, true) or state:find("manual hide", 1, true)
                    or state:find("damage hide", 1, true) or state:find("low health hide", 1, true) then
                    sceneMode = "Void Hide"
                elseif state:find("void tp", 1, true) then sceneMode = "Void TP"
                elseif state:find("orbit", 1, true) then sceneMode = "Orbit"
                elseif state:find("jitter", 1, true) then sceneMode = "Jitter"
                elseif state:find("strafe", 1, true) then sceneMode = "Strafe"
                elseif state:find("sphere", 1, true) then sceneMode = "Random sphere"
                elseif state:find("waiting", 1, true) or state:find("pause", 1, true)
                    or state:find("stopped", 1, true) or state:find("disabled", 1, true) then
                    sceneMode = "Paused"
                elseif helper:Get("MovementEnabled") then
                    local modes = {
                        {"OrbitEnabled", "Orbit"}, {"VoidTPEnabled", "Void TP"},
                        {"VoidHideEnabled", "Void Hide"}, {"JitterEnabled", "Jitter"},
                        {"StrafeEnabled", "Strafe"}, {"SphereEnabled", "Random sphere"},
                    }
                    for _, item in ipairs(modes) do
                        if helper:Get(item[1]) then
                            sceneMode = sceneMode == "Idle" and item[2] or "Hybrid"
                        end
                    end
                elseif helper:Get("FakeEnabled") then sceneMode = "Fake Position"
                elseif helper:Get("LunarMode") ~= "Off" then sceneMode = "Lunar Riot" end
            end
            ui.Side:SetAnimation(sceneMode)
            ui.Side:Set("Target",helper.TargetName or "none")
            ui.Side:Set("Requested points",helper.Stats.Teleports)
            ui.Side:Set("Floor clamps",helper.Stats.Clamped)
            ui.Side:Set("Errors",helper.Stats.Errors)
            ui.Side:Set("Riot Abuser",helper.BackFacingStatus)
            ui.Side:Set("Fake position",helper.FakePositionStatus)
            ui.Side:SetGhostHeight(helper:Get("FakeHeight"))
            ui.Side:Set("Ghost height",FrekksecSpace.Format(helper:Get("FakeHeight")).." studs (local)")
            ui.Side:Set("Lunar",helper.LunarStatus)
            if settingsUI.Prefs.Watermark and os.clock()>=nextWatermark then
                nextWatermark=os.clock()+0.5
                local ok,ping=pcall(player.GetNetworkPing,player)
                ui.Mark:SetFields({"frekksec lua","v"..helper.Version,player.Name,
                    string.format("%d fps",math.round(1/averageFrame)),
                    ok and type(ping)=="number" and string.format("%d ms",math.round(ping*1000)) or "-- ms"})
            end
            if live.driver then
                live.driver.Text="Driver: "..helper.Driver
                live.mode.Text="State: "..helper.Status:sub(1,60)
                live.target.Text="Target: "..(helper.TargetName or "none"):sub(1,40)
                live.count.Text="Requested points: "..helper.Stats.Teleports
                live.back.Text="Riot Abuser: "..helper.BackFacingStatus:sub(1,80)
                live.fake.Text="Fake position: "..helper.FakePositionStatus
                live.lunar.Text="Lunar: "..helper.LunarStatus
            end
            statusLabel.Text=helper.Driver.."  |  "..message.."\npoints: "..helper.Stats.Teleports.."  |  target: "..(helper.TargetName or "none").."  |  End: panic"
            hud.Visible=helper:Get("ShowHud")
            if helper:Get("ShowMarker") and helper:Get("Enabled") and helper.LastDestination then
                if not marker then
                    marker=Instance.new("Part"); marker.Name="frekksec_requested_position"
                    marker.Shape=Enum.PartType.Ball; marker.Size=Vector3.new(1.5,1.5,1.5)
                    marker.Anchored=true; marker.CanCollide=false; marker.CanTouch=false; marker.CanQuery=false
                    marker.CastShadow=false; marker.Material=Enum.Material.Neon; marker.Color=ui.AccentColor
                    marker.Transparency=0.35; marker.Parent=workspace
                end
                marker.CFrame=helper.LastDestination
            elseif marker then marker:Destroy(); marker=nil end
        end)))
        helper:Track(ui.ScreenGui.Destroying:Connect(function() if not helper.Destroyed then helper:Destroy() end end))
        settingsUI:LoadStartup()
        ui:Mount()
    end,function(err) return debug.traceback(tostring(err),2) end)
    if not ok then
        helper:Destroy()
        error("frekksec lua could not start:\n"..tostring(problem),0)
    end
    return helper
end

return startFrekksec(makeFrekksec, loadFrekksecUI)
