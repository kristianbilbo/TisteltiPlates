local time=10
local secret={}
issecretvalue=function(v) return v==secret end
GetTime=function() return time end
IsInRaid=function() return false end
GetNumSubgroupMembers=function() return 3 end
UnitExists=function() return true end
UnitIsPlayer=function() return true end
UnitCanAttack=function(_,u) return u~='friend' end
UnitIsDeadOrGhost=function() return false end
UnitGUID=function(u) return u..'guid' end
local targets={party1target='a',party2target='a',party3target='b'}
UnitIsUnit=function(a,b) return a==(targets[b] or b) end
local marked
GetRaidTargetIndex=function(u) return u==marked and 8 or nil end
local function plate() return {UnitFrame={IsShown=function() return true end}} end
local plates={a=plate(),b=plate(),friend=plate()}
assert(loadfile('Prioridad.lua'))()
local p=TisteltiPlatesPriority
p.Update(plates,true) assert(p.Reason('a')=='FOCO DEL GRUPO' and not p.Reason('b'))
targets.party2target='b' p.Update(plates,true)
assert(p.Reason('b')=='FOCO DEL GRUPO','invalidated recommendation does not stay stale')
marked='a' p.Update(plates,true) assert(p.Reason('a')=='MARCA DEL GRUPO','explicit skull wins')
marked=nil targets.party1target='a' targets.party2target='a'
p.Update(plates,true)
GetNumSubgroupMembers=function() return 5 end
targets.party3target='b' targets.party4target='b' targets.party5target='b'
time=10.5 p.Update(plates,true) assert(p.Reason('a'),'stable recommendation during a brief vote change')
time=13 p.Update(plates,true) assert(p.Reason('b'),'higher consensus wins after hold time')
UnitIsUnit=function() return secret end
p.Update(plates,true) assert(not p.Reason('a') and not p.Reason('b'),'restricted targets are not guessed')
marked='friend' p.Update(plates,true) assert(not p.Reason('friend'),'friendly skull is not an enemy')
marked='a' UnitIsDeadOrGhost=function(u) return u=='a' end
p.Update(plates,true) assert(not p.Reason('a'),'dead targets excluded')
UnitIsDeadOrGhost=function() return false end
p.Update(plates,true) assert(p.Reason('a'))
p.Update(plates,false) assert(not p.Reason('a'),'disabled PvP clears recommendation')
print('PASS: group consensus, skull, stability, stale targets, restricted data, friendly/dead exclusion and disable')
