-- Exercise the real modules together, using the native-frame fixture.
local file=assert(io.open('tests/test_pvp.lua','r'))
local fixture=file:read('*a'); file:close()
fixture=fixture:sub(1,assert(fixture:find("local enemy=add('enemy')",1,true))-1)
local cases=[=[
SlashCmdList.TISTELTIPLATES('pvp off')
db.playerColors.enemy.nameColor={.15,.75,.4}
db.playerColors.enemy.borderColor={.25,.5,.9}
local enemy=add('enemy')
enemy.name:SetTextColor(.7,.6,.5,.45)
assert(enemy.name.textColor[2]==.75 and enemy.name.textColor[4]==.45,
    'Classic custom colors preserve native alpha')
for i=1,10 do
    SlashCmdList.TISTELTIPLATES('pvp on')
    assert(enemy.TisteltiPvPArt.shown and not enemy.TisteltiPlayerBorder.shown)
    assert(enemy.TisteltiPvPArt.edges[1].texture.vertex[2]==.5)
    assert(enemy.name.textColor[2]==.75 and enemy.name.textColor[4]==.45)
    enemy.name:SetVertexColor(.3,.4,.5,.6)
    assert(enemy.name.textColor[2]==.75,'PvP custom name survives native vertex recoloring')
    db.playerColors.enemy.name=false; core.refresh()
    assert(enemy.name.textColor[2]==.3,'Turning off custom color restores PvP faction names')
    db.playerColors.enemy.name=true; core.refresh()
    SlashCmdList.TISTELTIPLATES('pvp off')
    assert(not enemy.TisteltiPvPArt.shown and enemy.TisteltiPlayerBorder.shown)
    assert(enemy.name.textColor[2]==.75 and enemy.name.textColor[4]==.45)
end
SlashCmdList.TISTELTIPLATES('off')
assert(enemy.name.textColor[1]==.7 and enemy.name.textColor[4]==.45,
    'Repeated owner handoffs must restore native color, not another addon color')
SlashCmdList.TISTELTIPLATES('on')
-- Deferred restoration must also work for classic custom names.
combat=true; enemy.name.protected=true
SlashCmdList.TISTELTIPLATES('off')
assert(enemy.name.textColor[2]==.75)
combat=false; enemy.name.protected=false
core.driver.scripts.OnEvent(core.driver,'PLAYER_REGEN_ENABLED')
assert(enemy.name.textColor[1]==.7 and enemy.name.textColor[4]==.45)
SlashCmdList.TISTELTIPLATES('on')
-- Unreadable text colors are left alone, without errors or invented snapshots.
local originalGet=enemy.name.GetTextColor
TisteltiPlatesPlayers.Remove(enemy)
enemy.name.GetTextColor=function() error('restricted name') end
core.refresh()
assert(enemy.name.textColor[1]==.7)
enemy.name.GetTextColor=originalGet; core.refresh()
assert(enemy.name.textColor[2]==.75)

-- Aura priority and the saved right-wing preference coexist with custom styles.
SlashCmdList.TISTELTIPLATES('pvp on')
local guild=add('guild')
local art=guild.TisteltiPvPArt
art.wings[1].rect={0,0,20,20}; art.classFrame.rect={30,0,20,20}
art.factionFrame.rect={48,-5,12,12}; art.wings[2].rect={160,0,20,20}
local controls=guild.AurasFrame.LossOfControlFrame
controls.AuraItemFrame=Frame(controls)
local icon=controls.AuraItemFrame
icon.Icon={}; icon.Cooldown={duration=8}; icon.rect={200,0,18,18}
local function tick() art.scripts.OnUpdate(art,.1) end
db.hideRightWingOnCC=true; tick(); assert(not art.wings[2].shown)
db.hideRightWingOnCC=false; tick(); assert(art.wings[2].shown)
icon.rect={160,0,18,18}; tick()
assert(not art.wings[2].shown and art.wings[1].shown,
    'Actual overlapping auras retain priority even when automatic CC hiding is off')
icon:Hide(); tick(); assert(art.wings[2].shown)

-- The compact group artwork survives combat; names-only wins when requested.
SlashCmdList.TISTELTIPLATES('pvp off')
UnitInParty=function(unit) return unit=='guild' end
GetGuildInfo=function(unit) return unit=='guild' and 'Guild' or nil end
GetTime=function() return 100 end
core.refresh()
combat=true; core.refresh()
assert(guild.TisteltiArt.groupCompact and guild.TisteltiArt.rightWing.shown)
local mutations=nativeMutations
guild.showOnlyName=true; core.refresh()
assert(guild.TisteltiNameWings.shown and not guild.TisteltiArt.shown)
assert(nativeMutations==mutations,'Names-only transition never mutates native geometry in combat')
guild.showOnlyName=false; core.refresh()
assert(guild.TisteltiCombatArt.shown and guild.TisteltiCombatArt.groupCompact)
combat=false; core.driver.scripts.OnEvent(core.driver,'PLAYER_REGEN_ENABLED')
assert(guild.TisteltiArt.shown and guild.TisteltiArt.groupCompact)
assert(not guild.TisteltiCombatArt.shown and not guild.TisteltiNameWings.shown)
SlashCmdList.TISTELTIPLATES('off')
assert(not guild.TisteltiArt.shown and not guild.TisteltiNameWings.shown)
assert(not enemy.TisteltiPlayerBorder.shown and not enemy.TisteltiPvPArt.shown)
assert(enemy.name.textColor[1]==.7 and enemy.name.textColor[4]==.45)
assert(#errors==0,table.concat(errors,'\n'))
print('PASS: repeated PvP/custom ownership, alpha, protected restoration, aura priority and group/names-only transitions')
]=]
assert((loadstring or load)(fixture..cases))()
