local function addFrekksecExtraOptions(option)
    option("Fake Position","Underground","FakeEnabled","Enable fake position",false,nil,"Custom-height engine. Enable the helper with F6 first. Physical depth and the local ghost height are independent.")
    option("Fake Position","Underground","FakeKey","Toggle key","X",{"X","Z","C","V","B","N","None"})
    option("Fake Position","Underground","FakeDepth","Underground depth",5.8,{1,25,1})
    option("Fake Position","Underground","FakeWalk","Dynamic walk",true,nil,"Moves the surface point with your walking input when another helper movement mode is not placing it.")
    option("Fake Position","Underground","FakeCamera","Surface camera",true)
    option("Fake Position","Underground","FakeNoclip","Underground noclip",true)
    option("Fake Position","Underground","FakeHandoff","Surface briefly on shooting",true,nil,"Responds to fire input, tool activation, and linked Frekks shots. Other scripts can signal a shot through frekksec:NotifyShot().")
    option("Fake Position","Visuals","FakeHeight","Ghost height above surface",0,{0,1e37,2},"Local virtual/ghost height above the saved surface position. Range: 0 to 1e37 studs; exact input accepts scientific notation. Physical depth, camera correction, shot handoff and return use the surface anchor.")
    option("Fake Position","Visuals","FakeGhost","Show local ghost",true)
    option("Fake Position","Visuals","FakeGhostColor","Ghost color (#RRGGBB)","#00A2FF")
    option("Fake Position","Visuals","FakeHide","Hide character meshes",true)
    option("Fake Position","Visuals","FakeAnimation","Freeze animation pose",false,nil,"Uses the extracted engine's animation asset and pause time. Availability depends on the character and asset permissions.")
    option("Fake Position","Visuals","FakeZeroVelocity","Zero assembly velocity",true)
    option("Fake Position","Jitter","FakePanic","Panic jitter",false)
    option("Fake Position","Jitter","FakeMinX","Panic X minimum",-5,{-15,0,1})
    option("Fake Position","Jitter","FakeMaxX","Panic X maximum",5,{0,15,1})
    option("Fake Position","Jitter","FakeJitterZ","Jitter on Z too",false)
    option("Fake Position","Angles","FakePose","Angle preset","Custom",{"Custom","Inverted pitch","Zero pitch","Backward look","Spinbot"})
    option("Fake Position","Angles","FakeUsePitch","Apply custom pitch",false)
    option("Fake Position","Angles","FakePitch","Custom pitch",-89,{-89,89,0})
    option("Fake Position","Angles","FakeYaw","Custom yaw",0,{0,360,0})
    option("Fake Position","Angles","FakeSpinSpeed","Spin speed (degrees/sec)",900,{1,3000,0})
    option("Lunar Riot","Controller","LunarMode","Lunar mode","Off",{"Off","Riot Bypass","Riot Abuser V1","Riot Abuser V2","Perfect Block"},"One Lunar mode at a time. Your existing Riot Abuser remains available in Extra.")
    option("Lunar Riot","Controller","LunarPriority","Rotation priority","Current Riot Abuser",{"Current Riot Abuser","Lunar mode"},"Chooses who controls rotation when both find a target. Lunar movement can still run with current Riot Abuser rotation.")
    option("Lunar Riot","Riot Bypass","LunarBypassPosition","Tracking position","Behind",{"Behind","Front","Above","Below","Left","Right"})
    option("Lunar Riot","Riot Bypass","LunarBypassDistance","Distance",3,{0,100,1})
    option("Lunar Riot","Riot Bypass","LunarBypassHeight","Height",0,{-30,30,1})
    option("Lunar Riot","Riot Bypass","LunarBypassRate","Target update / travel time",0.5,{0.05,10,2})
    option("Lunar Riot","Riot Bypass","LunarBypassSnap","Snap instead of smooth travel",false)
    option("Lunar Riot","Riot Abuser V1","LunarV1Speed","Spin speed",720,{1,9999,0})
    option("Lunar Riot","Riot Abuser V1","LunarV1Position","Tracking position","Behind",{"Behind","Above","Front","Below","Left","Right","Exact"})
    option("Lunar Riot","Riot Abuser V1","LunarV1Distance","Tracking distance",3,{1,50,1})
    option("Lunar Riot","Riot Abuser V2","LunarV2Speed","Spin speed",720,{1,3000000,0})
    option("Lunar Riot","Riot Abuser V2","LunarV2XZ","XZ jitter",30,{0,120,0})
    option("Lunar Riot","Riot Abuser V2","LunarV2Y","Y jitter",8,{0,60,0})
    option("Lunar Riot","Riot Abuser V2","LunarV2Spread","Spread distance",300,{1,5000,0})
end

local FrekksecSpace = {MaxCoordinate=3.4e38, MaxOffset=1e37}
function FrekksecSpace.Finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function FrekksecSpace.Vector(value)
    return typeof(value)=="Vector3" and FrekksecSpace.Finite(value.X)
        and FrekksecSpace.Finite(value.Y) and FrekksecSpace.Finite(value.Z)
        and math.max(math.abs(value.X),math.abs(value.Y),math.abs(value.Z))<=FrekksecSpace.MaxCoordinate
end
function FrekksecSpace.Delta(a,b)
    local x,y,z=a.X-b.X,a.Y-b.Y,a.Z-b.Z
    local scale=math.max(math.abs(x),math.abs(y),math.abs(z))
    if scale==0 then return 0,Vector3.zero end
    if not FrekksecSpace.Finite(scale) then return math.huge,Vector3.zero end
    local sx,sy,sz=x/scale,y/scale,z/scale
    local length=math.sqrt(sx*sx+sy*sy+sz*sz)
    return scale*length,Vector3.new(sx/length,sy/length,sz/length)
end
function FrekksecSpace.Face(position,direction)
    local flat=math.sqrt(direction.X^2+direction.Z^2)
    if flat<1e-8 then return CFrame.new(position) end
    return CFrame.new(position)*CFrame.Angles(0,math.atan2(-direction.X,-direction.Z),0)
end
function FrekksecSpace.Format(value,unlimited)
    if unlimited and value==0 then return "Unlimited" end
    if value~=0 and math.abs(value)<0.01 then return string.format("%.6g",value) end
    return value<1e6 and string.format("%.2f",value):gsub("%.?0+$","") or string.format("%.6g",value)
end
function FrekksecSpace.ToSlider(value,unlimited)
    if unlimited and value==0 then return 1000 end
    local cap=unlimited and 999 or 1000
    return math.clamp(math.log10(1+value)/37*cap,0,cap)
end
function FrekksecSpace.FromSlider(value,unlimited)
    if unlimited and value>=1000 then return 0 end
    local cap=unlimited and 999 or 1000
    local result=10^(math.clamp(value,0,cap)/cap*37)-1
    if unlimited then result=math.max(1,result) end
    return math.min(FrekksecSpace.MaxOffset,result)
end

