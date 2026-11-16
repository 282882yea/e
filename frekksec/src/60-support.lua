local function makeFrekksecMatchCheck(d)
    local M = {}
    local attribute = d.attribute or function(instance,name) return instance:GetAttribute(name) end
    local function id(value)
        if type(value)=="number" then
            if value~=value or math.abs(value)==math.huge then return nil end
            return tostring(value)
        end
        return type(value)=="string" and value~="" and value or nil
    end
    function M:Environment(other)
        return other and id(attribute(other,"EnvironmentID")) or nil
    end
    local function registry()
        local fighters=d.registry and d.registry()
        if type(fighters)~="table" or type(fighters.StateByPlayer)~="table"
            or type(fighters.EnemyByPlayer)~="table" then return nil end
        local own=fighters.LocalState
        if type(own)~="table" or own.Player~=d.player then return nil end
        return fighters
    end
    function M:Classify(other, suppliedState)
        if typeof(other)~="Instance" or not other:IsA("Player") or other.Parent~=d.players or other==d.player then
            return false,"Not another player","excluded"
        end
        local ourEnvironment=self:Environment(d.player)
        if not ourEnvironment then return false,"Waiting for a match","outside" end
        if self:Environment(other)~=ourEnvironment then return false,"Not in your current match","outside" end
        local ourTeam,theirTeam=id(attribute(d.player,"TeamID")),id(attribute(other,"TeamID"))
        if ourTeam and theirTeam and ourTeam==theirTeam then return false,"Teammate excluded","teammate" end
        local fighters=registry()
        local state=suppliedState
        if fighters then
            local own=fighters.LocalState
            if own.IsSpectating then return false,"Spectating; orbit paused","unknown" end
            if id(own.EnvironmentId)~=ourEnvironment then return false,"Waiting for current match data","unknown" end
            state=fighters.StateByPlayer[other]
            if suppliedState and state~=suppliedState then return false,"Stale opponent state","unknown" end
            if not state then return false,"Waiting for opponent list","unknown" end
        end
        if type(state)=="table" then
            if state.Player~=other or id(state.EnvironmentId)~=ourEnvironment then
                return false,"Opponent changed match","unknown"
            end
            if state.IsEnemy~=true then return false,"Not a confirmed match opponent","unknown" end
            if fighters and fighters.EnemyByPlayer[other]~=state then
                return false,"Opponent left the enemy list","unknown"
            end
            return true,"Confirmed Frekks opponent","opponent"
        end
        if ourTeam and theirTeam then return true,"Confirmed match opponent","opponent" end
        if not ourTeam and not theirTeam and d.player.Neutral==false and other.Neutral==false
            and d.player.Team and other.Team then
            if d.player.Team==other.Team then return false,"Teammate excluded","teammate" end
            return true,"Confirmed match opponent","opponent"
        end
        return false,"Waiting for team data","unknown"
    end
    function M:Roster()
        local result={EnvironmentId=self:Environment(d.player),Opponents={},Teammates={},Unresolved=0}
        for _,other in ipairs(d.players:GetPlayers()) do
            local allowed,_,kind=self:Classify(other)
            if allowed then table.insert(result.Opponents,other.Name)
            elseif kind=="teammate" then table.insert(result.Teammates,other.Name)
            elseif kind=="unknown" then result.Unresolved=result.Unresolved+1 end
        end
        table.sort(result.Opponents)
        table.sort(result.Teammates)
        return result
    end
    return M
end

local function makeFrekksecAccess(env, lookup, useReferences)
    local A = {}
    local references=setmetatable({}, {__mode="kv"})
    function A:Function(name)
        local caps = rawget(env, "FrekksHailCaps") or rawget(_G, "FrekksHailCaps")
        if type(caps) == "table" then
            if type(caps.stubbed) == "table" and caps.stubbed[name] then return nil end
            if type(caps.has) == "function" then
                local ok, supported = pcall(caps.has, name)
                if not ok or not supported then return nil end
            end
        end
        local value = rawget(env, name)
        if type(value) ~= "function" then value = lookup(name) end
        return type(value) == "function" and value or nil
    end
    function A:Ref(instance)
        if typeof(instance) ~= "Instance" then return instance end
        if useReferences and not useReferences() then return instance end
        if references[instance] then return references[instance] end
        local clone = self:Function("cloneref") or self:Function("clonereference")
        if clone then
            local ok, reference = pcall(clone, instance)
            if ok and typeof(reference) == "Instance" then references[instance]=reference;return reference end
        end
        return instance
    end
    function A:Service(name)
        return self:Ref(game:GetService(name))
    end
    function A:Attribute(instance, name)
        return self:Ref(instance):GetAttribute(name)
    end
    function A:Find(instance, name)
        return self:Ref(instance):FindFirstChild(name)
    end
    function A:FindClass(instance, name)
        return self:Ref(instance):FindFirstChildOfClass(name)
    end
    function A:Scan(callback)
        local scan = self:Function("getgc")
        if not scan then return false, "Frekks link requires working getgc(true)" end
        local ok, objects = pcall(scan, true)
        if not ok or type(objects) ~= "table" then
            return false, "getgc(true) could not inspect the Frekks runtime"
        end
        local snapshot = setmetatable({}, {__mode = "v"})
        for key, value in next, objects do snapshot[key] = value end
        objects = nil
        for _, value in next, snapshot do
            local inspected, done = pcall(callback, value)
            if inspected and done then break end
        end
        return true
    end
    return A
end

local function makeFrekksecBackFacing(d)
    local B = {}
    local held, holdUntil, yaw, pitch, lastTime
    local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
    local function vector(v)
        return typeof(v)=="Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
    end
    local function magnitude(x,y,z)
        local scale=math.max(math.abs(x),math.abs(y),math.abs(z))
        if scale==0 then return 0 end
        return scale*math.sqrt((x/scale)^2+(y/scale)^2+(z/scale)^2)
    end
    function B:Reset() held,holdUntil,yaw,pitch,lastTime=nil,nil,nil,nil,nil end
    local function delta(a,b) return (a-b+math.pi)%(math.pi*2)-math.pi end
    local function angles(frame)
        local look=frame:VectorToWorldSpace(Vector3.new(0,0,-1))
        local up=frame:VectorToWorldSpace(Vector3.new(0,1,0))
        local right=frame:VectorToWorldSpace(Vector3.new(1,0,0))
        local p=math.asin(math.clamp(look.Y,-1,1))
        local horizontal=math.sqrt(look.X*look.X+look.Z*look.Z)
        local y=horizontal>0.000001 and math.atan2(-look.X,-look.Z) or math.atan2(-right.Z,right.X)
        if horizontal>0.000001 and up.Y<0 then y,p=y+math.pi,math.pi-p end
        return y,p
    end
    local function measure(other,origin,rotation,position,config)
        if not vector(origin) or not vector(position) then return nil end
        local x,y,z=position.X-origin.X,position.Y-origin.Y,position.Z-origin.Z
        local distance=magnitude(x,y,z)
        if not finite(distance) or distance<0.1 or config.BackRange>0 and distance>config.BackRange then return nil end
        local hasAim=typeof(rotation)=="Vector2" and finite(rotation.X) and finite(rotation.Y)
        local forward,miss=0,math.huge
        if hasAim then
            local c=math.cos(rotation.X)
            local ax,ay,az=-math.sin(rotation.Y)*c,math.sin(rotation.X),-math.cos(rotation.Y)*c
            forward=x*ax+y*ay+z*az
            miss=magnitude(x-ax*forward,y-ay*forward,z-az*forward)
        end
        return {Player=other,Direction=Vector3.new(x/distance,y/distance,z/distance),Miss=miss,Distance=distance,
            HasAim=hasAim,Aiming=hasAim and forward>0 and miss<=config.BackAimRadius}
    end
    local function candidate(other,fighter,position,config)
        if not d.allowed(other,fighter) then return nil end
        local state=fighter.Character and fighter.Character.State
        if not state or not state.Alive or state.Model~=other.Character or not state.Model.Parent then return nil end
        local root=state.RootPart
        if not root or not root.Parent then return nil end
        local observer=fighter.ItemObserver
        local rotation
        if observer and type(observer.EquippedItemAsGun)=="function" and observer:EquippedItemAsGun() then
            rotation=fighter._data and rawget(fighter._data,"CameraRotation")
        end
        local head=state.HitboxHead
        local origin=head and head.Parent and head.Position or root.Position
        return measure(other,origin,rotation,position,config)
    end
    function B:Apply(frame,config,ctx)
        if not config.BackFacing then self:Reset();return nil,"Off" end
        local now=d.now()
        local dt=lastTime and math.clamp(now-lastTime,0,0.1) or 1/60
        lastTime=now
        local best,previous,nearest
        local mode=config.BackTargetMode or "Aim only"
        local function consider(item)
            if not item then return end
            if item.Player==held and item.HasAim then previous=item end
            if item.Aiming and (not best or item.Miss<best.Miss
                or item.Miss==best.Miss and item.Distance<best.Distance) then best=item end
            if (mode=="Nearest opponent" or mode=="Auto" and not item.HasAim)
                and (not nearest or item.Distance<nearest.Distance) then nearest=item end
        end
        if ctx.nativeDriver then
            local fighters=d.registry and d.registry()
            for other,fighter in pairs(fighters and fighters.EnemyByPlayer or {}) do
                local ok,item=pcall(candidate,other,fighter,frame.Position,config)
                if ok then consider(item) end
            end
        else
            for _,item in ipairs(d.candidates and d.candidates() or {}) do
                if d.allowed(item.Player) then
                    consider(measure(item.Player,item.Origin,item.Rotation,frame.Position,config))
                end
            end
        end
        local holding,fallback=false,false
        if mode=="Nearest opponent" then best,fallback=nearest,nearest~=nil;held,holdUntil=nil,nil
        elseif best then held,holdUntil=best.Player,now+config.BackHoldTime
        elseif previous and holdUntil and now<holdUntil then best,holding=previous,true
        elseif nearest then best,fallback=nearest,true;held,holdUntil=nil,nil end
        if not best then held,holdUntil,yaw,pitch=nil,nil,nil,nil;return nil,"No matching enemy threat" end
        if not yaw then yaw,pitch=angles(frame) end
        local direction=best.Direction
        local horizontal=math.sqrt(direction.X*direction.X+direction.Z*direction.Z)
        local targetYaw=horizontal>0.000001 and math.atan2(-direction.X,-direction.Z) or yaw
        local targetPitch=math.asin(math.clamp(direction.Y,-1,1))
        local invertedYaw,invertedPitch=targetYaw+math.pi,math.pi-targetPitch
        local pose=config.BackPose or "Auto"
        if pose=="Upside down" or pose=="Auto" and
            delta(invertedYaw,yaw)^2+delta(invertedPitch,pitch)^2+0.000000001
                <delta(targetYaw,yaw)^2+delta(targetPitch,pitch)^2 then
            targetYaw,targetPitch=invertedYaw,invertedPitch
        end
        if config.BackTurnSpeed<=0 then yaw,pitch=targetYaw,targetPitch
        else
            local dy,dp=delta(targetYaw,yaw),delta(targetPitch,pitch)
            local distance=math.sqrt(dy*dy+dp*dp)
            local limit=math.rad(config.BackTurnSpeed)*dt
            local step=distance>0 and math.min(1,limit/distance) or 1
            yaw,pitch=yaw+dy*step,pitch+dp*step
        end
        local result=CFrame.new(frame.Position)*CFrame.Angles(0,yaw,0)*CFrame.Angles(pitch,0,0)
        return result,(fallback and "Nearest: " or holding and "Holding: " or "Facing away: ")..best.Player.Name,
            {Kind="Normalized",Pitch=math.deg(pitch)%360,Yaw=math.deg(yaw)%360}
    end
    return B
end

local function makeFrekksecThreatReader(d)
    local R = {}
    local controller,module,job,ticket
    local nextLoad,busy,destroyed=0,false,false
    local function ensureController()
        if destroyed or busy or d.now()<nextLoad then return end
        nextLoad=d.now()+5
        local scripts=d.access:Find(d.player,"PlayerScripts")
        local controllers=scripts and d.access:Find(scripts,"Controllers")
        local found=controllers and d.access:Find(controllers,"FighterController")
        if found~=module then module,controller=found,nil end
        if controller or not module or not module:IsA("ModuleScript") then return end
        busy=true
        local request={}
        ticket=request
        local pending=d.spawn(function()
            local ok,result=pcall(d.load,module)
            if destroyed or ticket~=request then return end
            if ok and type(result)=="table" and type(result.GetFighter)=="function" and module.Parent then
                controller=result
            end
            busy=false
            job=nil
        end)
        if busy then job=pending end
    end
    local function read(other)
        if not d.allowed(other) then return nil end
        local model=other.Character
        local root=model and d.access:Find(model,"HumanoidRootPart")
        local humanoid=model and d.access:FindClass(model,"Humanoid")
        if not model or not model.Parent or not root or not root.Parent or not humanoid or humanoid.Health<=0 then return nil end
        local head=d.access:Find(model,"Head")
        local origin=head and head:IsA("BasePart") and head.Position or root.Position
        local rotation
        if controller and module and module.Parent then
            local ok,fighter=pcall(controller.GetFighter,controller,other)
            if ok and not fighter then ok,fighter=pcall(controller.GetFighter,controller,model) end
            if ok and type(fighter)=="table" then
                local data=rawget(fighter,"Data")
                rotation=type(data)=="table" and rawget(data,"CameraRotation") or nil
            end
        end
        return {Player=other,Origin=origin,Rotation=rotation}
    end
    function R:Candidates()
        if destroyed then return {} end
        ensureController()
        local result={}
        for _,other in ipairs(d.players:GetPlayers()) do
            local ok,item=pcall(read,other)
            if ok and item then table.insert(result,item) end
        end
        return result
    end
    function R:Destroy()
        destroyed=true
        ticket,controller,module=nil,nil,nil
        if job and d.cancel then pcall(d.cancel,job) end
        job=nil
    end
    return R
end

local function makeFrekksecMotionGuard(d)
    local G={}
    local owner
    function G:Frame(frame)
        if typeof(frame)~="CFrame" or not FrekksecSpace.Vector(frame.Position) then return false,"Invalid position" end
        local x=frame:VectorToWorldSpace(Vector3.new(1,0,0))
        local y=frame:VectorToWorldSpace(Vector3.new(0,1,0))
        local z=frame:VectorToWorldSpace(Vector3.new(0,0,1))
        for _,axis in ipairs({x,y,z}) do
            if not FrekksecSpace.Vector(axis) or math.abs(axis:Dot(axis)-1)>.02 then return false,"Invalid rotation" end
        end
        if math.abs(x:Dot(y))>.02 or math.abs(x:Dot(z))>.02 or math.abs(y:Dot(z))>.02 then return false,"Invalid rotation" end
        return true
    end
    function G:Check(root)
        if not owner or owner.root~=root or not root or not root.Parent then return true end
        if not self:Frame(root.CFrame) then return false,"Another mover supplied an invalid position" end
        local displacement=FrekksecSpace.Delta(root.Position,owner.frame.Position)
        if owner.moving then
            local dt=math.clamp(d.now()-owner.time,0,0.25)
            local speed=FrekksecSpace.Vector(owner.velocity) and FrekksecSpace.Delta(owner.velocity,Vector3.zero) or 0
            local allowance=math.clamp(speed*dt*3+4,6,64)
            if displacement>allowance then
                return false,"Another mover changed your position"
            end
        end
        if not owner.moving and displacement>0.05 then return true end
        local currentLook=root.CFrame:VectorToWorldSpace(Vector3.new(0,0,-1))
        local writtenLook=owner.frame:VectorToWorldSpace(Vector3.new(0,0,-1))
        local currentUp=root.CFrame:VectorToWorldSpace(Vector3.new(0,1,0))
        local writtenUp=owner.frame:VectorToWorldSpace(Vector3.new(0,1,0))
        if currentLook:Dot(writtenLook)<.5 or currentUp:Dot(writtenUp)<.5 then
            return false,"Another controller changed your rotation"
        end
        return true
    end
    function G:OwnsPosition(root)
        return owner~=nil and owner.moving and owner.root==root and self:Check(root)
    end
    function G:Record(root,frame,moving)
        owner={root=root,frame=frame,moving=moving,velocity=root.AssemblyLinearVelocity,time=d.now()}
    end
    function G:Forget() owner=nil end
    return G
end

-- Movement and counter-rotation adapted from the provided Lunar prem source.
local function makeFrekksecLunar(d)
    local L={Status="Off"}
    local mode,started,lastTime,seed,selected,nextTarget
    function L:Reset()
        mode,started,lastTime,seed,selected,nextTarget=nil,nil,nil,nil,nil,nil
        self.Status="Off"
    end
    local function offset(target,position,distance,height)
        local look=target.frame:VectorToWorldSpace(Vector3.new(0,0,-1))
        local right=Vector3.new(-look.Z,0,look.X)
        if right.Magnitude<0.0001 then right=target.frame:VectorToWorldSpace(Vector3.new(1,0,0)) end
        right=right.Unit
        local delta=Vector3.zero
        if position=="Behind" then delta=-look*distance elseif position=="Front" then delta=look*distance
        elseif position=="Above" then delta=Vector3.new(0,distance,0) elseif position=="Below" then delta=Vector3.new(0,-distance,0)
        elseif position=="Left" then delta=-right*distance elseif position=="Right" then delta=right*distance end
        return target.frame.Position+delta+Vector3.new(0,height or 0,0)
    end
    function L:Apply(frame,c,ctx)
        local result={frame=frame,active=false,moves=false}
        if c.LunarMode=="Off" then self:Reset();return result end
        local now=d.now()
        if mode~=c.LunarMode then
            self:Reset();mode=c.LunarMode;started=now;seed=d.random(1000,9999)
        end
        local dt=lastTime and math.clamp(now-lastTime,0,0.1) or 1/60
        lastTime=now
        local t=now-started
        local target
        if mode~="Riot Abuser V2" then
            if mode=="Riot Bypass" and selected and now<(nextTarget or 0) then target=d.target(frame.Position,selected) end
            if not target then target=d.target(frame.Position);nextTarget=now+c.LunarBypassRate end
            selected=target and target.player or nil
        end
        if mode=="Riot Abuser V1" then
            local position=target and offset(target,c.LunarV1Position,c.LunarV1Distance) or frame.Position
            result.frame=CFrame.new(position)*CFrame.Angles(0,(t*math.rad(c.LunarV1Speed))%(math.pi*2),0)
            result.active,result.moves=true,target~=nil
        elseif mode=="Riot Abuser V2" then
            local speed=c.LunarV2Speed
            local spin=frame*CFrame.Angles(math.rad(speed*0.37*dt*math.sin(t*3.1)),math.rad(speed*dt),
                math.rad(speed*0.19*dt*math.cos(t*5.7+seed)))
            local spread=c.LunarV2Spread/300
            local x=(d.random(0,1)-0.5)*c.LunarV2XZ*spread*2+math.noise(t*9,seed,0)*c.LunarV2XZ*spread
            local y=(d.random(0,1)-0.5)*c.LunarV2Y*spread+math.noise(0,t*9,seed)*c.LunarV2Y*spread*0.3
            local z=(d.random(0,1)-0.5)*c.LunarV2XZ*spread*2+math.noise(0,0,t*9+seed)*c.LunarV2XZ*spread
            result.frame=spin+Vector3.new(x,math.max(spin.Position.Y+y,2)-spin.Position.Y,z)
            result.active,result.moves=true,true
        elseif mode=="Riot Bypass" and target then
            local destination=offset(target,c.LunarBypassPosition,c.LunarBypassDistance,c.LunarBypassHeight)
            local alpha=c.LunarBypassSnap and 1 or math.clamp(dt/c.LunarBypassRate,0,1)
            local a,b=frame.Position,destination
            result.frame=CFrame.new(a.X*(1-alpha)+b.X*alpha,a.Y*(1-alpha)+b.Y*alpha,a.Z*(1-alpha)+b.Z*alpha)
            result.active,result.moves=true,true
        elseif mode=="Perfect Block" and target then
            local look=target.frame:VectorToWorldSpace(Vector3.new(0,0,-1))
            local counter=Vector3.new(-look.X,0,-look.Z)
            local pitch=target.headLook and math.asin(math.clamp(target.headLook.Y,-1,1)) or 0
            local yaw=(math.atan2(look.X,look.Z)+math.pi+math.pi)%(2*math.pi)-math.pi
            result.cameraRotation=Vector2.new(-pitch,yaw)
            result.angles={Kind="Normalized",Pitch=math.deg(-pitch)%360,Yaw=math.deg(yaw)%360}
            if counter.Magnitude>0.001 then result.frame=FrekksecSpace.Face(frame.Position,counter) end
            result.active=true
        end
        self.Status=result.active and mode..(target and " / "..target.player.Name or "") or "Waiting for match opponent"
        result.status=self.Status
        return result
    end
    return L
end

-- Underground position, walking, jitter, and pose adapted from the provided Sleepy source.
-- Custom-height engine adapted to Frekksec's existing movement/cleanup lifecycle.
-- BaseCF is the surface anchor; VirtualCF is only the local ghost above it.
-- Physical destinations, shot handoff, camera correction and restore use BaseCF.
local function makeFrekksecFakePosition(d)
    local F = {Status = "Off"}
    local state = {Height = 0, Depth = 5.8, Native = false}
    local properties, parts, connections = {}, {}, {}
    local ghost, track, cameraOwner
    local handoffUntil, nextAnimation = 0, 0
    local function disconnectCharacter()
        for _, connection in ipairs(connections) do pcall(connection.Disconnect, connection) end
        table.clear(connections)
        table.clear(parts)
    end
    local function ownsRoot(root)
        if not root or not state.LastWrittenCF then return false end
        if d.ownsPosition then return d.ownsPosition(root) == true end
        return FrekksecSpace.Delta(root.Position, state.LastWrittenCF.Position) < 0.05
    end
    local function restoreCamera()
        local owner = cameraOwner
        cameraOwner = nil
        if owner then pcall(function()
            if owner.camera.CFrame == owner.applied then owner.camera.CFrame = owner.original end
        end) end
    end
    local function restoreProperties(key, onlyPart)
        for part, entries in pairs(properties) do
            if not onlyPart or part == onlyPart then
                for name, entry in pairs(entries) do
                    if not key or key == name then
                        pcall(function() if part[name] == entry.forced then part[name] = entry.original end end)
                        entries[name] = nil
                    end
                end
                if next(entries) == nil then properties[part] = nil end
            end
        end
    end
    local function force(part, key, value)
        local current = part[key]
        local entries = properties[part] or {}
        properties[part] = entries
        local entry = entries[key]
        if not entry then
            entry = {original = current, forced = value}
            entries[key] = entry
        elseif current ~= entry.forced then entry.original = current end
        entry.forced = value
        if current ~= value then part[key] = value end
    end
    local function stopAnimation()
        if track then pcall(function() track:Stop(0.1); track:Destroy() end); track = nil end
    end
    local function removeGhost()
        if ghost then pcall(ghost.Destroy, ghost); ghost = nil end
    end
    local function updateVirtual(c)
        state.Height, state.Depth = c.FakeHeight or 0, c.FakeDepth
        state.VirtualCF, state.VisualWarning = nil, nil
        if not state.BaseCF then return end
        local virtual = state.BaseCF + Vector3.new(0, state.Height, 0)
        if not FrekksecSpace.Vector(virtual.Position) then
            state.VisualWarning = "Ghost position is outside the finite coordinate range"
            return
        end
        state.VirtualCF = virtual
    end
    local function updateGhost(c)
        if not c.FakeGhost or not state.VirtualCF then removeGhost(); return end
        local parent = d.visualParent()
        if not parent then removeGhost(); return end
        local ok, problem = pcall(function()
            if not ghost or not ghost.Parent then
                removeGhost()
                ghost = Instance.new("BoxHandleAdornment")
                ghost.Name, ghost.Size = "FrekksecFakePositionGhost", Vector3.new(2, 5, 1)
                ghost.Transparency, ghost.AlwaysOnTop, ghost.ZIndex = 0.55, true, 5
                ghost.Adornee, ghost.Parent = d.terrain(), parent
            end
            local color = type(c.FakeGhostColor) == "string" and c.FakeGhostColor or ""
            local r, g, b = color:match("^#?(%x%x)(%x%x)(%x%x)$")
            ghost.Color3 = r and Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)) or Color3.fromRGB(0, 162, 255)
            ghost.CFrame = state.VirtualCF
        end)
        if not ok then
            removeGhost()
            state.VisualWarning = "Ghost visual unavailable: " .. tostring(problem):sub(1, 80)
        end
    end
    local function attachCharacter(character)
        state.Character = character
        local function added(part)
            if part:IsA("BasePart") or part:IsA("Decal") then parts[part] = true end
        end
        for _, part in ipairs(character:GetDescendants()) do added(part) end
        table.insert(connections, character.DescendantAdded:Connect(added))
        table.insert(connections, character.DescendantRemoving:Connect(function(part)
            if parts[part] then restoreProperties(nil, part); parts[part] = nil end
        end))
    end
    function F:Release(restorePosition)
        restoreCamera()
        disconnectCharacter()
        restoreProperties()
        stopAnimation()
        removeGhost()
        local character, root, humanoid = d.character()
        if restorePosition and not state.Native and character == state.Character and root and humanoid
            and humanoid.Health > 0 and state.BaseCF and ownsRoot(root) then
            pcall(d.restore, state.BaseCF)
        end
        state.Character, state.BaseCF, state.VirtualCF, state.LastWrittenCF = nil, nil, nil, nil
        state.LastTime, state.Started, state.Native, state.VisualWarning = nil, nil, false, nil
        handoffUntil, nextAnimation = 0, 0
        self.Status = "Off"
    end
    function F:Surface()
        local character, root = d.character()
        if character ~= state.Character or not root or not state.BaseCF then return nil end
        if not state.Native and state.LastWrittenCF and not ownsRoot(root) then return nil end
        return state.BaseCF
    end
    function F:Virtual()
        if not self:Surface() then return nil end
        return state.VirtualCF
    end
    function F:Refresh(c)
        if not c.Enabled or not c.FakeEnabled or not state.BaseCF then return end
        local character = d.character()
        if character ~= state.Character then self:Release(false); return end
        updateVirtual(c)
        updateGhost(c)
    end
    function F:NotifyShot(c)
        if c.FakeEnabled and c.FakeHandoff then handoffUntil = d.now() + 1 / 30 end
    end
    function F:Commit(frame)
        if state.BaseCF then state.LastWrittenCF = frame end
    end
    function F:BeforeCamera() restoreCamera() end
    function F:AfterCamera(c)
        if not c.Enabled or not c.FakeEnabled or not c.FakeCamera or state.Native
            or not state.BaseCF or not state.LastWrittenCF or not self:Surface() then return end
        local camera = d.camera()
        if not camera then return end
        restoreCamera()
        local original = camera.CFrame
        local applied = original + (state.BaseCF.Position - state.LastWrittenCF.Position)
        if d.validFrame and not d.validFrame(applied) then return end
        camera.CFrame = applied
        cameraOwner = {camera = camera, original = original, applied = applied}
    end
    function F:Apply(frame, c, ctx, moving)
        if not c.FakeEnabled then self:Release(true); return frame, false end
        local character, root, humanoid = d.character()
        if not character or not root or not humanoid or humanoid.Health <= 0 then
            self:Release(false); return frame, false
        end
        if d.validFrame and not d.validFrame(frame) then self:Release(false); return frame, false end
        local now = d.now()
        if character ~= state.Character then
            self:Release(false)
            attachCharacter(character)
            state.BaseCF, state.Started = frame, now
        end
        state.Native = ctx.nativeDriver == true
        local dt = state.LastTime and math.clamp(now - state.LastTime, 0, 0.1) or 1 / 60
        state.LastTime = now
        if moving or state.Native or not state.BaseCF or (state.LastWrittenCF and not ownsRoot(root)) then state.BaseCF = frame end
        if not moving and not state.Native then
            local camera = d.camera()
            local look = camera and camera.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1)) or Vector3.new(0, 0, -1)
            local position, direction = state.BaseCF.Position, humanoid.MoveDirection
            if c.FakeWalk and FrekksecSpace.Vector(direction) and direction.Magnitude > 0 then
                position = position + direction * ((humanoid.WalkSpeed or 16) * dt)
            end
            state.BaseCF = CFrame.new(position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
        end
        updateVirtual(c)
        if not c.FakeHide then restoreProperties("Transparency") end
        if not c.FakeNoclip then restoreProperties("CanCollide") end
        if c.FakeHide or c.FakeNoclip then
            for part in pairs(parts) do
                if c.FakeHide then force(part, "Transparency", 1) end
                if c.FakeNoclip and part:IsA("BasePart") then force(part, "CanCollide", false) end
            end
        end
        if track and not track.IsPlaying then stopAnimation() end
        if c.FakeAnimation then
            if not track and now >= nextAnimation then
                nextAnimation = now + 5
                local animator = humanoid:FindFirstChildOfClass("Animator")
                if animator then
                    local animation = Instance.new("Animation")
                    animation.AnimationId = "rbxassetid://10714003221"
                    local pending
                    local ok, result = pcall(function()
                        pending = animator:LoadAnimation(animation)
                        pending.Priority, pending.Looped = Enum.AnimationPriority.Action4, true
                        pending:Play(0, 1, 0)
                        pending.TimePosition = 1.48
                        pending:AdjustSpeed(0)
                        return pending
                    end)
                    animation:Destroy()
                    if ok then track = result elseif pending then pcall(function() pending:Stop(); pending:Destroy() end) end
                end
            end
        else stopAnimation(); nextAnimation = 0 end
        updateGhost(c)
        if now < handoffUntil then self.Status = "Shot handoff / surface"; return state.BaseCF, true end
        local offset = Vector3.new(0, -state.Depth, 0)
        if c.FakePanic then
            local low, high = math.min(c.FakeMinX, c.FakeMaxX), math.max(c.FakeMinX, c.FakeMaxX)
            offset += Vector3.new(d.random(low, high), 0, c.FakeJitterZ and d.random(-(high - low) / 2, (high - low) / 2) or 0)
        end
        local pitch, yaw = c.FakeUsePitch and c.FakePitch or 0, c.FakeYaw
        if c.FakePose == "Inverted pitch" then pitch = -89
        elseif c.FakePose == "Zero pitch" then pitch = 0
        elseif c.FakePose == "Backward look" then pitch, yaw = 0, 180
        elseif c.FakePose == "Spinbot" then yaw = ((now - state.Started) * c.FakeSpinSpeed) % 360 end
        self.Status = (state.Native and "Linked underground" or "Underground") .. " / ghost +" .. FrekksecSpace.Format(state.Height)
        if state.VisualWarning then self.Status ..= " / ghost unavailable"
        elseif c.FakeAnimation and not track then self.Status ..= " / animation unavailable" end
        return (state.BaseCF + offset) * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0), true
    end
    return F
end

local function makeFrekksecPerfectLink(d)
    local P={Status="Body only (camera link unavailable)"}
    local camera,original,applied,desired
    local nextScan=0
    function P:Clear()
        if camera and applied then pcall(function() if camera.Rotation==applied then camera.Rotation=original end end) end
        original,applied,desired=nil,nil,nil
    end
    function P:Set(value)
        if not value then self:Clear();return end
        desired=value
        if not camera and d.now()>=nextScan then
            nextScan=d.now()+2
            local filter,upvalues=d.functionFor("filtergc"),d.functionFor("getupvalues")
            if filter and upvalues then
                pcall(function()
                    local fn=filter("function",{Name="_UpdateCharacterRotation"},true)
                    if type(fn)~="function" then return end
                    for _,item in pairs(upvalues(fn)) do
                        if type(item)=="table" and typeof(rawget(item,"Rotation"))=="Vector2" then camera=item;break end
                    end
                end)
            end
        end
        self.Status=camera and "Body + camera" or "Body only (camera link unavailable)"
    end
    function P:Update()
        if not desired or not camera then return end
        local ok=pcall(function()
            if not applied or camera.Rotation~=applied then original=camera.Rotation end
            camera.Rotation=desired;applied=desired
        end)
        if not ok then camera=nil;applied=nil;self.Status="Body only (camera link unavailable)" end
    end
    function P:Destroy() self:Clear();camera=nil end
    return P
end

local function startFastHit(player, env)
    local speed = 1 / (1 + 1e69 / 100)
    local state = {running = true, hooks = {}, changes = {}}
    local function restoreInfo(info, changed)
        if not table.isfrozen(info) then
            for field, entry in pairs(changed) do
                if rawget(info, field) == entry.forced then rawset(info, field, entry.original) end
            end
        end
        if state.changes[info] == changed then state.changes[info] = nil end
    end
    local function moduleAt(...)
        local current = player:FindFirstChild("PlayerScripts")
        for _, name in ipairs({...}) do
            current = current and current:FindFirstChild(name)
        end
        if not current or not current:IsA("ModuleScript") then return nil end
        local ok, module = pcall(require, current)
        return ok and type(module) == "table" and module or nil
    end
    local function wrap(module, fields, bladeOnly)
        if not state.running or not module or state.hooks[module] or table.isfrozen(module)
            or type(module.StartShooting) ~= "function" then return end
        local original = module.StartShooting
        local function replacement(self, ...)
            if not state.running then return original(self, ...) end
            local info = type(self) == "table" and self.Info
            local apply = not bladeOnly
            if bladeOnly and type(self) == "table" and type(self.Get) == "function" then
                local ok, mode = pcall(self.Get, self, "Mode")
                apply = ok and mode == "Blade"
            end
            if not apply or type(info) ~= "table" or table.isfrozen(info) or state.changes[info] then return original(self, ...) end
            local changed = {}
            state.changes[info] = changed
            for _, field in ipairs(fields) do
                local value = rawget(info, field)
                if type(value) == "number" and value >= 0 and value < math.huge then
                    local forced = value * speed
                    changed[field] = {original = value, forced = forced}
                    rawset(info, field, forced)
                end
            end
            local result = table.pack(pcall(original, self, ...))
            restoreInfo(info, changed)
            if not result[1] then error(result[2], 0) end
            return table.unpack(result, 2, result.n)
        end
        module.StartShooting = replacement
        state.hooks[module] = {original = original, replacement = replacement}
    end
    function state:Stop()
        self.running = false
        for info, changed in pairs(self.changes) do restoreInfo(info, changed) end
        for module, hook in pairs(self.hooks) do
            if not table.isfrozen(module) and module.StartShooting == hook.replacement then
                module.StartShooting = hook.original
            end
        end
        table.clear(self.hooks)
        if self.worker and type(task.cancel) == "function" then pcall(task.cancel, self.worker); self.worker = nil end
        if env.FrekksFireRate65000000 == self then env.FrekksFireRate65000000 = nil end
    end
    local old = env.FrekksFireRate65000000
    if type(old) == "table" and type(old.Stop) == "function" then old:Stop() end
    env.FrekksFireRate65000000 = state
    state.worker = task.spawn(function()
        while state.running do
            wrap(moduleAt("Modules", "ItemTypes", "Gun"), {"ShootCooldown", "ShootBurstCooldown", "QuickShotCooldown"})
            wrap(moduleAt("Modules", "ItemTypes", "Melee"), {"AttackCooldown"})
            wrap(moduleAt("Modules", "Items", "Gunblade"), {"BladeCooldown"}, true)
            task.wait(1)
        end
    end)
    return state
end

