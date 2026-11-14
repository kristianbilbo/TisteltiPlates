local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
fixture=fixture:sub(1,assert(fixture:find("local enemy=add('enemy')",1,true))-1)
local cases=[=[
local C,O=TisteltiPlatesConfig,TisteltiPlatesOptions
local function toggle(id,value)
    local b=assert(O.controls[id],id); b:SetChecked(value); b.scripts.OnClick(b)
end
db.pvp.enabled=false; core.refresh()
db.scopes.party=true; db.scopes.raid=true
db.priority='group'
UnitInParty=function(unit) return unit=='guild' or unit=='ally' end
inside,kind=true,'party'
local member,guest=add('guild'),add('ally')
member.showOnlyName=true; guest.showOnlyName=true; core.refresh()
assert(db.wings.dungeonGuildOnly)
assert(member.TisteltiNameWings.shown)
assert(not guest.TisteltiNameWings or not guest.TisteltiNameWings.shown)
toggle('addons.wings.dungeonGuildOnly',false)
assert(guest.TisteltiNameWings.shown and not O.controls['wings.dungeonGuildOnly'].checked)
toggle('wings.dungeonGuildOnly',true)
assert(not guest.TisteltiNameWings.shown and O.controls['addons.wings.dungeonGuildOnly'].checked)
-- The filter uses actual membership even when the group style wins priority.
db.guild=false; core.refresh(); assert(member.TisteltiNameWings.shown)
units.ally.guild=true; core.refresh(); assert(guest.TisteltiNameWings.shown)
units.ally.guild=false; core.refresh(); assert(not guest.TisteltiNameWings.shown)
-- Party identity can supply membership missing on the nameplate token.
local oldSame,oldGuild=UnitIsUnit,UnitIsInMyGuild
GetNumSubgroupMembers=function() return 1 end
UnitIsUnit=function(a,b) return (a=='ally' and b=='party1') or oldSame(a,b) end
UnitIsInMyGuild=function(u) if u=='party1' then return true end; return oldGuild(u) end
assert(C.WingsAllowed(db,'ally'))
UnitIsInMyGuild=function() return secret end
assert(not C.WingsAllowed(db,'ally'),'Restricted membership cannot reveal wings')
UnitIsInMyGuild=function() error('unavailable') end
assert(not C.WingsAllowed(db,'ally'))
UnitIsUnit,UnitIsInMyGuild=oldSame,oldGuild
GetNumSubgroupMembers=function() return 0 end
-- Only dungeon wings are filtered; the existing scope settings remain in force.
for _,scope in ipairs({'world','raid','pvp','arena'}) do
    inside,kind=scope~='world',scope; core.refresh()
    assert(guest.TisteltiNameWings.shown,scope)
end
inside,kind=true,'party'; core.refresh(); assert(not guest.TisteltiNameWings.shown)
-- Full plates keep their border and hide both wings, including combat refreshes.
member.showOnlyName=false; guest.showOnlyName=false; core.refresh()
assert(member.TisteltiArt.wings.shown)
assert(guest.TisteltiArt.shown and guest.TisteltiArt.body.shown)
assert(not guest.TisteltiArt.wings.shown and not guest.TisteltiArt.rightWing.shown)
combat=true; core.refresh()
local art=guest.TisteltiCombatArt or guest.TisteltiArt
if art.scripts.OnUpdate then art.scripts.OnUpdate(art,.1) end
assert(not art.wings.shown and not art.rightWing.shown)
combat=false; core.refresh()
toggle('addons.wings.dungeonGuildOnly',false)
assert(guest.TisteltiArt.wings.shown)
C.Initialize(db); assert(not db.wings.dungeonGuildOnly,'Saved opt-out survives initialization')
C.Reset(db,'general'); assert(db.wings.dungeonGuildOnly)
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: dungeon guild-only wings, native UI, roster fallback, membership changes, scopes, combat and saved opt-out')
]=]
assert((loadstring or load)(fixture..cases))()
