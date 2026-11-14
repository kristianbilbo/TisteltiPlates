-- Reuse the existing native-frame fixture, before its behavioral cases start.
local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
local stop=assert(fixture:find("local enemy=add('enemy')",1,true))
fixture=fixture:sub(1,stop-1)
local cases=[=[
SlashCmdList.TISTELTIPLATES('pvp off')
local now=100
GetTime=function() return now end
UnitInParty=function(unit) return unit=='guild' end
GetGuildInfo=function(unit) if units[unit] and units[unit].guild then return 'INFINITY','Oficial',1 end end
units.guildOnly={faction='Alliance',class='MAGE',friend=true,guild=true,rank=8}
local member=add('guild')
local outside=add('guildOnly')
local npc=add('npc')
local fullWidth=member.TisteltiArt.wings.width
local outsideWidth=outside.TisteltiArt.wings.width
local scale,width,color=member.scale,member.width,member.healthBar.color
local before=nativeMutations
combat=true; core.refresh()
local art=member.TisteltiArt
assert(art.groupCompact and art.wings.width<fullWidth)
assert(art.wings.shown and art.rightWing.shown and art.badge.shown)
assert(not art.guildName.shown and not art.guildRole.shown and not art.honor.shown)
assert(member.scale==scale and member.width==width and nativeMutations==before,
    'Compact mode writes only addon-owned ornaments, never native geometry')
assert(member.healthBar.color==color,'Compact mode adds no health recoloring')
assert(not outside.TisteltiArt.groupCompact and outside.TisteltiArt.wings.width==outsideWidth)
assert(not npc.TisteltiArt and not npc.TisteltiCombatArt,'NPCs remain on the 0.8.10 path')
-- Controls must not remove one of the compact wings.
local control=member.AurasFrame.LossOfControlFrame
control.AuraItemFrame=Frame(control); control.AuraItemFrame.Icon={}; control.AuraItemFrame.Cooldown={}
art.scripts.OnUpdate(art,.1)
assert(art.rightWing.shown and art.rightWingLight.shown)
combat=false; now=110; core.refresh()
assert(art.groupCompact,'A short pause does not undo the compact appearance')
now=141; core.refresh()
assert(not art.groupCompact and art.wings.width==fullWidth and art.guildName.shown)
combat=true; now=150; core.refresh(); assert(art.groupCompact)
UnitInParty=function() return false end
core.refresh(); assert(not art.groupCompact,'Guild-only allies are never compacted')
IsInRaid=function() return true end
UnitInRaid=function(unit) return unit=='guild' end
core.refresh(); assert(art.groupCompact,'Friendly raid members are eligible')
db.raid=false; core.refresh(); assert(not art.groupCompact)
combat=false; now=180; core.refresh()
-- Undo only the old experimental setting, without introducing another feature.
local setting,writes=1.32,0
C_CVar={GetCVar=function() return tostring(setting) end,SetCVar=function(_,value) setting=value; writes=writes+1 end}
db.nativeTargetScale=1.2; db.nativeTargetApplied=1.32
core.refresh(); assert(setting==1.2 and writes==1)
core.refresh(); assert(writes==1 and db.nativeTargetScale==nil)
db.nativeTargetScale=1.2; db.nativeTargetApplied=1.32; setting=1.1
core.refresh(); assert(setting==1.1 and writes==1,'Respect subsequent user settings')
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: group-only compact artwork, both wings, native geometry/colors untouched, thirty-second grace, raid membership and legacy cleanup')
]=]
assert((loadstring or load)(fixture..cases))()
