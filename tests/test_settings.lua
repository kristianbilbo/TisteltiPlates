-- Exercise the shipped modules and real settings callbacks in the native-frame fixture.
local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
fixture=fixture:sub(1,assert(fixture:find("local enemy=add('enemy')",1,true))-1)
local cases=[=[
local C,O=TisteltiPlatesConfig,TisteltiPlatesOptions
local function choose(id,value)
    local b=assert(O.controls[id],id); b.scripts.OnClick()
    for _,f in ipairs(frames) do
        if f.parent and f.parent.owner==b and f.text==value and f.shown then f.scripts.OnClick(); return end
    end
    error('Missing choice '..id..' '..value)
end
local function toggle(id,value)
    local b=assert(O.controls[id],id); b:SetChecked(value); b.scripts.OnClick(b)
end
local function number(id,value)
    local b=assert(O.controls[id],id); b:SetText(tostring(value)); b.scripts.OnEnterPressed()
end
-- The dungeon case is configurable from the first visible settings page.
local oldParty=UnitInParty
UnitInParty=function(unit) return unit=='guild' end
inside,kind=true,'party'; db.scopes.party=false
local groupName=add('guild'); groupName.showOnlyName=true; core.refresh()
O.Open('general')
assert(O.controls.namesOnlyWings.parent==O.controls['scopes.party'].parent)
assert(O.controls['mini.group'].parent==O.controls['scopes.party'].parent)
assert(O.controls['scopes.party'].parent.shown)
assert(not groupName.TisteltiNameWings or not groupName.TisteltiNameWings.shown)
local scopeButton=O.controls['scope.enableCurrent']
assert(scopeButton.shown and O.status.text:find('Mazmorra: placas y alitas desactivadas',1,true))
local savedRaid,savedWings=db.scopes.raid,db.namesOnlyWings
scopeButton.scripts.OnClick()
assert(db.scopes.party and db.scopes.raid==savedRaid and db.namesOnlyWings==savedWings)
assert(O.controls['scopes.party'].checked and not scopeButton.shown)
assert(groupName.TisteltiNameWings.shown,'Dungeon button updates the live names-only plate')
toggle('mini.group',false); assert(not groupName.TisteltiNameWings.shown)
toggle('mini.group',true); assert(groupName.TisteltiNameWings.shown)
toggle('namesOnlyWings',false); assert(not groupName.TisteltiNameWings.shown)
toggle('namesOnlyWings',true); assert(groupName.TisteltiNameWings.shown)
toggle('scopes.party',false); assert(not groupName.TisteltiNameWings.shown and scopeButton.shown)
O.controls['names.styles'].scripts.OnClick()
assert(O.panel.selectedTab==2 and O.previews.sample.TisteltiNameWings.shown)
choose('preview.scenario','Normal')
O.Open('general'); db.enabled=false; O.redraw()
assert(not scopeButton.shown); scopeButton.scripts.OnClick(); assert(not db.scopes.party)
db.enabled=true
kind='raid'; O.redraw(); assert(scopeButton.shown)
scopeButton.scripts.OnClick(); assert(db.scopes.raid and not db.scopes.party)
db.scopes.raid=savedRaid
-- Reset follows the page that owns the setting and preserves advanced sizing.
db.namesOnlyWings=false; db.mini.group=false; db.mini.size=24
C.Reset(db,'behavior'); assert(not db.namesOnlyWings and not db.mini.group)
C.Reset(db,'general'); assert(db.namesOnlyWings and db.mini.group and db.mini.size==24)
C.Reset(db,'advanced')
C.Initialize(db); assert(db.namesOnlyWings and db.mini.group and not db.scopes.party)
core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_REMOVED','guild')
plates.guild=nil; UnitInParty=oldParty; inside=false; core.refresh()

local enemy=add('enemy')
local control=enemy.AurasFrame.LossOfControlFrame
assert(control.points[1][1]=='LEFT')
-- Every renderer and native control restoration uses the same instance scope.
inside,kind=true,'party'; core.refresh()
assert(not enemy.TisteltiPvPArt.shown and (not enemy.TisteltiPlayerBorder or not enemy.TisteltiPlayerBorder.shown))
assert(enemy.name.textColor[1]==1 and control.points[1][1]=='BOTTOM')
toggle('scopes.party',true)
assert(enemy.TisteltiPvPArt.shown and control.points[1][1]=='LEFT')
for _,scope in ipairs({'party','raid','pvp','arena'}) do
    kind=scope; db.scopes[scope]=false; core.refresh()
    assert(not enemy.TisteltiPvPArt.shown and control.points[1][1]=='BOTTOM')
    db.scopes[scope]=true; core.refresh(); assert(enemy.TisteltiPvPArt.shown)
end
inside=false; toggle('scopes.world',false)
assert(not enemy.TisteltiPvPArt.shown and control.points[1][1]=='BOTTOM')
toggle('scopes.world',true)
-- Explicit native mode must restore a PvP name and remove every extra border.
O.Open('appearance'); choose('preview.subject','Enemigos')
choose('player.nameMode','Nativo de WoW'); choose('player.borderMode','Nativo de WoW')
assert(enemy.name.textColor[1]==1 and enemy.name.textColor[2]==1)
assert(not enemy.TisteltiPvPArt.body.shown and not enemy.TisteltiPvPArt.inner.shown)
assert(not enemy.TisteltiPvPArt.edges[1].texture.shown)
assert(O.previews.sample.name.textColor[1]==1 and not O.previews.sample.TisteltiPvPArt.body.shown)
-- Preview and live PvP resolve the same custom colors; disabling the mode is reversible.
db.playerColors.enemy.nameColor={.23,.47,.81}; db.playerColors.enemy.borderColor={.12,.34,.56}
choose('player.nameMode','Personalizado'); choose('player.borderMode','Personalizado')
assert(enemy.name.textColor[2]==.47 and O.previews.sample.name.textColor[2]==.47)
assert(enemy.TisteltiPvPArt.inner.borderColor[3]==.56 and O.previews.sample.TisteltiPvPArt.inner.borderColor[3]==.56)
choose('player.nameMode','Facción'); choose('preview.faction','Horda')
assert(enemy.name.textColor[2]==.3 and O.previews.sample.name.textColor[2]==.3)
choose('player.nameMode','Clase'); assert(enemy.name.textColor[1]==RAID_CLASS_COLORS.WARLOCK.r)
toggle('player.enabled',false); assert(enemy.name.textColor[1]==1 and not enemy.TisteltiPvPArt.body.shown)
toggle('player.enabled',true)
toggle('pvp.enemies',false)
assert(not enemy.TisteltiPvPArt.shown and enemy.TisteltiPlayerBorder.shown and O.previews.border.shown)
toggle('pvp.enemies',true)
-- Control positioning and ordinary aura rows have independent opt-outs.
O.Open('behavior'); toggle('controls.enabled',false)
assert(control.points[1][1]=='BOTTOM' and control.points[1][5]==4)
toggle('controls.enabled',true); number('controls.x',17); number('controls.y',-9)
assert(control.points[1][4]==17 and control.points[1][5]==-9)
choose('controls.anchor','Barra de salud'); assert(control.points[1][2]==enemy.healthBar)
toggle('controls.enemies',false); assert(control.points[1][1]=='BOTTOM')
toggle('controls.enemies',true)
combat=true; control.protected=true; toggle('controls.enabled',false)
assert(control.points[1][1]=='LEFT','Protected restoration waits')
combat=false; core.refresh(); assert(control.points[1][1]=='BOTTOM')
control.protected=false; toggle('controls.enabled',true)
-- Separate selected/recommended behavior and matching preview scenes.
local oldReason=TisteltiPlatesPriority.Reason
TisteltiPlatesPriority.Reason=function() return 'FOCO DEL GRUPO' end
local oldIsUnit=UnitIsUnit
UnitIsUnit=function(a,b) return (a=='enemy' and b=='target') or oldIsUnit(a,b) end
toggle('pvp.selected',false); toggle('pvp.recommended',true)
pvp.Update('enemy',enemy)
assert(enemy.TisteltiPvPEmphasis.shown and enemy.TisteltiPvPEmphasis.outline.edges[1].texture.vertex[2]==.8)
toggle('pvp.recommended',false); assert(not enemy.TisteltiPvPEmphasis.shown)
toggle('pvp.selected',true); assert(enemy.TisteltiPvPEmphasis.shown and not enemy.TisteltiPvPEmphasis.reason.shown)
choose('preview.scenario','Objetivo seleccionado'); assert(O.previews.sample.TisteltiPvPEmphasis.shown)
toggle('pvp.selected',false); assert(not O.previews.sample.TisteltiPvPEmphasis.shown)
TisteltiPlatesPriority.Reason=oldReason; UnitIsUnit=oldIsUnit
-- Classic components apply live, even during combat, without affecting each other.
toggle('pvp.enabled',false)
UnitInParty=function(unit) return unit=='guild' end
GetGuildInfo=function(unit) if units[unit] and units[unit].guild then return 'INFINITY','Oficial',1 end end
local member=add('guild'); local art=member.TisteltiArt
local buffs=Frame(member.AurasFrame); member.AurasFrame.BuffListFrame=buffs
buffs:SetPoint('BOTTOM',member.healthBar,'TOP',0,3); core.refresh()
assert(buffs.points[1][2]==art.ccAnchor)
toggle('controls.buffs',false); assert(buffs.points[1][1]=='BOTTOM' and buffs.points[1][5]==3)
assert(member.AurasFrame.LossOfControlFrame.points[1][1]=='LEFT')
toggle('controls.buffs',true)
O.Open('appearance'); choose('preview.subject','Grupo'); choose('preview.scenario','Normal')
toggle('compact.enabled',false)
combat=true; core.refresh()
for _,key in ipairs({'showWings','showBorder','showLevel','showGuild','showRole','showMerit'}) do toggle('style.'..key,false) end
art.scripts.OnUpdate(art,.1)
assert(not art.wings.shown and not art.rightWing.shown and not art.honor.shown and not art.guildName.shown and not art.guildRole.shown and not art.badge.shown and not art.body.shown)
toggle('style.showMerit',true)
assert(art.honor.shown and art.honor.parent==art and not art.badge.shown,'Merit is independent from the level badge')
for _,key in ipairs({'showWings','showBorder','showLevel','showGuild','showRole'}) do toggle('style.'..key,true) end
assert(art.wings.shown and art.rightWing.shown and art.guildName.shown and art.badge.shown and art.body.shown)
-- Compact eligibility, grace period measured from leaving combat, and per-group settings.
local now=100; GetTime=function() return now end
toggle('compact.enabled',true); toggle('compact.group',false); assert(not art.groupCompact)
toggle('compact.group',true); assert(art.groupCompact)
number('compact.delay',7); number('compact.size',1.5)
local compactWidth=art.wings.width
assert(compactWidth>0)
combat=false; now=110; core.refresh(); assert(art.groupCompact)
now=116; core.refresh(); assert(art.groupCompact)
now=117; core.refresh(); assert(not art.groupCompact)
-- Mini wings use stored category/size/gap and retire in an excluded scope.
member.showOnlyName=true; core.refresh(); assert(member.TisteltiNameWings.shown)
number('mini.size',24); number('mini.gap',9)
assert(member.TisteltiNameWings.left.width==24 and member.TisteltiNameWings.left.points[1][4]==-9)
toggle('mini.group',false); assert(not member.TisteltiNameWings.shown)
toggle('mini.group',true); toggle('scopes.world',false); assert(not member.TisteltiNameWings.shown)
toggle('scopes.world',true)
-- Turning off guild presentation must remove the otherwise independent guild label.
member.showOnlyName=false; UnitInParty=function() return false end
db.guild=false; core.refresh()
assert(not member.TisteltiArt.shown)
for _,f in ipairs(member.children) do assert(not (f.text=='<INFINITY>' and f.shown),'Disabled guild text leaked') end
-- Fixed sizing is configurable, restores native dimensions and never follows the cursor.
db.guild=true; core.refresh()
number('geometry.scale',1.1); number('geometry.width',1.3)
assert(math.abs(member.scale-1.1)<.001 and math.abs(member.width-143)<.001)
toggle('geometry.enabled',false); assert(member.scale==1 and member.width==110)
-- Restricted measurements never turn a configuration refresh into an arithmetic error.
local oldHeight=member.healthBar.GetHeight
member.healthBar.GetHeight=function() return secret end
core.refresh(); assert(not member.TisteltiArt.shown and member.scale==1)
member.healthBar.GetHeight=oldHeight; core.refresh(); assert(member.TisteltiArt.shown)
-- Invalid inputs do not corrupt state. Numeric limits and finite values survive reload.
number('mini.size','bad'); assert(db.mini.size==24)
number('mini.size',1000); assert(db.mini.size==32)
db.text.size=0/0; db.controls.anchor='bad'; C.Initialize(db)
assert(db.text.size==10 and db.controls.anchor=='level')
-- Resets require a second click, apply only the section, keep renderer table identity.
local pvpConfig=db.pvp; O.Open('pvp'); local reset=O.controls.reset
reset.scripts.OnClick(); assert(db.pvp.selected==false)
reset.scripts.OnClick(); assert(db.pvp.selected and db.pvp==pvpConfig)
assert(db.mini.size==32 and db.compact.delay==7)
db.pvp.enabled=true; core.refresh(); combat=true
reset.scripts.OnClick(); reset.scripts.OnClick()
assert(pvp.IsActive() and not db.pvp.enabled,'Reset also defers a mode switch in combat')
combat=false; core.refresh(); assert(not pvp.IsActive())
O.Open('behavior'); reset.scripts.OnClick(); reset.scripts.OnClick()
assert(db.controls.enabled and db.compact.enabled and db.mini.size==32 and db.compact.delay==7)
O.Open('advanced'); reset.scripts.OnClick(); reset.scripts.OnClick()
assert(db.mini.size==16 and db.compact.delay==30 and db.geometry.scale==1.25 and db.pvp.classIconSize==22)
-- Explicit false values and old color preferences survive initialization/migration.
db.scopes.party=false; db.controls.enabled=false; db.playerColors.ally.name=false
local saved=C.Copy(db); saved.pvp.selected=nil; saved.pvp.recommended=nil; saved.pvp.emphasizeTargets=false
C.Initialize(saved); pvp.Initialize(saved)
assert(not saved.pvp.selected and not saved.pvp.recommended and not saved.controls.enabled and not saved.scopes.party)
assert(saved.playerColors.ally.name==false and saved.playerColors.enemy.nameMode=='class')
pvp.Initialize(db)
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: shared scopes, independent switches, native colors, faithful previews, numeric settings, protected restoration, defaults and migrations')
]=]
assert((loadstring or load)(fixture..cases))()
