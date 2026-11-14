dofile("Config.lua")
-- Event-level regression: selection must not start an asynchronous comparison.
local frames, queued = {}, {}
CreateFrame=function()
    local f={events={}}
    function f:RegisterEvent(event) self.events[event]=true end
    function f:SetScript(_,fn) self.onEvent=fn end
    frames[#frames+1]=f
    return f
end
local function dispatch(event,...)
    for _,f in ipairs(frames) do
        if f.events[event] then f.onEvent(f,event,...) end
    end
end
local requests=0
SetAchievementComparisonUnit=function(unit)
    requests=requests+1
    queued[#queued+1]='friend'
end
-- Model the hidden Blizzard panel from the supplied stack trace: it remains
-- subscribed, with "summary" selected outside the comparison UI.
AchievementFrame={IsShown=function() return false end}
local blizzard=CreateFrame()
blizzard:RegisterEvent('INSPECT_ACHIEVEMENT_READY')
blizzard:SetScript('OnEvent',function()
    error('GetCategoryNumAchievements received summary instead of numeric category')
end)
InCombatLockdown=function() return false end
IsInInstance=function() return false end
UnitIsPlayer=function() return true end
UnitIsFriend=function() return true end
UnitGUID=function(u) return u=='player' and 'self' or 'friend' end
time=function() return 1000 end
GetStatisticsCategoryList=function() return {10} end
GetCategoryNumAchievements=function(id) assert(type(id)=='number'); return 1 end
GetAchievementInfo=function() return 100,'Total honorable kills' end
GetStatistic=function() return '1,500' end
GetComparisonStatistic=function() return '300' end
GetPVPLifetimeStats=function() return 1500 end
local cached={hk=300,bg=2,duels=4,at=1}
TisteltiPlatesDB={enabled=true,combatStats={friend=cached}}
dofile('Honor.lua')
for i=1,20 do dispatch('PLAYER_TARGET_CHANGED') end
assert(requests==0, 'Target selection must never initiate an achievement comparison')
for _,guid in ipairs(queued) do dispatch('INSPECT_ACHIEVEMENT_READY',guid) end
assert(TisteltiPlatesDB.combatStats.friend==cached, 'Keep existing merit data')
local tier,score=TisteltiMerito('target')
assert(tier==2 and score==356, 'Cached merit stays available')
dispatch('PLAYER_ENTERING_WORLD')
assert(TisteltiPlatesDB.combatStats.self.hk==1500)
GetStatistic=function() return '3,000' end
dispatch('PLAYER_PVP_KILLS_CHANGED')
assert(TisteltiPlatesDB.combatStats.self.hk==3000)
UnitPVPRank=function() return 9 end
GetPVPRankInfo=function() return 'Rank',3 end
local _,_,rank=TisteltiMerito('target'); assert(rank==3)
TisteltiPlatesDB.combatStats.friend=nil; UnitPVPRank=nil
local unknown,_,_,partial=TisteltiMerito('target'); assert(unknown==0 and partial)
TisteltiPlatesDB.enabled=false; dispatch('PLAYER_TARGET_CHANGED'); assert(requests==0)
print('PASS: target changes issue no achievement comparisons; cached merit, own stats and official rank still work')
