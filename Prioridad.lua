-- Recomendación visual. Nunca marca, selecciona ni ataca unidades.
local P={}
TisteltiPlatesPriority=P
local chosen,chosenGUID,reason,since
local function read(fn,...)
    if type(fn)~="function" then return end
    local ok,value=pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
function P.Update(plates,enabled)
    if not enabled then chosen,chosenGUID,reason=nil,nil,nil return end
    local raid=read(IsInRaid)
    local count=read(raid and GetNumGroupMembers or GetNumSubgroupMembers) or 0
    local candidates={}
    for unit,plate in pairs(plates) do
        local uf=plate and plate.UnitFrame
        if uf and read(uf.IsShown,uf) and read(UnitIsPlayer,unit) and read(UnitCanAttack,"player",unit)
            and read(UnitIsDeadOrGhost,unit)~=true then
            local votes=0
            for i=1,count do
                local member=(raid and "raid" or "party")..i
                if read(UnitExists,member) and not read(UnitIsUnit,member,"player")
                    and read(UnitIsUnit,unit,member.."target") then votes=votes+1 end
            end
            local marked=read(GetRaidTargetIndex,unit)==8
            if marked or votes>=2 then
                candidates[unit]={votes=votes,marked=marked,guid=read(UnitGUID,unit),reason=marked and "MARCA DEL GRUPO" or "FOCO DEL GRUPO"}
            end
        end
    end
    local now=read(GetTime) or 0
    local current=chosen and candidates[chosen]
    if current and chosenGUID and current.guid~=chosenGUID then current=nil end
    local best=current and chosen or nil
    for unit,c in pairs(candidates) do
        local old=best and candidates[best]
        if not old or (c.marked and not old.marked) or (c.marked==old.marked and
            (c.votes>old.votes or (c.votes==old.votes and not current and unit<best))) then best=unit end
    end
    if current and best~=chosen and now-(since or 0)<2 and not candidates[best].marked then best=chosen end
    if best~=chosen then since=now end
    chosen=best
    chosenGUID=best and candidates[best].guid
    reason=best and candidates[best].reason
end
function P.Reason(unit)
    if chosen and (unit==chosen or read(UnitIsUnit,unit,chosen)) then return reason end
end
