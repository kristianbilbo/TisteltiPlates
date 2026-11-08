unpack = unpack or table.unpack
local frames = {}
local function Frame()
    local f = {shown=true, color={.8,.8,.8,1}}
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:GetFrameLevel() return 5 end
    function f:GetTextColor() return unpack(self.color) end
    function f:SetTextColor(...) self.color={...} end
    function f:SetVertexColor(...) self.color={...} end
    function f:SetSize() error('Must not resize native plates') end
    function f:SetScale() error('Must not scale native plates') end
    setmetatable(f,{__index=function(_,key)
        if key:match('^Set') or key=='ClearAllPoints' or key=='EnableMouse' then
            return function() end
        end
    end})
    frames[#frames+1]=f
    return f
end
CreateFrame=Frame
hooksecurefunc=function(object,key,hook)
    local original=object[key]
    object[key]=function(...) original(...); hook(...) end
end
local units={horde={true,'Horde'},ally={true,'Alliance'},npc={false,'Horde'}}
UnitIsPlayer=function(unit) return units[unit] and units[unit][1] end
UnitFactionGroup=function(unit) return units[unit] and units[unit][2] end
local secret={}
issecretvalue=function(v) return v==secret end
units.restricted={true,secret}
dofile('TisteltiPlates/HordeStyle.lua')
local H=TisteltiPlatesHorde
local uf=Frame(); uf.name=Frame(); uf.HealthBarsContainer=Frame(); uf.unit='horde'
local db={enabled=true,hordeRedName=true,hordeRedBorder=true}
H.Update(uf,uf.unit,db)
local border=frames[#frames]
assert(border~=uf.HealthBarsContainer and border.shown)
assert(uf.name.color[1]==1 and uf.name.color[2]==.12)
-- Native selection/mouseover changes must retain red, but restore their latest color.
uf.name:SetVertexColor(.2,.4,.6,1)
assert(uf.name.color[1]==1 and uf.name.color[2]==.12)
db.hordeRedName=false; H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==.2 and uf.name.color[2]==.4 and border.shown)
db.hordeRedName=true; db.hordeRedBorder=false; H.Update(uf,uf.unit,db)
assert(uf.name.color[1]==1 and not border.shown)
db.hordeRedBorder=true
for _,unit in ipairs({'ally','npc','restricted','missing'}) do
    uf.unit=unit; H.Update(uf,unit,db)
    assert(not border.shown and uf.name.color[1]==.2, 'Only known Horde players are accented')
    uf.unit='horde'; H.Update(uf,uf.unit,db)
end
-- A reused native frame must not keep forcing red before the next refresh.
uf.unit='ally'; uf.name:SetVertexColor(.7,.7,.7,1)
assert(uf.name.color[1]==.7)
H.Remove(uf); assert(not border.shown and uf.name.color[1]==.7)
uf.unit='horde'; H.Update(uf,uf.unit,db)
db.enabled=false; H.Update(uf,uf.unit,db)
assert(not border.shown and uf.name.color[1]==.7)
db.enabled=true; H.Update(uf,uf.unit,db)
uf.unit=nil; H.Remove(uf)
assert(not border.shown and uf.name.color[1]==.7)
-- Missing faction APIs fail closed, including restricted data in combat.
UnitFactionGroup=function() error('Restricted') end
uf.unit='horde'; H.Update(uf,uf.unit,db)
assert(not border.shown)
print('PASS: Horde-only accents, native color updates, independent toggles, recycling, removal and restricted data')
