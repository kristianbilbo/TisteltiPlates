-- Lua 5.1 behavioral checks: actual PvP module, Core events and option callbacks.
unpack = unpack or table.unpack
local frames, panels = {}, {}
local combat, inside, kind = false, false, "none"
local secret = {}
local nativeMutations = 0
local errors = {}
local originalPrint = print
print = function(message)
    if type(message)=='string' and message:find('Error al dibujar',1,true) then errors[#errors+1]=message end
    originalPrint(message)
end
local function Frame(parent)
    local f = {parent=parent,children={},shown=true,scripts={},points={},width=110,height=10,frameLevel=1,
        scale=1,color={.3,.4,.5,1},alpha=1}
    if parent then parent.children[#parent.children+1]=f end
    function f:CreateTexture() return Frame(self) end
    function f:CreateFontString() return Frame(self) end
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:RegisterEvent() end
    function f:SetPoint(...) self.points[#self.points+1]={...} end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:GetNumPoints() return #self.points end
    function f:ClearAllPoints() self.points={} end
    function f:SetAllPoints(anchor) self.anchor=anchor end
    function f:GetFrameLevel() return self.frameLevel end
    function f:SetFrameLevel(v) self.frameLevel=v end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetWidth(w) if self.native then nativeMutations=nativeMutations+1; assert(not combat) end; self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetScale(v) if self.native then nativeMutations=nativeMutations+1; assert(not combat) end; self.scale=v end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:GetRect() return unpack(self.rect or {0,0,self.width,self.height}) end
    function f:SetTextColor(...) self.textColor={...} end
    function f:GetTextColor() return unpack(self.textColor or {.8,.8,.8,1}) end
    function f:SetStatusBarColor(...) self.color={...} end
    function f:GetStatusBarColor() return unpack(self.color) end
    function f:SetValue(v) self.value=v end
    function f:GetValue() return self.value or 78 end
    function f:SetMinMaxValues(a,b) self.minimum,self.maximum=a,b end
    function f:GetMinMaxValues() return self.minimum or 0,self.maximum or 100 end
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children) end
    function f:IsProtected() return self.protected or false end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:GetEffectiveAlpha() return self.alpha end
    function f:UpdateAnchors() end
    function f:SetVertexColor(...) self.vertex={...} end
    function f:SetTexCoord(...) self.uv={...} end
    function f:SetTexture(v) self.texture=v end
    function f:SetRotation(v) self.rotation=v end
    function f:SetText(v) self.text=v end
    function f:SetChecked(v) self.checked=v end
    function f:GetChecked() return self.checked end
    function f:SetAlpha(v) self.alpha=v end
    function f:GetAlpha() return self.alpha end
    function f:IsShown() return self.shown end
    function f:IsForbidden() return self.forbidden or false end
    function f:SetShown(v)
        if self.shown==v then return end
        self.shown=v
        local callback=self.scripts[v and 'OnShow' or 'OnHide']
        if callback then callback(self) end
    end
    function f:Show() self:SetShown(true) end
    function f:Hide() self:SetShown(false) end
    function f:GetID() return 2 end
    setmetatable(f,{__index=function(_,k)
        if k:match('^Set') or k:match('^Enable') then return function() end end
    end})
    frames[#frames+1]=f
    return f
end
CreateFrame=function(_,_,parent) return Frame(parent) end
UIParent=Frame(); SlashCmdList={}
issecretvalue=function(v) return v==secret end
InCombatLockdown=function() return combat end
IsInInstance=function() return inside,kind end
IsInRaid=function() return false end
GetNumSubgroupMembers=function() return 0 end
GetNumGroupMembers=function() return 0 end
RAID_CLASS_COLORS={MAGE={r=.41,g=.8,b=.94},WARLOCK={r=.58,g=.51,b=.79}}
local units = {
    player={faction='Alliance',class='MAGE',friend=true},
    enemy={faction='Horde',class='WARLOCK',enemy=true,guild=true},
    guild={faction='Alliance',class='MAGE',friend=true,guild=true,rank=8},
    ally={faction='Alliance',class='MAGE',friend=true},
    npc={faction='Horde',class='WARLOCK',enemy=true,npc=true},
}
UnitIsPlayer=function(u) return units[u] and not units[u].npc end
UnitIsUnit=function(a,b) return a==b end
UnitIsFriend=function(_,u) return units[u] and units[u].friend or false end
UnitCanAttack=function(_,u) return units[u] and units[u].enemy or false end
UnitFactionGroup=function(u) return units[u] and units[u].faction end
UnitIsInMyGuild=function(u) return units[u] and units[u].guild end
UnitClass=function(u) return 'Class',units[u].class end
UnitExists=function(u) return units[u]~=nil end
TisteltiMerito=function(u) return units[u].rank or 0 end
hooksecurefunc=function(owner,key,callback)
    if type(owner)=='string' then return end
    local original=owner[key]
    owner[key]=function(self,...) original(self,...); callback(self,...) end
end
Settings={
    RegisterCanvasLayoutCategory=function(p) return p end,
    RegisterCanvasLayoutSubcategory=function(_,p,label) panels[label]=p; return p end,
    RegisterAddOnCategory=function() end,
    OpenToCategory=function(id) assert(id==2) end,
}
local plates={}
C_NamePlate={GetNamePlateForUnit=function(u) return plates[u] end}
assert(loadfile('TisteltiPlates/Prioridad.lua'))()
assert(loadfile('TisteltiPlates/PvP.lua'))()
assert(loadfile('TisteltiPlates/CCPosition.lua'))()
assert(loadfile('TisteltiPlates/HoverWidth.lua'))()
local file=assert(io.open('TisteltiPlates/Core.lua','rb')); local source=file:read('*a'); file:close()
local core=assert(loadstring(source..'\nreturn {driver=driver,refresh=Refresh,active=active,allowed=Allowed}'))('TisteltiPlates')
local pvp=TisteltiPlatesPvP
TisteltiPlatesDB={priority='group',scale=1.4,appearance={group={border='cobre'}}}
core.driver.scripts.OnEvent(core.driver,'ADDON_LOADED','TisteltiPlates')
local db=TisteltiPlatesDB
assert(not db.pvp.enabled and not pvp.IsActive(),'PvP desactivado por defecto')
assert(db.pvp.enemyColor=='class' and db.pvp.classIcon)
assert(db.priority=='group' and db.scale==1.4 and db.appearance.group.border=='cobre')
assert(panels['Modo PvP'],'PvP subcategory must be registered')
SlashCmdList.TISTELTIPLATES('pvp on')
assert(db.pvp.enabled and pvp.IsActive(),'activación explícita')
local function add(unit)
    local uf=Frame(); uf.unit=unit; uf.native=true
    uf.healthBar=Frame(uf); uf.healthBar.native=true
    uf.name=Frame(uf.healthBar)
    uf.name:SetText('Nombre original largo')
    uf.name:SetPoint('CENTER',uf.healthBar,'CENTER',0,0)
    if unit=='guild' then
        uf.AurasFrame=Frame(uf)
        uf.AurasFrame.LossOfControlFrame=Frame(uf.AurasFrame)
        uf.AurasFrame.LossOfControlFrame:SetPoint('BOTTOM',uf.healthBar,'TOP',0,4)
    end
    plates[unit]={UnitFrame=uf}
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_ADDED',unit)
    return uf
end
local enemy=add('enemy'); local art=enemy.TisteltiPvPArt
assert(art and art.shown and enemy.width==110 and enemy.scale==1)
assert(nativeMutations==0,'Compact mode must never enlarge native plates')
assert(enemy.healthBar.color[1]==RAID_CLASS_COLORS.WARLOCK.r)
assert(art.edges[1].texture.vertex[1]==1 and art.edges[1].texture.vertex[2]==.08,'Enemy border is red independently of class-colored health')
assert(art.faction.texture:find('Horde') and art.factionFrame.points[1][2]==art.classFrame)
assert(not art.wings[1].shown and not art.wings[2].shown,'No Horde guild wings, even with bad guild membership data')
assert(art.classFrame.shown and art.classFrame.edges[1].texture.vertex[1]==RAID_CLASS_COLORS.WARLOCK.r)
assert(art.classFrame.width==22 and art.classFrame.height==22,'Class icons use a readable size independent of the health bar')
assert(art.classFrame.points[1][1]=='RIGHT' and art.classFrame.points[1][2]==art.body and art.classFrame.points[1][4]==-4,'Class tile joins the metal body and leaves right-side controls alone')
assert(art.body and art.inner and art.classFrame.metal and art.levelFrame,'Guild-style metal frame is used throughout')
local guild=add('guild')
assert(guild.TisteltiPvPArt.wings[1].shown and guild.TisteltiPvPArt.wings[2].shown)
-- CC and native ability timers must win the right-hand space in compact mode.
local controls=guild.AurasFrame.LossOfControlFrame
controls.AuraItemFrame=Frame(controls)
controls.AuraItemFrame.rect={200,0,18,18}
controls.AuraItemFrame:Hide()
controls.AuraItemFrame.Icon={}
local nativeCooldown={duration=12,expiration=120}
controls.AuraItemFrame.Cooldown=nativeCooldown
guild.castBar=Frame(guild)
guild.castBar:SetPoint('TOP',guild.healthBar,'BOTTOM',0,-3)
local castPoint=guild.castBar.points[1]
local nativePoint=controls.points[1]
local function tickControls() guild.TisteltiPvPArt.scripts.OnUpdate(guild.TisteltiPvPArt,.05) end
tickControls()
assert(guild.TisteltiPvPArt.classFrame.shown,'Empty aura lists do not suppress class icon')
combat=true; controls.protected=true
controls.AuraItemFrame:Show(); tickControls()
assert(not guild.TisteltiPvPArt.wings[2].shown and guild.TisteltiPvPArt.classFrame.shown)
assert(guild.TisteltiPvPArt.wings[1].shown,'Left wing does not conflict with controls')
core.refresh()
assert(guild.TisteltiPvPArt.classFrame.shown,'Class icon stays on the other side while CC is visible')
assert(controls.points[1]==nativePoint and guild.castBar.points[1]==castPoint,'Native aura and cast anchors unchanged')
assert(controls.AuraItemFrame.Cooldown==nativeCooldown and nativeCooldown.duration==12,'Native skill timer untouched')
controls.AuraItemFrame:Hide(); tickControls()
assert(guild.TisteltiPvPArt.wings[2].shown and guild.TisteltiPvPArt.classFrame.shown)
controls.AuraItemFrame:Show(); controls:Hide(); tickControls()
assert(guild.TisteltiPvPArt.classFrame.shown,'Hidden control parent does not count')
controls:Show(); controls.AuraItemFrame:Hide()
local crowd=Frame(guild.AurasFrame)
guild.AurasFrame.CrowdControlListFrame=crowd
local crowdIcon=Frame(crowd); crowdIcon.Icon={}; crowdIcon.Cooldown={}
crowdIcon.rect={200,0,18,18}
tickControls(); assert(not guild.TisteltiPvPArt.wings[2].shown and guild.TisteltiPvPArt.classFrame.shown,'Child controls reserve the right side, class icon stays left')
crowdIcon:Hide(); tickControls(); assert(guild.TisteltiPvPArt.classFrame.shown)
local isVisible=controls.AuraItemFrame.IsVisible
controls.AuraItemFrame.IsVisible=function() return secret end
tickControls(); assert(guild.TisteltiPvPArt.classFrame.shown,'Restricted visibility is handled safely')
controls.AuraItemFrame.IsVisible=isVisible
combat=false; controls.protected=false
local wing=guild.TisteltiPvPArt.wings[1]
assert(wing.texture.texture:find('Wings.tga',1,true),'Guild wings reuse the real feather artwork')
assert(wing.texture.vertex[1]==.55+.45*pvp.WingColor(8).r)
assert(wing.points[1][2]==guild.TisteltiPvPArt.classFrame,'Wing and class tile form one silhouette')
local ally=add('ally'); assert(not ally.TisteltiPvPArt.wings[1].shown)
local npc=add('npc'); assert(not npc.TisteltiPvPArt,'NPCs must be untouched')
local function clickText(prefix)
    for _,f in ipairs(frames) do
        if f.text and f.text:sub(1,#prefix)==prefix and f.scripts.OnClick then f.scripts.OnClick(f); return end
    end
    error('Missing control: '..prefix)
end
clickText('Enemigos · barra:')
assert(db.pvp.enemyColor=='red' and enemy.healthBar.color[1]==1 and enemy.healthBar.color[2]==.08)
assert(art.edges[1].texture.vertex[2]==.08,'Red frame follows red bar')
assert(art.classFrame.edges[1].texture.vertex[1]==RAID_CLASS_COLORS.WARLOCK.r,'Class icon neon stays class-colored on red plate')
local function toggle(caption,value)
    for _,f in ipairs(frames) do
        if f.text==caption and f.parent and f.parent.scripts.OnClick then
            f.parent:SetChecked(value); f.parent.scripts.OnClick(f.parent); return
        end
    end
    error('Missing checkbox: '..caption)
end
toggle('Icono de clase con neón de clase',false)
assert(not art.classFrame.shown)
controls.AuraItemFrame:Show(); tickControls()
controls.AuraItemFrame:Hide(); tickControls()
assert(not guild.TisteltiPvPArt.classFrame.shown,'CC ending must respect disabled class icons')
toggle('Icono de clase con neón de clase',true)
assert(art.classFrame.shown)
clickText('Alas · mérito 5–9:')
assert(db.pvp.middle=='oro' and guild.TisteltiPvPArt.wings[1].texture.vertex[2]==.55+.45*.86)
clickText('Brillo (0.6 / 1 / 1.4):')
assert(db.pvp.intensity==1.4)
clickText('Tamaño de icono de clase:')
assert(db.pvp.classIconSize==26 and art.classFrame.width==26,'Size option updates real plates')
-- Keep class icons outside the left guild wing, independent of the right level.
guild.PlayerLevelDiffFrame=Frame(guild); core.refresh()
assert(guild.TisteltiPvPArt.wings[2].points[1][2]==guild.PlayerLevelDiffFrame)
assert(guild.TisteltiPvPArt.classFrame.points[1][2]==guild.TisteltiPvPArt.body)
assert(guild.TisteltiPvPArt.levelFrame.shown and guild.TisteltiPvPArt.levelFrame.points[1][2]==guild.PlayerLevelDiffFrame)
enemy.healthBar:SetStatusBarColor(.1,.2,.3)
assert(enemy.healthBar.color[1]==1,'Native recolor must not erase PvP styling')
combat=true
local enemy2=add('enemy'); assert(enemy2.TisteltiPvPArt.shown and nativeMutations==0)
SlashCmdList.TISTELTIPLATES('pvp off')
assert(pvp.IsActive(),'Mode changes must wait until combat ends')
combat=false
core.driver.scripts.OnEvent(core.driver,'PLAYER_REGEN_ENABLED')
assert(not pvp.IsActive() and not enemy2.TisteltiPvPArt.shown)
assert(enemy2.healthBar.color[1]==.3,'Original health color restored')
assert(guild.scale==1.25 and guild.width==110*1.22,'Disabling PvP restores the existing classic style')
SlashCmdList.TISTELTIPLATES('pvp on'); SlashCmdList.TISTELTIPLATES('pvp')
assert(guild.scale==1 and guild.width==110,'Returning to PvP must restore native dimensions')
assert(guild.AurasFrame.LossOfControlFrame.points[1][1]=='BOTTOM'
    and guild.AurasFrame.LossOfControlFrame.points[1][5]==4,'Real Core/CC/PvP switch must restore the native aura anchor')
SlashCmdList.TISTELTIPLATES('enemigos clase')
assert(enemy2.healthBar.color[1]==RAID_CLASS_COLORS.WARLOCK.r)
inside=true; kind='party'; core.refresh(); assert(not enemy2.TisteltiPvPArt.shown)
kind='raid'; core.refresh(); assert(not enemy2.TisteltiPvPArt.shown)
kind='pvp'; core.refresh(); assert(enemy2.TisteltiPvPArt.shown and core.allowed())
kind='arena'; core.refresh(); assert(enemy2.TisteltiPvPArt.shown)
db.enabled=false; core.refresh(); assert(not enemy2.TisteltiPvPArt.shown)
db.enabled=true; inside=false; core.refresh()
-- Restricted class information cannot be indexed or produce a false class icon.
local normalClass=UnitClass; UnitClass=function() return 'Class',secret end
core.refresh(); assert(enemy2.TisteltiPvPArt.shown and not enemy2.TisteltiPvPArt.classFrame.shown)
assert(enemy2.healthBar.color[1]==1)
UnitClass=normalClass
db.pvp.enemies=false; core.refresh(); assert(not enemy2.TisteltiPvPArt.shown)
db.pvp.enemies=true; core.refresh(); assert(enemy2.TisteltiPvPArt.classFrame.shown)
core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_REMOVED','enemy')
assert(not enemy2.TisteltiPvPArt.shown and enemy2.healthBar.color[1]==.3)
-- Recycled plates must clear stale wings and emblems.
pvp.Update('guild',enemy2); assert(enemy2.TisteltiPvPArt.wings[1].shown)
pvp.Update('enemy',enemy2); assert(not enemy2.TisteltiPvPArt.wings[1].shown)
local oldUnitIsUnit=UnitIsUnit
GetNumSubgroupMembers=function() return 1 end
UnitIsUnit=function(a,b) return (a=='ally' and b=='party1') or oldUnitIsUnit(a,b) end
units.party1=units.guild
pvp.Update('ally',ally)
assert(ally.TisteltiPvPArt.wings[1].shown,'Guild wings must support roster-only membership data')
enemy2.unit=nil; pvp.Remove(enemy2); assert(enemy2.healthBar.color[1]==.3)

-- Emphasis is an empty frame: the real name, health fill and textures stay visible.
local target='enemy'
local targets={party1target='enemy',party2target='enemy'}
units.party2=units.ally
GetNumSubgroupMembers=function() return 2 end
UnitIsUnit=function(a,b) return a==(targets[b] or (b=='target' and target) or b) end
GetTime=function() return 100 end
local priority=TisteltiPlatesPriority
enemy2.unit='enemy'
local nativeBefore=nativeMutations
local originalName=enemy2.name
local originalNamePoint=originalName.points[1]
local originalValueSetter=enemy2.healthBar.SetValue
enemy2.castBar=Frame(enemy2)
enemy2.castBar:SetPoint('TOP',enemy2.healthBar,'BOTTOM',0,-3)
local originalCastPoint=enemy2.castBar.points[1]
combat=true
priority.Update({enemy={UnitFrame=enemy2}},true)
pvp.Update('enemy',enemy2)
local enlarged=enemy2.TisteltiPvPEmphasis
assert(enlarged and enlarged.shown and enlarged.points[1][2]==enemy2.healthBar)
assert(not enlarged.background and not enlarged.sourceBar,'Emphasis must never overlay a replacement health fill')
assert(enemy2.width==110 and enemy2.scale==1 and nativeMutations==nativeBefore,'Native scale, click area and protected geometry remain unchanged')
assert(enlarged.marker.shown and enlarged.reason.text=='FOCO DEL GRUPO')
assert(enlarged.reason.points[1][2]==enemy2.castBar,'Priority caption leaves room for a visible cast bar')
assert(enemy2.castBar.points[1]==originalCastPoint and enemy2.name==originalName
    and originalName.text=='Nombre original largo' and originalName.points[1]==originalNamePoint,
    'Names and cast bars retain their text, placement and identity')
assert(enemy2.healthBar.SetValue==originalValueSetter,'No replacement health forwarding hooks remain')
assert(enlarged.outline.edges[1].texture.vertex[2]==1,'Current target has white outline')
enemy2.healthBar:SetValue(35)
assert(enemy2.healthBar.value==35 and not enlarged.value,'Only the real health bar renders health')
enemy2.healthBar:SetMinMaxValues(0,150)
assert(enemy2.healthBar.maximum==150 and not enlarged.maximum)
target=nil pvp.Update('enemy',enemy2)
assert(enlarged.outline.edges[1].texture.vertex[2]==.8,'Recommended target has gold outline')
targets={} priority.Update({enemy={UnitFrame=enemy2}},true) pvp.Update('enemy',enemy2)
assert(not enlarged.shown,'Enlargement disappears when priority disappears')
target='enemy' pvp.Update('enemy',enemy2) assert(enlarged.shown)
assert(enlarged.reason.text=='' and not enlarged.reason.shown and not enlarged.marker.shown,
    'A selected target needs no detached TU OBJETIVO label or skull')
db.pvp.emphasizeTargets=false pvp.Update('enemy',enemy2) assert(not enlarged.shown)
db.pvp.emphasizeTargets=true pvp.Update('enemy',enemy2)
pvp.Remove(enemy2) assert(not enlarged.shown,'Recycled plates hide the enlarged bar')
combat=false
db.pvp.enabled=false; db.pvp.high='violeta'; pvp.Initialize(db)
assert(not pvp.IsActive() and db.pvp.high=='violeta','Saved settings must survive reload')
db.pvp.enabled=true; pvp.Initialize(db)
assert(pvp.IsActive(),'se conserva una activación guardada')
assert(db.pvp.classIconSize==26,'Class icon size survives reload')
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: PvP migration, native size, factions, wings, options, colors, combat, native skills/CC/cast timers, secrets, restoration and recycling')

-- EllesmereUI's external name host must not be dwarfed by our bar enlargement.
SlashCmdList.TISTELTIPLATES('pvp off')
assert(guild.scale==1.25 and guild.width==110*1.22)
C_AddOns={IsAddOnLoaded=function(addon) return addon=='EllesmereUINameplates' end}
core.refresh()
assert(guild.scale==1 and guild.width==110,'Detecting EllesmereUI restores our earlier enlargement')
guild.name=Frame() -- An external text host, outside the native bar hierarchy.
guild.name.fontSize=14
guild.name:SetPoint('BOTTOM',guild.healthBar,'TOP',0,6)
local namePoint=guild.name.points[1]
guild:SetScale(.9); guild:SetWidth(145)
local beforeExternal=nativeMutations
core.refresh(); core.refresh()
assert(guild.scale==.9 and guild.width==145 and nativeMutations==beforeExternal,
    'EllesmereUI owns live geometry; repeated refresh must not fight its settings')
assert(guild.name.fontSize==14 and guild.name.points[1]==namePoint and guild.name.scale==1,
    'External name font, position and scale must remain intact')
combat=true; core.refresh(); combat=false
assert(guild.scale==.9 and guild.width==145)
db.enabled=false; core.refresh()
assert(guild.scale==.9 and guild.width==145,'Turning Tistelti off must not restore stale external geometry')
db.enabled=true
C_AddOns=nil
IsAddOnLoaded=function(addon) return addon=='EllesmereUINameplates' end
core.refresh()
assert(guild.scale==.9 and guild.width==145,'Legacy addon detection also preserves external geometry')
IsAddOnLoaded=nil
core.refresh()
assert(guild.scale==.9*1.25 and guild.width==145*1.22,'Standalone style retains its enlargement')
db.enabled=false; core.refresh()
assert(guild.scale==.9 and guild.width==145,'Standalone removal restores the latest base geometry')
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: EllesmereUI external names, live geometry, legacy detection, combat, disable and standalone restoration')

-- Faction names are independent of bar/class/reaction colours and restore fully.
db.enabled=true
SlashCmdList.TISTELTIPLATES('pvp on')
pvp.Update('guild',guild)
assert(guild.name.textColor[1]==.35 and guild.name.textColor[3]==1,'Alliance names are readable blue')
enemy2.name:SetTextColor(.7,.6,.5,.4)
pvp.Update('enemy',enemy2)
assert(enemy2.name.textColor[1]==1 and enemy2.name.textColor[2]==.3 and enemy2.name.textColor[4]==.4,
    'Horde names are red while preserving alpha')
enemy2.name:SetTextColor(0,1,0,1)
assert(enemy2.name.textColor[1]==1 and enemy2.name.textColor[2]==.3,'Native recolours cannot erase faction names')
local oldName=enemy2.name
enemy2.name=Frame(enemy2)
enemy2.name:SetTextColor(.2,.3,.4,.9)
pvp.Update('enemy',enemy2)
assert(oldName.textColor[1]==.7 and oldName.textColor[4]==.4,'Replacing the name restores the previous text region')
combat=true; enemy2.name.protected=true
pvp.Remove(enemy2)
assert(enemy2.name.textColor[1]==1,'Protected text waits for safe restoration')
combat=false; enemy2.name.protected=false; pvp.Sync()
assert(enemy2.name.textColor[1]==.2 and enemy2.name.textColor[4]==.9,'Deferred restoration keeps original colour and alpha')
pvp.Update('enemy',enemy2)
units.enemy.faction=nil
pvp.Update('enemy',enemy2)
assert(enemy2.name.textColor[1]==.2,'An unknown faction retains the original name colour')
units.enemy.faction='Horde'
print('PASS: faction name colours, alpha, external recolours, replacement, unknown faction and combat restoration')

-- Auras always win; hide only ornaments that actually overlap their rectangles.
local guildArt=guild.TisteltiPvPArt
guildArt.wings[1].rect={0,0,20,20}
guildArt.classFrame.rect={30,0,20,20}
guildArt.factionFrame.rect={48,-5,12,12}
guildArt.wings[2].rect={160,0,20,20}
local buffs=Frame(guild.AurasFrame)
guild.AurasFrame.BuffListFrame=buffs
local buffIcon=Frame(buffs)
buffIcon.Icon={}; buffIcon.Cooldown={duration=12}
buffIcon.rect={30,0,18,18}
buffIcon:SetPoint('BOTTOM',guild.healthBar,'TOP',0,4)
local buffPoint=buffIcon.points[1]
combat=true
tickControls()
assert(not guildArt.classFrame.shown and not guildArt.factionFrame.shown
    and guildArt.wings[1].shown and guildArt.wings[2].shown,'Only overlapping ornaments yield')
assert(buffIcon.points[1]==buffPoint and buffIcon.Cooldown.duration==12,'Aura anchors and timers stay untouched in combat')
buffIcon.rect={0,0,18,18}; tickControls()
assert(not guildArt.wings[1].shown and guildArt.classFrame.shown,'Moving a buff restores class and hides the affected wing')
buffIcon.rect={400,80,18,18}; tickControls()
assert(guildArt.wings[1].shown and guildArt.classFrame.shown,'Non-overlapping buffs leave the full design visible')
buffIcon.scale=2; buffIcon.rect={15,0,9,9}; tickControls()
assert(not guildArt.classFrame.shown,'Collision compares screen space across different effective scales')
buffIcon.scale=1
local auraMeasurements=0
buffIcon.HasAnyForbiddenAspects=function() return true end
buffIcon.GetRect=function() auraMeasurements=auraMeasurements+1 error('Cannot measure restricted aura') end
tickControls()
assert(auraMeasurements==0,'Restricted geometry is checked before measuring')
assert(not guildArt.wings[1].shown and not guildArt.wings[2].shown and not guildArt.classFrame.shown,
    'Unreadable visible auras conservatively reserve all ornament space')
buffIcon.HasAnyForbiddenAspects=nil
for i=1,100 do tickControls() end
assert(auraMeasurements==1,'A failing GetRect is never retried every frame')
buffIcon:Hide(); tickControls()
assert(guildArt.wings[1].shown and guildArt.classFrame.shown,'Empty visible containers never hide ornaments')
combat=false
db.pvp.classIcon=false; pvp.Update('guild',guild); tickControls()
assert(not guildArt.classFrame.shown,'Aura ending respects disabled class icons')
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: overlapping buffs, scaled rectangles, moving icons, combat, restricted geometry, empty containers and saved preferences')
