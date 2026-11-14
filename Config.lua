-- Persistent functional settings shared by live rendering and previews.
TisteltiPlatesConfig = {}
local C = TisteltiPlatesConfig
local defaults = {
    scopes={world=true,party=false,raid=false,pvp=true,arena=true},
    compact={enabled=true,group=true,raid=true,delay=30,size=1,hideGuild=true,hideMerit=true},
    controls={enabled=true,allies=true,enemies=true,anchor="level",x=8,y=0,buffs=true,buffGap=6},
    auras={enabled=true,margin=4},
    mini={group=true,raid=true,guild=true,size=16,gap=4},
    text={size=10,offset=-3},
    recommendation={marked=true,consensus=true,votes=2,hold=2},
    geometry={enabled=true,scale=1.25,width=1.22},
}
local bounds={delay={0,120},size={.5,2},x={-40,80},y={-60,60},buffGap={0,30},margin={0,16},
    gap={0,30},offset={-40,20},votes={1,10},hold={0,10},scale={.8,1.8},width={1,1.6}}
local components={showWings=true,showBorder=true,showLevel=true,showGuild=true,showRole=true,showMerit=true}
local function copy(t)
    local out={}; for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end; return out
end
C.Copy=copy
function C.Get(db,section)
    return db and type(db[section])=="table" and db[section] or defaults[section]
end
function C.Initialize(db)
    for section,values in pairs(defaults) do
        if type(db[section])~="table" then db[section]={} end
        for key,value in pairs(values) do
            local current=db[section][key]
            local range=bounds[key]
            if key=="size" then range=section=="mini" and {8,32} or section=="text" and {8,20} or {.5,2} end
            if type(current)~=type(value) or (type(value)=="number" and
                (current~=current or current<range[1] or current>range[2])) then db[section][key]=value end
        end
    end
    if db.controls.anchor~="level" and db.controls.anchor~="health" then db.controls.anchor="level" end
    for _,style in ipairs({"group","raid","guild"}) do
        local appearance=db.appearance[style]
        for key,value in pairs(components) do if type(appearance[key])~="boolean" then appearance[key]=value end end
    end
    -- Missing modes retain prior behavior through "auto"; an explicit native
    -- selection is never silently replaced by faction colors in PvP.
    for _,kind in ipairs({"ally","enemy"}) do
        local player=db.playerColors[kind]
        for _,field in ipairs({"nameMode","borderMode"}) do
            local mode=player[field]
            if mode~="auto" and mode~="native" and mode~="class" and mode~="faction" and mode~="custom" then player[field]="auto" end
        end
        if type(player.enabled)~="boolean" then player.enabled=true end
    end
    db.configVersion=1
end
function C.Allowed(db)
    if not db or db.enabled==false then return false end
    local inside,kind=false,"none"
    if IsInInstance then inside,kind=IsInInstance() end
    if issecretvalue and (issecretvalue(inside) or issecretvalue(kind)) then return false end
    return C.Get(db,"scopes")[inside and kind or "world"]==true
end
function C.Part(db,style,key)
    local appearance=db and db.appearance and db.appearance[style]
    return not appearance or appearance[key]~=false
end
function C.ExternalGeometry()
    local fn=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not fn then return false end
    local ok,value=pcall(fn,"EllesmereUINameplates")
    return ok and not (issecretvalue and issecretvalue(value)) and value==true
end
local factions={Alliance={.35,.7,1},Horde={1,.3,.3}}
function C.ResolveColor(db,kind,field,class,faction,pvp,native)
    local player=db.playerColors and db.playerColors[kind]
    if not player or player.enabled==false then return nil end
    local mode=player[field.."Mode"] or "auto"
    if mode=="auto" then
        if player[field] then return player[field.."Color"] end
        return pvp and (field=="name" and factions[faction] or native) or nil
    end
    if mode=="native" then return nil end
    if mode=="custom" then return player[field.."Color"] end
    if mode=="faction" then return factions[faction] end
    local rgb=RAID_CLASS_COLORS and RAID_CLASS_COLORS[class or ""]
    return rgb and {rgb.r,rgb.g,rgb.b} or nil
end
function C.Reset(db,section)
    if defaults[section] then db[section]=copy(defaults[section]); return end
    if section=="appearance" then
        for _,style in ipairs({"group","raid","guild"}) do
            db[style]=true
            db.appearance[style]={border=style=="guild" and "plata" or "oroazul",icon="animales",color={1,.73,.22}}
            for key,value in pairs(components) do db.appearance[style][key]=value end
        end
        for _,kind in ipairs({"ally","enemy"}) do
            local rgb=kind=="enemy" and {1,.12,.12} or {.2,.65,1}
            db.playerColors[kind]={enabled=true,name=kind=="enemy",border=kind=="enemy",nameMode="auto",borderMode="auto",nameColor=copy(rgb),borderColor=copy(rgb)}
        end
        db.priority="guild"
    elseif section=="behavior" then
        for section,keys in pairs({compact={"enabled","group","raid","hideGuild","hideMerit"},
            controls={"enabled","allies","enemies","buffs"},auras={"enabled"},mini={"group","raid","guild"}}) do
            for _,key in ipairs(keys) do db[section][key]=defaults[section][key] end
        end
        db.hideRightWingOnCC=true; db.namesOnlyWings=true
    elseif section=="advanced" then
        for _,key in ipairs({"text","recommendation","geometry"}) do C.Reset(db,key) end
        db.scale=1
        db.compact.delay=30; db.compact.size=1
        db.controls.anchor="level"; db.controls.x=8; db.controls.y=0; db.controls.buffGap=6
        db.auras.margin=4; db.mini.size=16; db.mini.gap=4
        for key,value in pairs({intensity=1,wingSize=.8,classIconSize=22,low="bronce",middle="plata",high="oro"}) do db.pvp[key]=value end
    elseif section=="general" then
        db.enabled=true; C.Reset(db,"scopes")
    elseif section=="pvp" then
        -- Keep both table identity and the renderer's active mode until Sync is safe.
        for key,value in pairs({enabled=false,friends=true,enemies=true,emblem=true,wings=true,classIcon=true,
            selected=true,recommended=true,guildBothFactions=false,meritColors=true,enemyColor="class",friendColor="class"}) do
            db.pvp[key]=value
        end
    end
end
