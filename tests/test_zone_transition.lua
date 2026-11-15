local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
fixture=fixture:sub(1,assert(fixture:find("local enemy=add('enemy')",1,true))-1)
local cases=[=[
db.pvp.enabled=false; db.scopes.party=true
UnitInParty=function(unit) return unit=='guild' or unit=='ally' end
local member=add('guild'); member.showOnlyName=true
local guest=add('ally'); guest.showOnlyName=true
local visible={plates.guild,plates.ally}
C_NamePlate.GetNamePlates=function() return visible end
core.refresh()
assert(member.TisteltiNameWings.shown and guest.TisteltiNameWings.shown)
-- Loading screens can detach plates before their replacement is available.
core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
visible={}; plates.guild=nil; plates.ally=nil
assert(not member.TisteltiNameWings.shown and not guest.TisteltiNameWings.shown)
inside,kind=true,'party'
core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
-- Reuse the native frames without relying on another ADDED notification.
plates.guild={UnitFrame=member}; plates.ally={UnitFrame=guest}
visible={plates.guild,plates.ally}
core.driver.scripts.OnUpdate(core.driver,.4)
assert(member.TisteltiNameWings.shown,'Guild wings recover after delayed dungeon plates')
assert(not guest.TisteltiNameWings.shown,'Dungeon guild filter remains active')
-- Both world entry and the periodic recovery must respect saved opt-outs.
core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
inside=false
core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
assert(member.TisteltiNameWings.shown and guest.TisteltiNameWings.shown,'World wings return')
db.namesOnlyWings=false; core.refresh()
assert(not member.TisteltiNameWings.shown and not guest.TisteltiNameWings.shown)
db.namesOnlyWings=true; core.refresh()
-- A base plate can acquire a different UnitFrame while retaining its token.
local replacement=Frame(); replacement.unit='guild'; replacement.name=Frame(replacement)
replacement.showOnlyName=true
plates.guild.UnitFrame=replacement
core.driver.scripts.OnUpdate(core.driver,.4)
assert(not member.TisteltiNameWings.shown,'Old UnitFrame decoration is released')
assert(replacement.TisteltiNameWings.shown,'Replacement UnitFrame is tracked')
visible={plates.ally}; plates.guild=nil
core.driver.scripts.OnUpdate(core.driver,.4)
assert(not replacement.TisteltiNameWings.shown,'Missing remove event cannot leave stale wings')
-- Transient inaccessible enumeration must not throw or discard valid tracking.
C_NamePlate.GetNamePlates=function() error('loading') end
core.refresh(); assert(guest.TisteltiNameWings.shown)
C_NamePlate.GetNamePlates=function() return visible end
inside,kind=true,'party'; db.scopes.party=false
core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
assert(not guest.TisteltiNameWings.shown,'Excluded dungeon stays excluded')
inside=false; core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
assert(guest.TisteltiNameWings.shown)
-- Repeat loading screens with both presentations, with and without combat.
plates.guild={UnitFrame=member}; visible={plates.guild,plates.ally}
db.scopes.party=true
local function wings(uf,names)
    if names then return uf.TisteltiNameWings and uf.TisteltiNameWings.shown or false end
    for _,art in ipairs({uf.TisteltiArt or {},uf.TisteltiCombatArt or {}}) do
        if art.shown and art.wings and art.wings.shown then return true end
    end
    return false
end
for _,names in ipairs({true,false}) do
    member.showOnlyName=names; guest.showOnlyName=names
    for _,locked in ipairs({false,true}) do
        for cycle=1,4 do
            combat=false; inside=false; core.refresh()
            assert(wings(member,names) and wings(guest,names))
            combat=locked
            local mutations=nativeMutations
            core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
            assert(not wings(member,names) and not wings(guest,names))
            core.driver.scripts.OnUpdate(core.driver,.4)
            assert(not wings(member,names),'No reacquisition during the loading screen')
            inside,kind=true,'party'
            core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
            assert(wings(member,names) and not wings(guest,names),'Dungeon membership after repeated entry')
            core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
            inside=false
            core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
            assert(wings(member,names) and wings(guest,names),'Both wings recover outside')
            if locked then assert(nativeMutations==mutations,'Loading screens do not mutate native geometry in combat') end
            combat=false; core.driver.scripts.OnEvent(core.driver,'PLAYER_REGEN_ENABLED')
            assert(wings(member,names) and wings(guest,names))
        end
    end
end
-- Late data / names-only initialization recovers without another group event.
member.showOnlyName=true; guest.showOnlyName=true
inside,kind=true,'party'; core.refresh()
local oldGuild,oldParty=UnitIsInMyGuild,UnitInParty
UnitIsInMyGuild=function() return nil end
UnitInParty=function() return false end
core.driver.scripts.OnUpdate(core.driver,.4)
assert(not wings(member,true))
UnitIsInMyGuild,UnitInParty=oldGuild,oldParty
member.name.textWidth=0
core.driver.scripts.OnUpdate(core.driver,.4); assert(not wings(member,true))
member.name.textWidth=80; member.name:Hide()
core.driver.scripts.OnUpdate(core.driver,.4); assert(not wings(member,true))
member.name:Show()
core.driver.scripts.OnUpdate(core.driver,.4); assert(wings(member,true))
-- Token reuse for somebody outside the guild removes the previous ornaments.
plates.guild=nil; plates.ally=nil
member.unit='ally'; plates.ally={UnitFrame=member}; visible={plates.ally}
core.driver.scripts.OnUpdate(core.driver,.4)
assert(not wings(member,true) and not wings(guest,true))
member.unit='guild'; plates.ally=nil; plates.guild={UnitFrame=member}; visible={plates.guild}
core.driver.scripts.OnUpdate(core.driver,.4); assert(wings(member,true))
-- An early ADDED callback can run before a UnitFrame exists.
core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_REMOVED','guild')
plates.guild={}; visible={plates.guild}
core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_ADDED','guild')
plates.guild.UnitFrame=member
core.driver.scripts.OnUpdate(core.driver,.4); assert(wings(member,true))
-- A forbidden or secret unit cannot be treated as an eligible guild member.
member.forbidden=true; core.refresh()
member.forbidden=false; member.unit=secret
core.refresh(); assert(not wings(member,true))
member.unit='guild'; core.refresh(); assert(wings(member,true))
-- Global and per-style switches survive travel, as does the dungeon filter.
local function toggle(id,value)
    local b=TisteltiPlatesOptions.controls[id]; b:SetChecked(value); b.scripts.OnClick(b)
end
for _,id in ipairs({'enabled','namesOnlyWings','mini.group'}) do
    toggle(id,false)
    core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
    core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
    assert(not wings(member,true),id)
    toggle(id,true); assert(wings(member,true),id..' re-enabled')
end
-- The same lifecycle works while PvP is active; names-only retains priority.
toggle('pvp.enabled',true)
core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
inside=false; core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
assert(wings(member,true) and not member.TisteltiArt.shown)
assert(not member.TisteltiPvPArt or not member.TisteltiPvPArt.shown)
-- Enter and leave every supported scope, enabled and disabled, through events.
for _,scope in ipairs({'party','raid','pvp','arena'}) do
    for _,allowed in ipairs({false,true}) do
        db.scopes[scope]=allowed
        core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
        inside,kind=true,scope
        core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
        assert(wings(member,true)==allowed,scope..' enabled/disabled')
        core.driver.scripts.OnEvent(core.driver,'PLAYER_LEAVING_WORLD')
        inside=false
        core.driver.scripts.OnEvent(core.driver,'PLAYER_ENTERING_WORLD')
        assert(wings(member,true),scope..' exit')
    end
end
-- Repeated native remove/add notifications and unavailable plates are harmless.
for i=1,3 do
    visible={}; plates.guild=nil
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_REMOVED','guild')
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_REMOVED','guild')
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_ADDED','guild')
    assert(not wings(member,true))
    plates.guild={UnitFrame=member,namePlateUnitToken='guild'}; visible={plates.guild}
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_ADDED','guild')
    core.driver.scripts.OnEvent(core.driver,'NAME_PLATE_UNIT_ADDED','guild')
    assert(wings(member,true))
end
assert(#errors==0,table.concat(errors,'\n'))
-- Capture the actual failing state from native AddOns settings without refresh
-- or changing preferences; otherwise opening diagnostics could erase evidence.
local diagnostic=TisteltiPlatesOptions.controls['addons.wings.diagnostic']
local report=TisteltiPlatesOptions.controls['addons.wings.diagnostic.report']
local mutations=nativeMutations
member.name.textWidth=0
diagnostic.scripts.OnClick()
assert(report.text:find('ancho=110.00/0.00',1,true))
assert(report.text:find('estilo=group',1,true))
assert(report.highlighted and db.lastWingDiagnostic==report.text)
assert(not report.text:find('Nombre original largo',1,true))
assert(nativeMutations==mutations and db.namesOnlyWings and db.wings.dungeonGuildOnly)
-- Exceptions outside individual painting callbacks must remain diagnosable.
local oldKind=TisteltiPlatesPlayers.Kind
TisteltiPlatesPlayers.Kind=function() error('diagnostic-test failure') end
core.refresh()
TisteltiPlatesPlayers.Kind=oldKind
diagnostic.scripts.OnClick()
assert(report.text:find('diagnostic-test failure',1,true))
member.name.textWidth=80
visible={}; plates.guild=nil; core.refresh()
diagnostic.scripts.OnClick()
assert(report.text:find('No hay placas disponibles',1,true))
print('PASS: repeated loading screens, delayed/reused/replaced plates, combat, late membership/name data, native UI opt-outs and PvP coexistence')
]=]
assert((loadstring or load)(fixture..cases))()
