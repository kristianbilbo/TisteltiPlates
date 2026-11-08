-- Automatic addon merit. Never treats honor level or a manual rank as official.
local f=CreateFrame("Frame")
local ids
local names={
 ["total honorable kills"]="hk", ["total de muertes con honor"]="hk", ["muertes con honor totales"]="hk",
 ["honorable kills"]="hk", ["muertes con honor"]="hk",
 ["battlegrounds played"]="bg", ["campos de batalla jugados"]="bg",
 ["duels won"]="duels", ["duelos ganados"]="duels",
}
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function number(v)
    if not public(v) then return nil end
    if type(v)=="string" then
        v=v:gsub("[ ,%.]", "")
        if not v:match("^%d+$") then return nil end
        v=tonumber(v)
    end
    if type(v)=="number" and v==v and v>=0 and v<math.huge then return v end
end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok and public(value) then return value end
end
local function official(unit)
    local id=number(call(UnitPVPRank,unit))
    if not id or type(GetPVPRankInfo)~="function" then return nil end
    local ok,_,rank=pcall(GetPVPRankInfo,id)
    if ok then
        rank=number(rank)
        if rank and rank<=14 then return math.floor(rank) end
    end
end
local thresholds={100,300,700,1500,3000,5500,9000,14000,21000,30000,42000,58000,80000,110000}
function TisteltiMeritoCalcular(s,rank)
    s=s or {}
    -- Caps prevent repetitive duels or participation alone dominating the badge.
    local score=math.min(number(s.hk) or 0,100000)
        + math.min(number(s.bg) or 0,1000)*20
        + math.min(number(s.duels) or 0,500)*4
    rank=number(rank)
    if rank and rank<=14 then score=score+rank*rank*250 end
    local tier=0
    for i,threshold in ipairs(thresholds) do if score>=threshold then tier=i end end
    return tier,score
end
function TisteltiMerito(unit)
    local guid=call(UnitGUID,unit)
    local db=TisteltiPlatesDB
    local s=guid and db and db.combatStats and db.combatStats[guid]
    local rank=official(unit)
    if not s and rank==nil then return 0,nil,nil,true end
    local tier,score=TisteltiMeritoCalcular(s,rank)
    return tier,score,rank,not (s and s.hk~=nil and s.bg~=nil and s.duels~=nil and rank~=nil)
end
local function findStats()
    if ids then return ids end
    local found={}
    for _,category in ipairs(GetStatisticsCategoryList()) do
        for i=1,GetCategoryNumAchievements(category) do
            local id,name=GetAchievementInfo(category,i)
            local key=type(name)=="string" and names[name:lower()]
            if key then found[key]=id end
        end
    end
    ids=found
    return found
end
-- Do not request achievement comparisons in the background. Their asynchronous
-- INSPECT_ACHIEVEMENT_READY event also reaches Blizzard's comparison panel while
-- hidden, where the normal "summary" category is not a numeric comparison ID.
-- Existing cached merit and directly available official ranks remain usable.
function TisteltiHonorTexto(unit)
    local tier,score,rank,partial=TisteltiMerito(unit)
    if not score then return "Mérito: sin datos" end
    return ("Mérito %d/14 · %d puntos%s · rango oficial %s"):format(tier,score,
        partial and " (datos parciales)" or "",rank and tostring(rank) or "no disponible")
end
local function readSelf()
    if not TisteltiPlatesDB then return end
    local guid=call(UnitGUID,"player")
    if not guid then return end
    local s={at=time()}
    if type(GetStatisticsCategoryList)=="function" then
        for key,id in pairs(findStats()) do s[key]=number(call(GetStatistic,id)) end
    end
    if s.hk==nil then s.hk=number(call(GetPVPLifetimeStats)) end
    TisteltiPlatesDB.combatStats=TisteltiPlatesDB.combatStats or {}
    TisteltiPlatesDB.combatStats[guid]=s
end
f:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(f.RegisterEvent,f,"PLAYER_PVP_KILLS_CHANGED")
pcall(f.RegisterEvent,f,"ACHIEVEMENT_EARNED")
f:SetScript("OnEvent",function()
    pcall(readSelf)
end)
